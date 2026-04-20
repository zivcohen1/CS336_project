type output_mode =
  | Text
  | Json

let usage () =
  Printf.eprintf
    "Usage: scanner [--json] [--entropy-threshold <float>] [--min-entropy-length <int>] <file>\n";
  exit 1

let () =
  let mode = ref Text in
  let entropy_threshold = ref Rules.default_config.entropy_threshold in
  let min_entropy_length = ref Rules.default_config.min_entropy_length in
  let target_file = ref None in

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
            (match float_of_string_opt Sys.argv.(i + 1) with Some v -> v | None -> usage ());
          parse_args (i + 2)
      | "--min-entropy-length" ->
          if i + 1 >= Array.length Sys.argv then usage ();
          min_entropy_length :=
            (match int_of_string_opt Sys.argv.(i + 1) with Some v -> v | None -> usage ());
          parse_args (i + 2)
      | arg when String.starts_with ~prefix:"-" arg -> usage ()
      | file ->
          if Option.is_some !target_file then usage () else target_file := Some file;
          parse_args (i + 1)
  in

  parse_args 1;

  let file = match !target_file with Some f -> f | None -> usage () in

  let config : Rules.config =
    {
      Rules.default_config with
      entropy_threshold = !entropy_threshold;
      min_entropy_length = !min_entropy_length;
    }
  in

  match Scanner.scan_file ~config file with
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
