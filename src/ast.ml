type expr =
  | String of string
  | Bool of bool
  | Number of int

type stmt =
  | Assign of string * expr * int
