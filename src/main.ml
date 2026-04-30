type output_mode =
  | Text
  | Json

let usage () =
  Printf.eprintf
    "Usage: scanner [--json] [--policy <file.json>] [--entropy-threshold <float>] [--min-entropy-length <int>] [--github <url>] <file>\n";
  exit 1

let () =
  let mode = ref Text in
  let entropy_threshold = ref None in
  let min_entropy_length = ref None in
  let policy_file = ref None in
  let target_file = ref None in
  let github_url = ref None in

  let rec parse_args i =
    if i >= Array.length Sys.argv then ()
    else
      match Sys.argv.(i) with
      | "--json" ->
          mode := Json;
          parse_args (i + 1)
      | "--entropy-threshold" ->
          if i + 1 >= Array.length Sys.argv then usage ();
          entropy_threshold :=
            (match float_of_string_opt Sys.argv.(i + 1) with Some v -> Some v | None -> usage ());
          parse_args (i + 2)
      | "--min-entropy-length" ->
          if i + 1 >= Array.length Sys.argv then usage ();
          min_entropy_length :=
            (match int_of_string_opt Sys.argv.(i + 1) with Some v -> Some v | None -> usage ());
          parse_args (i + 2)
      | "--policy" ->
          if i + 1 >= Array.length Sys.argv then usage ();
          if Option.is_some !policy_file then usage () else policy_file := Some Sys.argv.(i + 1);
          parse_args (i + 2)
      | "--github" ->
          if i + 1 >= Array.length Sys.argv then usage ();
          if Option.is_some !github_url then usage () else github_url := Some Sys.argv.(i + 1);
          parse_args (i + 2)
      | arg when String.starts_with ~prefix:"-" arg -> usage ()
      | file ->
          if Option.is_some !target_file then usage () else target_file := Some file;
          parse_args (i + 1)
  in

  parse_args 1;

  (* Check that either --github or file is provided, but not both *)
  let (is_github, scan_target) = match (!github_url, !target_file) with
    | (Some url, None) -> (true, url)
    | (None, Some f) -> (false, f)
    | (Some _, Some _) -> 
        Printf.eprintf "Error: Cannot specify both --github and a file\n";
        usage ()
    | (None, None) -> usage ()
  in

  let config_from_policy : Rules.config =
    match !policy_file with
    | None -> Rules.default_config
    | Some path -> (
        match Policy.load path with
        | Ok policy -> Policy.apply_to_config policy Rules.default_config
        | Error msg ->
            prerr_endline msg;
            exit 1)
  in

  let config : Rules.config =
    {
      config_from_policy with
      entropy_threshold = Option.value !entropy_threshold ~default:config_from_policy.entropy_threshold;
      min_entropy_length = Option.value !min_entropy_length ~default:config_from_policy.min_entropy_length;
    }
  in

  let scan_result = 
    if is_github then
      Git_utils.fetch_and_scan_github ~config ~github_url:scan_target ~policy_file:!policy_file
    else
      Scanner.scan_file ~config scan_target
  in

  match scan_result with
  | Error msg ->
      prerr_endline msg;
      exit 1
  | Ok findings ->
      let out =
        match !mode with
        | Text -> Report.render_text findings
        | Json -> Report.render_json findings
      in
      print_endline out;
      if findings = [] then exit 0 else exit 2
