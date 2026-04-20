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

- Preferred wrapper (matches `./scanner ...` style):
  - `./scanner path/to/file.imp`
  - `./scanner path/to/config.json`
  - `./scanner path/to/config.yaml`
- Direct dune executable:
  - `dune exec src/main.exe -- path/to/file.imp`
- JSON output:
  - `./scanner --json path/to/file.json`

## Optional tuning flags

- `--entropy-threshold <float>` (default `3.8`)
- `--min-entropy-length <int>` (default `10`)

Example:

`./scanner --entropy-threshold 4.0 --min-entropy-length 12 config.yaml`

## Exit codes

- `0`: scan succeeded, no findings
- `2`: scan succeeded, findings produced
- `1`: parse/usage/runtime error
