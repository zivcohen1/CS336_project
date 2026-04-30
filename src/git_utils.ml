(* Extract owner/repo from GitHub URL *)
let parse_github_url url =
  let url = 
    if String.ends_with ~suffix:".git" url then
      String.sub url 0 (String.length url - 4)
    else url
  in
  try
    let url = String.lowercase_ascii url in
    if String.contains url ':' && not (String.starts_with ~prefix:"https:" url) then
      (* SSH format: git@github.com:owner/repo *)
      let parts = String.split_on_char ':' url in
      (match parts with
      | [_; repo_part] ->
          let parts = String.split_on_char '/' repo_part in
          (match parts with
          | [owner; repo] -> Ok (owner, repo)
          | _ -> Error ("Invalid SSH GitHub URL format: " ^ url))
      | _ -> Error ("Invalid SSH GitHub URL format: " ^ url))
    else if String.starts_with ~prefix:"https://github.com/" url then
      let path = String.sub url 19 (String.length url - 19) in
      let parts = String.split_on_char '/' path in
      (match parts with
      | owner :: repo :: _ -> Ok (owner, repo)
      | _ -> Error ("Invalid GitHub URL format: " ^ url))
    else
      Error ("Not a GitHub URL: " ^ url)
  with _ -> Error ("Failed to parse GitHub URL: " ^ url)

let is_github_url url =
  let url = String.lowercase_ascii url in
  String.starts_with ~prefix:"https://github.com/" url || 
  (String.contains url ':' && String.starts_with ~prefix:"git@github.com:" url)

let create_temp_dir () =
  let unique_id = Printf.sprintf "scanner_%d_%d" (Random.int 1000000) (Unix.getpid ()) in
  Filename.concat "/tmp" unique_id

let clone_repo url dest_dir =
  try
    let cmd = Printf.sprintf "git clone %s %s 2>&1" 
      (Filename.quote url) (Filename.quote dest_dir) in
    let result = Sys.command cmd in
    if result = 0 then Ok dest_dir
    else Error (Printf.sprintf "Failed to clone repository (exit code %d)" result)
  with Sys_error msg -> Error ("System error during clone: " ^ msg)

let supported_extensions = [".json"; ".yaml"; ".yml"; ".imp"]

let is_supported_file path =
  let ext = Filename.extension path |> String.lowercase_ascii in
  List.mem ext supported_extensions

let should_skip_dir name =
  let name = String.lowercase_ascii name in
  List.mem name [
    ".git"; ".github"; ".gitlab"; ".hg"; ".svn";
    "node_modules"; ".npm"; "venv"; ".venv"; ".env"; "__pycache__";
    ".pytest_cache"; ".tox"; ".vscode"; ".idea"; ".ds_store";
    "build"; "dist"; "target"; ".cargo"; "bin"; "obj";
  ]

let rec collect_files dir_path acc =
  try
    let entries = Sys.readdir dir_path in
    Array.fold_left (fun acc entry ->
      let full_path = Filename.concat dir_path entry in
      if Sys.is_directory full_path then
        if should_skip_dir entry then acc
        else collect_files full_path acc
      else
        if is_supported_file entry then full_path :: acc
        else acc
    ) acc entries
  with Sys_error _ -> acc

let find_all_files dir_path =
  let files = collect_files dir_path [] in
  List.rev files

let cleanup_repo_dir repo_dir =
  try
    let cmd = Printf.sprintf "rm -rf %s" (Filename.quote repo_dir) in
    let _ = Sys.command cmd in ()
  with _ -> ()

let fetch_and_scan_github ~config ~github_url ~policy_file:_ =
  match parse_github_url github_url with
  | Error msg -> Error msg
  | Ok (_owner, _repo) ->
      let temp_dir = create_temp_dir () in
      (match clone_repo github_url temp_dir with
      | Error msg ->
          cleanup_repo_dir temp_dir;
          Error msg
      | Ok repo_dir ->
          let files = find_all_files repo_dir in
          let findings = List.concat_map (fun file_path ->
            let ext = Filename.extension file_path |> String.lowercase_ascii in
            let file_kind = match ext with
              | ".imp" -> Some `Imp
              | ".json" -> Some `Json
              | ".yaml" | ".yml" -> Some `Yaml
              | _ -> None
            in
            match file_kind with
            | None -> []
            | Some kind ->
                (try
                  let entries = 
                    match kind with
                    | `Imp ->
                        let stmts = Parser.parse_file file_path in
                        List.map (fun stmt ->
                          match stmt with
                          | Ast.Assign (var, expr, line) ->
                              let scalar = match expr with
                                | Ast.String s -> Types.SString s
                                | Ast.Bool b -> Types.SBool b
                                | Ast.Number n -> Types.SNumber (float_of_int n)
                              in
                              ([], var, scalar, line)
                        ) stmts
                    | `Json ->
                        (match JsonScanner.scan_file file_path with
                        | Error _ -> []
                        | Ok entries ->
                            List.map (fun (e : JsonScanner.entry) ->
                              (e.path, e.key, e.value, e.line)
                            ) entries)
                    | `Yaml ->
                        (match YamlScanner.scan_file file_path with
                        | Error _ -> []
                        | Ok entries ->
                            List.map (fun (e : YamlScanner.entry) ->
                              (e.path, e.key, e.value, e.line)
                            ) entries)
                  in
                  let file_findings = List.concat_map
                    (fun (path, key, value, line) ->
                      Rules.analyze_key_value ~config ~source:(
                        match kind with
                        | `Imp -> Types.Imp
                        | `Json -> Types.Json
                        | `Yaml -> Types.Yaml
                      ) ~path ~key ~value ~line
                    ) entries
                  in
                  let root_len = String.length repo_dir in
                  let path_len = String.length file_path in
                  let repo_relative_path = 
                    if path_len > root_len then
                      let rel = String.sub file_path root_len (path_len - root_len) in
                      if String.starts_with ~prefix:"/" rel then
                        String.sub rel 1 (String.length rel - 1)
                      else rel
                    else file_path
                  in
                  List.map (fun (f : Types.finding) ->
                    { f with path = repo_relative_path :: f.path }
                  ) file_findings
                with _ -> [])
          ) files in
          cleanup_repo_dir temp_dir;
          Ok findings)
