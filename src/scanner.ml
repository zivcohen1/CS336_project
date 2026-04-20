open Types

let scalar_of_expr = function
  | Ast.String s -> SString s
  | Ast.Bool b -> SBool b
  | Ast.Number n -> SNumber (float_of_int n)

type file_kind =
  | KImp
  | KJson
  | KYaml

let detect_file_kind path =
  let ext = Filename.extension path |> String.lowercase_ascii in
  match ext with
  | ".imp" -> Ok KImp
  | ".json" -> Ok KJson
  | ".yaml" | ".yml" -> Ok KYaml
  | _ -> Error ("Unsupported file extension: " ^ ext ^ " (supported: .imp, .json, .yaml, .yml)")

let analyze_entries ~config ~source entries =
  List.concat_map
    (fun (path, key, value, line) -> Rules.analyze_key_value ~config ~source ~path ~key ~value ~line)
    entries

let scan_imp ~config path =
  try
    let stmts = Parser.parse_file path in
    let entries =
      List.map
        (function
          | Ast.Assign (var, expr, line) -> ([], var, scalar_of_expr expr, line))
        stmts
    in
    Ok (analyze_entries ~config ~source:Imp entries)
  with
  | Parser.Parse_error (line, msg) -> Error (Printf.sprintf "IMP parse error at line %d: %s" line msg)
  | Sys_error msg -> Error ("File error: " ^ msg)

let scan_json ~config path =
  match JsonScanner.scan_file path with
  | Error msg -> Error msg
  | Ok entries ->
      let normalized =
        List.map (fun (e : JsonScanner.entry) -> (e.path, e.key, e.value, e.line)) entries
      in
      Ok (analyze_entries ~config ~source:Json normalized)

let scan_yaml ~config path =
  match YamlScanner.scan_file path with
  | Error msg -> Error msg
  | Ok entries ->
      let normalized =
        List.map (fun (e : YamlScanner.entry) -> (e.path, e.key, e.value, e.line)) entries
      in
      Ok (analyze_entries ~config ~source:Yaml normalized)

let scan_file ?(config = Rules.default_config) path =
  match detect_file_kind path with
  | Error msg -> Error msg
  | Ok KImp -> scan_imp ~config path
  | Ok KJson -> scan_json ~config path
  | Ok KYaml -> scan_yaml ~config path
