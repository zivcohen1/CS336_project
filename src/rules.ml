open Types

type config = {
  entropy_threshold : float;
  min_entropy_length : int;
  ignored_values : string list;
  extra_secret_patterns : string list;
  extra_misconfig_true_keys : string list;
  extra_misconfig_false_keys : string list;
}

let default_config =
  {
    entropy_threshold = 3.8;
    min_entropy_length = 10;
    ignored_values = [ "test"; "example"; "sample"; "dummy"; "changeme"; "placeholder" ];
    extra_secret_patterns = [];
    extra_misconfig_true_keys = [];
    extra_misconfig_false_keys = [];
  }

let normalize_key s =
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      let lc = Char.lowercase_ascii c in
      if (lc >= 'a' && lc <= 'z') || (lc >= '0' && lc <= '9') then Buffer.add_char b lc)
    s;
  Buffer.contents b

let contains_substring haystack needle =
  let hlen = String.length haystack and nlen = String.length needle in
  nlen > 0
  && hlen >= nlen
  &&
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  loop 0

let string_lower_trim s = String.trim s |> String.lowercase_ascii

let is_ignored_value config value =
  let v = string_lower_trim value in
  List.exists (fun i -> v = i) config.ignored_values

let default_secret_patterns = [ "password"; "passwd"; "apikey"; "token"; "secret" ]

let classify_secret_key normalized =
  if contains_substring normalized "password" || contains_substring normalized "passwd" then Some "Hardcoded password"
  else if contains_substring normalized "apikey" then Some "Hardcoded API key"
  else if contains_substring normalized "token" then Some "Hardcoded token"
  else if contains_substring normalized "secret" then Some "Hardcoded secret"
  else None

let bool_of_scalar = function
  | SBool b -> Some b
  | SString s ->
      let v = string_lower_trim s in
      if v = "true" then Some true else if v = "false" then Some false else None
  | _ -> None

let value_as_string = function
  | SString s -> Some s
  | _ -> None

let make_finding ~category ~issue_type ~key ~path ~line ~risk ~recommendation ~explanation ~severity ~source =
  { category; issue_type; key; path; line; risk; recommendation; explanation; severity; source }

let looks_secretish_key config normalized =
  List.exists (contains_substring normalized) default_secret_patterns
  || List.exists (contains_substring normalized) config.extra_secret_patterns

let is_custom_secret_key config normalized =
  List.exists (contains_substring normalized) config.extra_secret_patterns

let key_in_list normalized keys = List.exists (fun k -> normalized = k) keys

let high_entropy_finding ~source ~path ~key ~line ~entropy_value =
  make_finding
    ~category:Secret
    ~issue_type:"High-entropy value"
    ~key
    ~path
    ~line
    ~risk:"Likely secret leakage through source-controlled configuration."
    ~recommendation:"Move secret material into environment variables or a dedicated secrets manager."
    ~explanation:(Printf.sprintf "Value appears random (Shannon entropy %.2f)." entropy_value)
    ~severity:High
    ~source

let analyze_key_value ~config ~source ~path ~key ~value ~line =
  let normalized = normalize_key key in
  let findings = ref [] in

  (* Context-aware hardcoded secret rule *)
  (match value_as_string value with
  | Some v
    when String.length (String.trim v) >= 4
         && not (is_ignored_value config v)
         && (Option.is_some (classify_secret_key normalized) || is_custom_secret_key config normalized) ->
      let issue_type = Option.value (classify_secret_key normalized) ~default:"Hardcoded secret" in
      findings :=
        make_finding
          ~category:Secret
          ~issue_type
          ~key
          ~path
          ~line
          ~risk:"Hardcoded credentials can leak via source control, logs, and build artifacts."
          ~recommendation:"Use environment variables or a secret manager and rotate exposed credentials."
          ~explanation:"Sensitive key name paired with an inline literal value."
          ~severity:High
          ~source
        :: !findings
  | _ -> ());

  (* Misconfig rules *)
  (match (normalized, bool_of_scalar value) with
  | "debug", Some true ->
      findings :=
        make_finding
          ~category:Misconfiguration
          ~issue_type:"Debug mode enabled"
          ~key
          ~path
          ~line
          ~risk:"Information disclosure through stack traces, verbose logs, and internal state exposure."
          ~recommendation:"Disable debug mode in production environments."
          ~explanation:"`debug` is set to true."
          ~severity:Medium
          ~source
        :: !findings
  | "sslverify", Some false ->
      findings :=
        make_finding
          ~category:Misconfiguration
          ~issue_type:"SSL verification disabled"
          ~key
          ~path
          ~line
          ~risk:"Disables certificate validation, increasing MITM attack risk."
          ~recommendation:"Enable SSL/TLS certificate verification."
          ~explanation:"`ssl_verify` equivalent key is false."
          ~severity:High
          ~source
        :: !findings
  | "allowinsecure", Some true ->
      findings :=
        make_finding
          ~category:Misconfiguration
          ~issue_type:"Insecure connections explicitly allowed"
          ~key
          ~path
          ~line
          ~risk:"Permits downgraded or untrusted transport security settings."
          ~recommendation:"Set `allow_insecure` to false and enforce secure transport."
          ~explanation:"`allow_insecure` is set to true."
          ~severity:High
          ~source
        :: !findings
  | _, Some true when key_in_list normalized config.extra_misconfig_true_keys ->
      findings :=
        make_finding
          ~category:Misconfiguration
          ~issue_type:"Insecure setting enabled"
          ~key
          ~path
          ~line
          ~risk:"Policy-marked insecure flag is enabled."
          ~recommendation:"Disable this setting for production unless there is a documented exception."
          ~explanation:"Custom policy marked this key as unsafe when true."
          ~severity:High
          ~source
        :: !findings
  | _, Some false when key_in_list normalized config.extra_misconfig_false_keys ->
      findings :=
        make_finding
          ~category:Misconfiguration
          ~issue_type:"Security validation disabled"
          ~key
          ~path
          ~line
          ~risk:"Policy-marked verification or protection flag is disabled."
          ~recommendation:"Enable this setting to restore required security checks."
          ~explanation:"Custom policy marked this key as unsafe when false."
          ~severity:High
          ~source
        :: !findings
  | _ -> ());

  (* High-entropy detection *)
  (match value_as_string value with
  | Some s when String.length s >= config.min_entropy_length && not (is_ignored_value config s) ->
      let e = Entropy.entropy s in
      let strong_signal = looks_secretish_key config normalized || e >= config.entropy_threshold +. 0.6 in
      if e >= config.entropy_threshold && strong_signal then
        findings := high_entropy_finding ~source ~path ~key ~line ~entropy_value:e :: !findings
  | _ -> ());

  List.rev !findings
