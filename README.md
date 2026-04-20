# AST-Based Secret & Misconfiguration Scanner (OCaml)

A modular static scanner that analyzes:

- IMP-Core style files (`.imp`)
- JSON (`.json`)
- YAML (`.yaml`, `.yml`)

It detects:

- Hardcoded secrets (`password`, `token`, `api_key`, etc.)
- High-entropy strings (likely secrets)
- Insecure configurations (`debug=true`, `ssl_verify=false`, `allow_insecure=true`)

## Architecture

- `src/ast.ml` — IMP-Core AST (`Assign`, literals)
- `src/parser.ml` — IMP parser with line tracking
- `src/jsonScanner.ml` — recursive JSON traversal with path extraction
- `src/yamlScanner.ml` — recursive YAML traversal with path extraction
- `src/entropy.ml` — Shannon entropy implementation
- `src/rules.ml` — context-aware security/misconfiguration rules and thresholds
- `src/scanner.ml` — orchestrates parser/scanners + rule engine
- `src/report.ml` — text and JSON reporting
- `src/main.ml` — CLI entrypoint
- `src/types.ml` — shared finding/value types

## Build

1. Install dependencies (example using opam):
   - `dune`
   - `yojson`
   - `yaml`
2. Build:
   - `dune build`

## Run

- Preferred wrapper (macOS/Linux, matches `./scanner ...` style):
  - `./scanner path/to/file.imp`
  - `./scanner path/to/config.json`
  - `./scanner path/to/config.yaml`
- Windows `cmd` wrapper:
  - `scanner.cmd path\\to\\file.imp`
  - `scanner.cmd path\\to\\config.json`
  - `scanner.cmd path\\to\\config.yaml`
- Direct cross-platform dune command:
  - `opam exec -- dune exec src/main.exe -- path/to/file.imp`
- Direct dune executable:
  - `dune exec src/main.exe -- path/to/file.imp`
- JSON output:
  - `./scanner --json path/to/file.json`
  - `scanner.cmd --json path\\to\\file.json`

## Custom Policy File

You can provide a custom JSON policy file to extend scanner behavior:

- `--policy <file.json>`

Supported policy fields:

- `entropy_threshold` (number)
- `min_entropy_length` (integer)
- `ignored_values` (string array)
- `secret_patterns` (string array): additional key patterns treated as secret-like
- `misconfig_true_keys` (string array): keys flagged when set to `true`
- `misconfig_false_keys` (string array): keys flagged when set to `false`

Example:

- `scanner.cmd --policy examples\\policy.json examples\\sample.yaml`
- `opam exec -- dune exec src/main.exe -- --policy examples/policy.json examples/sample.yaml`

## Optional tuning flags

- `--entropy-threshold <float>` (default `3.8`)
- `--min-entropy-length <int>` (default `10`)

Example:

`./scanner --entropy-threshold 4.0 --min-entropy-length 12 config.yaml`

## Exit codes

- `0`: scan succeeded, no findings
- `2`: scan succeeded, findings produced
- `1`: parse/usage/runtime error
