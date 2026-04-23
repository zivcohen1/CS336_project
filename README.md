# AST-Based Secret & Misconfiguration Scanner (OCaml)

A modular static scanner that analyzes:

- IMP-Core style files (`.imp`)
- JSON (`.json`)
- YAML (`.yaml`, `.yml`)

It detects:

- Hardcoded secrets (`password`, `token`, `api_key`, etc.)
- High-entropy strings (likely secrets)
- Insecure configurations (`debug=true`, `ssl_verify=false`, `allow_insecure=true`)

---

## What this project does

Given an input file (`.imp`, `.json`, `.yaml`, `.yml`), the scanner:

1. Parses it into structured data (AST/tree, not regex-only scanning).
2. Applies context-aware rules based on key names and value types.
3. Computes Shannon entropy for candidate strings.
4. Produces findings with line number, issue type, key, risk, and recommendation.

---

## Quick start

Build:

- `dune build`

Run (text output):

- `./scanner examples/sample.imp`
- `./scanner examples/sample.json`
- `./scanner examples/sample.yaml`

Run (JSON output):

- `./scanner --json examples/sample.yaml`

Save output to file:

- `./scanner --json examples/sample.yaml > results.json`

## Architecture

- `src/ast.ml` — IMP-Core AST (`Assign`, literals)
- `src/parser.ml` — IMP parser with line tracking
- `src/jsonScanner.ml` — recursive JSON traversal with path extraction
- `src/yamlScanner.ml` — recursive YAML traversal with path extraction
- `src/entropy.ml` — Shannon entropy implementation
- `src/rules.ml` — context-aware security/misconfiguration rules and thresholds
- `src/policy.ml` — loads and validates custom policy JSON, then maps it to runtime rule config
- `src/scanner.ml` — orchestrates parser/scanners + rule engine
- `src/report.ml` — text and JSON reporting
- `src/main.ml` — CLI entrypoint
- `src/types.ml` — shared finding/value types

---

## Build

Install dependencies (example with opam):

- `dune`
- `yojson`
- `yaml`

Then:

- `dune build`

---

## CLI usage

Syntax:

- `./scanner [--json] [--policy <file.json>] [--entropy-threshold <float>] [--min-entropy-length <int>] <target-file>`

Important:

- Do **not** use `--yaml` or `--imp` flags.
- File type is auto-detected from extension.

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

---

## Custom Policy File

You can provide a custom JSON policy file to extend scanner behavior:

- `--policy <file.json>`

Quick examples (non-default policy):

- JSON:
  - `./scanner --policy examples/policy.custom.json --json examples/sample.json`
- YAML:
  - `./scanner --policy examples/policy.custom.json examples/sample.yaml`
  - `./scanner --policy examples/policy.custom.json --json examples/sample.yaml`
- IMP:
  - `./scanner --policy examples/policy.custom.json examples/sample.imp`
  - `./scanner --policy examples/policy.custom.json --json examples/sample.imp`

Important:

- Do **not** use `--yaml` or `--imp` flags.
- The scanner auto-detects type from the file extension (`.json`, `.yaml`, `.yml`, `.imp`).

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

See [POLICY_GUIDE.md](POLICY_GUIDE.md) for a full policy authoring guide and template workflow.

---

## Detection details

- Secret detection is key-aware (e.g., names containing `password`, `apikey`, `token`, `secret`).
- Misconfiguration detection includes:
  - `debug = true`
  - `ssl_verify = false`
  - `allow_insecure = true`
  - plus custom keys from policy
- Entropy detection checks long-enough strings and flags likely secrets.
- False-positive reduction includes ignored placeholder values and minimum length thresholds.

## Optional tuning flags

- `--entropy-threshold <float>` (default `3.8`)
- `--min-entropy-length <int>` (default `10`)

Example:

`./scanner --entropy-threshold 4.0 --min-entropy-length 12 config.yaml`

---

## Output format

Each finding includes:

- `category` (`SECRET` / `MISCONFIG`)
- `severity`
- `issue_type`
- `key`
- `path`
- `line`
- `source`
- `risk`
- `recommendation`
- `explanation`

Text mode prints human-readable blocks.
JSON mode prints an array of structured finding objects.

## Exit codes

- `0`: scan succeeded, no findings
- `2`: scan succeeded, findings produced
- `1`: parse/usage/runtime error

---

## Common mistakes

- Passing unsupported flags like `--yaml` (not needed).
- Using unsupported file extensions.
- Policy file not valid JSON or wrong field types.

If there is a policy/parse error, the scanner prints a specific message and exits with code `1`.
