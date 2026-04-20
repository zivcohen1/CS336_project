open Types

let yojson_of_finding (f : finding) =
  `Assoc
    [ ("category", `String (string_of_category f.category));
      ("severity", `String (string_of_severity f.severity));
      ("issue_type", `String f.issue_type);
      ("key", `String f.key);
      ("path", `String (path_to_string f.path));
      ("line", `Int f.line);
      ("source", `String (string_of_source f.source));
      ("risk", `String f.risk);
      ("recommendation", `String f.recommendation);
      ("explanation", `String f.explanation)
    ]

let sort_findings findings =
  let cmp a b =
    match Int.compare a.line b.line with
    | 0 -> String.compare a.key b.key
    | c -> c
  in
  List.sort cmp findings

let line_label line = if line > 0 then string_of_int line else "unknown"

let format_finding_text (f : finding) =
  Printf.sprintf
    "%s DETECTED at line %s\nType: %s\nVariable/Key: %s\nPath: %s\nSeverity: %s\nRisk: %s\nRecommendation: %s\n"
    (string_of_category f.category)
    (line_label f.line)
    f.issue_type
    f.key
    (path_to_string f.path)
    (string_of_severity f.severity)
    f.risk
    f.recommendation

let render_text findings =
  match sort_findings findings with
  | [] -> "No issues found."
  | xs -> String.concat "\n" (List.map format_finding_text xs)

let render_json findings =
  findings
  |> sort_findings
  |> List.map yojson_of_finding
  |> fun items -> `List items
  |> Yojson.Safe.pretty_to_string
