type scalar =
  | SString of string
  | SBool of bool
  | SNumber of float
  | SNull

type source_kind =
  | Imp
  | Json
  | Yaml

type category =
  | Secret
  | Misconfiguration

type severity =
  | Low
  | Medium
  | High

type finding = {
  category : category;
  issue_type : string;
  key : string;
  path : string list;
  line : int;
  risk : string;
  recommendation : string;
  explanation : string;
  severity : severity;
  source : source_kind;
}

let string_of_source = function
  | Imp -> "imp"
  | Json -> "json"
  | Yaml -> "yaml"

let string_of_category = function
  | Secret -> "SECRET"
  | Misconfiguration -> "MISCONFIG"

let string_of_severity = function
  | Low -> "Low"
  | Medium -> "Medium"
  | High -> "High"

let path_to_string path =
  match path with
  | [] -> "<root>"
  | _ -> String.concat "." path
