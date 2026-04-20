# Security Scanner Description

This project is a modular static analysis scanner written in OCaml. It inspects three input formats:

- IMP-Core files (`.imp`)
- JSON files (`.json`)
- YAML files (`.yaml`, `.yml`)

It detects:

- Hardcoded secrets (passwords, API keys, tokens, secrets)
- High-entropy string literals likely to be secrets
- Dangerous misconfigurations (`debug = true`, `ssl_verify = false`, `allow_insecure = true`)

---

## High-Level Flow

1. **CLI receives file path and optional flags** in `src/main.ml`.
2. **File type is auto-detected** in `src/scanner.ml` using extension.
3. Input is parsed into structured data:
   - IMP → AST (`src/parser.ml` + `src/ast.ml`)
   - JSON → recursive entries (`src/jsonScanner.ml`)
   - YAML → recursive entries (`src/yamlScanner.ml`)
4. **Rules engine** in `src/rules.ml` analyzes each key/value with context.
5. Findings are formatted in `src/report.ml` as text or JSON output.

---

## Module-by-Module

- **`src/ast.ml`**
  - Defines IMP AST types:
    - `expr = String | Bool | Number`
    - `stmt = Assign of variable * expr * line`

- **`src/parser.ml`**
  - Parses lines like `x := "value"`, `debug := true`.
  - Tracks source line numbers.
  - Supports comments and basic string escaping.

- **`src/jsonScanner.ml`**
  - Uses `Yojson.Safe`.
  - Recursively walks nested objects/lists.
  - Produces flattened entries with:
    - key name
    - parent path
    - scalar value
    - best-effort line number mapping

- **`src/yamlScanner.ml`**
  - Uses `Yaml` library.
  - Recursively walks mappings/sequences.
  - Produces the same normalized entry format as JSON scanner.

- **`src/entropy.ml`**
  - Implements Shannon entropy:
    - character frequency table
    - computes $-\sum p_i \log_2(p_i)$

- **`src/rules.ml`**
  - Core detection logic.
  - Key normalization removes separators and case differences.
  - Secret detection by semantic key match (`password`, `apikey`, `token`, `secret`).
  - Misconfiguration checks for risky booleans.
  - High-entropy detection for long-enough strings over threshold.
  - False-positive reduction:
    - ignores placeholder values (`test`, `example`, etc.)
    - minimum string length gate
    - stronger entropy signal requirement

- **`src/scanner.ml`**
  - Orchestrates per-format scanning.
  - Converts parsed data into a common scalar form.
  - Sends entries to rules engine.

- **`src/types.ml`**
  - Shared data model:
    - `scalar`
    - `finding`
    - `severity`
    - category/source enums

- **`src/report.ml`**
  - Renders findings as:
    - human-readable text blocks
    - pretty JSON array

- **`src/main.ml`**
  - CLI argument handling.
  - Supports dynamic tuning:
    - `--json`
    - `--entropy-threshold <float>`
    - `--min-entropy-length <int>`

---

## Detection Strategy Details

### 1) Context-Aware Secret Detection
The scanner does not rely on regex-only matching. It uses key semantics and value type context:

- If key indicates sensitive intent (e.g., `db_password`, `api_key`) and value is inline string literal → flag secret.

### 2) Entropy-Based Detection
For candidate strings with length above threshold, entropy is computed.

- If entropy is high enough and signal is strong, finding is reported.
- This catches random-looking tokens even when naming is imperfect.

### 3) Misconfiguration Detection
Boolean config values are inspected after normalization:

- `debug=true`
- `ssl_verify=false`
- `allow_insecure=true`

---

## Output Shape

Each finding includes:

- category (`SECRET` / `MISCONFIG`)
- issue type
- key name
- path
- line number
- risk explanation
- recommendation
- severity
- source format

Exit codes:

- `0` = no findings
- `2` = findings produced
- `1` = parse/runtime/usage error

---

## Build and Run

Build:

- `dune build`

Run:

- `./scanner path/to/file.imp`
- `./scanner path/to/file.json`
- `./scanner path/to/file.yaml`
- `./scanner --json path/to/file.yaml`

---

## Extensibility Notes

The architecture is designed for growth:

- Add new rules in `src/rules.ml`
- Add new input format scanner and normalize to shared entry shape
- Add severity tuning and policy profiles through config structs
- Add directory recursion and ignore-file support on top of `src/main.ml` + `src/scanner.ml`
