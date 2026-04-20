type t = {
  entropy_threshold : float option;
  min_entropy_length : int option;
  ignored_values : string list option;
  secret_patterns : string list option;
  misconfig_true_keys : string list option;
  misconfig_false_keys : string list option;
}

let empty =
  {
    entropy_threshold = None;
    min_entropy_length = None;
    ignored_values = None;
    secret_patterns = None;
    misconfig_true_keys = None;
    misconfig_false_keys = None;
  }

let normalize_string_list list =
  List.map (fun s -> String.trim s |> String.lowercase_ascii) list
  |> List.filter (fun s -> s <> "")

let normalize_key_list list =
  List.map Rules.normalize_key list |> List.filter (fun s -> s <> "")

let string_list_field obj field_name =
  match List.assoc_opt field_name obj with
  | None -> Ok None
  | Some (`List values) ->
      let rec collect acc = function
        | [] -> Ok (Some (List.rev acc))
        | `String s :: rest -> collect (s :: acc) rest
        | _ :: _ ->
            Error
              (Printf.sprintf
                 "Policy field `%s` must be an array of strings."
                 field_name)
      in
      collect [] values
  | Some _ -> Error (Printf.sprintf "Policy field `%s` must be an array of strings." field_name)

let float_field obj field_name =
  match List.assoc_opt field_name obj with
  | None -> Ok None
  | Some (`Float f) -> Ok (Some f)
  | Some (`Int n) -> Ok (Some (float_of_int n))
  | Some (`Intlit s) -> (
      match float_of_string_opt s with
      | Some f -> Ok (Some f)
      | None -> Error (Printf.sprintf "Policy field `%s` must be numeric." field_name))
  | Some _ -> Error (Printf.sprintf "Policy field `%s` must be numeric." field_name)

let int_field obj field_name =
  match List.assoc_opt field_name obj with
  | None -> Ok None
  | Some (`Int n) -> Ok (Some n)
  | Some (`Intlit s) -> (
      match int_of_string_opt s with
      | Some v -> Ok (Some v)
      | None -> Error (Printf.sprintf "Policy field `%s` must be an integer." field_name))
  | Some _ -> Error (Printf.sprintf "Policy field `%s` must be an integer." field_name)

let parse_json = function
  | `Assoc obj ->
      (match float_field obj "entropy_threshold" with
      | Error e -> Error e
      | Ok entropy_threshold ->
          match int_field obj "min_entropy_length" with
          | Error e -> Error e
          | Ok min_entropy_length ->
              match string_list_field obj "ignored_values" with
              | Error e -> Error e
              | Ok ignored_values ->
                  match string_list_field obj "secret_patterns" with
                  | Error e -> Error e
                  | Ok secret_patterns ->
                      match string_list_field obj "misconfig_true_keys" with
                      | Error e -> Error e
                      | Ok misconfig_true_keys ->
                          match string_list_field obj "misconfig_false_keys" with
                          | Error e -> Error e
                          | Ok misconfig_false_keys ->
                              Ok
                                {
                                  entropy_threshold;
                                  min_entropy_length;
                                  ignored_values = Option.map normalize_string_list ignored_values;
                                  secret_patterns = Option.map normalize_key_list secret_patterns;
                                  misconfig_true_keys =
                                    Option.map normalize_key_list misconfig_true_keys;
                                  misconfig_false_keys =
                                    Option.map normalize_key_list misconfig_false_keys;
                                })
  | _ -> Error "Policy file must contain a top-level JSON object."

let load path =
  try
    match Filename.extension path |> String.lowercase_ascii with
    | ".json" ->
        let json = Yojson.Safe.from_file path in
        parse_json json
    | ext -> Error (Printf.sprintf "Unsupported policy extension `%s` (use .json)." ext)
  with
  | Yojson.Json_error msg -> Error ("Policy JSON parse error: " ^ msg)
  | Sys_error msg -> Error ("Policy file error: " ^ msg)

let apply_to_config policy (config : Rules.config) : Rules.config =
  {
    entropy_threshold = Option.value policy.entropy_threshold ~default:config.entropy_threshold;
    min_entropy_length =
      Option.value policy.min_entropy_length ~default:config.min_entropy_length;
    ignored_values = Option.value policy.ignored_values ~default:config.ignored_values;
    extra_secret_patterns =
      Option.value policy.secret_patterns ~default:config.extra_secret_patterns;
    extra_misconfig_true_keys =
      Option.value policy.misconfig_true_keys ~default:config.extra_misconfig_true_keys;
    extra_misconfig_false_keys =
      Option.value policy.misconfig_false_keys ~default:config.extra_misconfig_false_keys;
  }
