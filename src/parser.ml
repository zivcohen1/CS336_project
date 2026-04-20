open Ast

exception Parse_error of int * string

let read_file path =
  let ch = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in ch)
    (fun () ->
      let len = in_channel_length ch in
      really_input_string ch len)

let is_blank_or_comment line =
  let trimmed = String.trim line in
  trimmed = "" || String.starts_with ~prefix:"#" trimmed || String.starts_with ~prefix:"//" trimmed

let unescape_string s =
  let b = Buffer.create (String.length s) in
  let rec loop i =
    if i >= String.length s then ()
    else if s.[i] = '\\' && i + 1 < String.length s then
      let () =
        match s.[i + 1] with
        | 'n' -> Buffer.add_char b '\n'
        | 't' -> Buffer.add_char b '\t'
        | '\\' -> Buffer.add_char b '\\'
        | '"' -> Buffer.add_char b '"'
        | c -> Buffer.add_char b c
      in
      loop (i + 2)
    else (
      Buffer.add_char b s.[i];
      loop (i + 1))
  in
  loop 0;
  Buffer.contents b

let parse_expr line_no raw =
  let value = String.trim raw in
  if value = "true" then Bool true
  else if value = "false" then Bool false
  else if String.length value >= 2 && value.[0] = '"' && value.[String.length value - 1] = '"' then
    let inner = String.sub value 1 (String.length value - 2) in
    String (unescape_string inner)
  else
    match int_of_string_opt value with
    | Some n -> Number n
    | None -> raise (Parse_error (line_no, "Unsupported literal value: " ^ value))

let find_assign_operator line =
  let rec loop i in_string =
    if i + 1 >= String.length line then None
    else
      let c = line.[i] in
      if c = '"' then loop (i + 1) (not in_string)
      else if (not in_string) && c = ':' && line.[i + 1] = '=' then Some i
      else loop (i + 1) in_string
  in
  loop 0 false

let parse_line line_no line =
  if is_blank_or_comment line then None
  else
    match find_assign_operator line with
    | None -> raise (Parse_error (line_no, "Expected ':=' assignment operator"))
    | Some idx ->
        let lhs = String.sub line 0 idx |> String.trim in
        let rhs = String.sub line (idx + 2) (String.length line - idx - 2) |> String.trim in
        if lhs = "" then raise (Parse_error (line_no, "Missing variable name"));
        if rhs = "" then raise (Parse_error (line_no, "Missing assigned value"));
        Some (Assign (lhs, parse_expr line_no rhs, line_no))

let parse content =
  content
  |> String.split_on_char '\n'
  |> List.mapi (fun i line -> parse_line (i + 1) line)
  |> List.filter_map (fun x -> x)

let parse_file path = read_file path |> parse
