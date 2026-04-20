open Types

type entry = {
  path : string list;
  key : string;
  value : scalar;
  line : int;
}

let read_file path =
  let ch = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in ch)
    (fun () ->
      let len = in_channel_length ch in
      really_input_string ch len)

let lines_of_file path = read_file path |> String.split_on_char '\n' |> Array.of_list

let scalar_of_yaml = function
  | `String s -> Some (SString s)
  | `Bool b -> Some (SBool b)
  | `Float f -> Some (SNumber f)
  | `Null -> Some SNull
  | _ -> None

let scalar_to_search_fragment = function
  | SString s -> s
  | SBool true -> "true"
  | SBool false -> "false"
  | SNumber n ->
      if Float.equal (Float.round n) n then string_of_int (int_of_float n) else string_of_float n
  | SNull -> "null"

let find_line_number lines ~key ~value_fragment =
  let key_l = String.lowercase_ascii key in
  let value_l = String.lowercase_ascii value_fragment in
  let rec loop i =
    if i >= Array.length lines then 0
    else
      let line = String.lowercase_ascii lines.(i) in
      if Rules.contains_substring line key_l && Rules.contains_substring line value_l then i + 1
      else if Rules.contains_substring line key_l then i + 1
      else loop (i + 1)
  in
  loop 0

let scan_file path =
  try
    let raw = read_file path in
    match Yaml.of_string raw with
    | Error (`Msg msg) -> Error ("YAML parse error: " ^ msg)
    | Ok yaml ->
        let lines = lines_of_file path in
        let rec walk current_path acc node =
          match node with
          | `O props ->
              List.fold_left
                (fun state (k, v) ->
                  let next_path = current_path @ [ k ] in
                  let with_scalar =
                    match scalar_of_yaml v with
                    | Some scalar ->
                        let line =
                          find_line_number lines ~key:k ~value_fragment:(scalar_to_search_fragment scalar)
                        in
                        { path = current_path; key = k; value = scalar; line } :: state
                    | None -> state
                  in
                  walk next_path with_scalar v)
                acc
                props
          | `A items ->
              List.mapi (fun i item -> (i, item)) items
              |> List.fold_left
                   (fun state (i, item) -> walk (current_path @ [ Printf.sprintf "[%d]" i ]) state item)
                   acc
          | _ -> acc
        in
        Ok (List.rev (walk [] [] yaml))
  with Sys_error msg -> Error ("File error: " ^ msg)
