let entropy s =
  let len = String.length s in
  if len = 0 then 0.0
  else
    let counts = Hashtbl.create 32 in
    String.iter
      (fun c ->
        let n = Option.value (Hashtbl.find_opt counts c) ~default:0 in
        Hashtbl.replace counts c (n + 1))
      s;
    Hashtbl.fold
      (fun _ count acc ->
        let p = float_of_int count /. float_of_int len in
        if p = 0.0 then acc else acc -. (p *. (log p /. log 2.0)))
      counts
      0.0
