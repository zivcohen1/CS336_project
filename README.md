# AST-Based Secret & Misconfiguration Scanner (OCaml)

A modular static scanner that parses source files into structured representations and detects hardcoded secrets, high-entropy strings, and insecure configurations.

---

## Team Members and Roles

| Member | Role |
| --- | --- |
| Ziv Cohen | Project Manager & Overview, Report, `policy.ml` |
| Zaccery Tarver | Lead Requirements Designer, Entropy Researcher |
| James Pazik | Parser Designer |

---

## What This Tool Does

Given an input file (`.imp`, `.json`, `.yaml`, `.yml`), the scanner:

1. Parses it into structured data (AST/tree, not regex-only scanning).
2. Applies context-aware rules based on key names and value types.
3. Computes Shannon entropy for candidate strings.
4. Produces findings with line number, issue type, key, risk, and recommendation.

Detects:

- Hardcoded secrets (`password`, `token`, `api_key`, etc.)
- High-entropy strings (likely secrets)
- Insecure configurations (`debug=true`, `ssl_verify=false`, `allow_insecure=true`)

---

## Prerequisites and Dependencies

- [opam](https://opam.ocaml.org/) (OCaml package manager)
- OCaml >= 4.14
- `dune` (build system)
- `yojson` (JSON parsing)
- `yaml` (YAML parsing)

Install dependencies with opam:

```sh
opam install dune yojson yaml
```

---

## Build Instructions

```sh
dune build
```

---

## How to Run the Tool

**CLI syntax:**

```sh
./scanner [--json] [--policy <file.json>] [--entropy-threshold <float>] [--min-entropy-length <int>] <target-file>
```

File type is auto-detected from extension — do **not** use `--yaml` or `--imp` flags.

**macOS/Linux:**

```sh
./scanner path/to/file.imp
./scanner path/to/config.json
./scanner path/to/config.yaml
./scanner --json path/to/file.json
```

**Windows:**

```sh
scanner.cmd path\to\file.imp
scanner.cmd path\to\config.json
scanner.cmd --json path\to\file.json
```

**Direct dune (cross-platform):**

```sh
opam exec -- dune exec src/main.exe -- path/to/file.imp
dune exec src/main.exe -- path/to/file.imp
```

**Save JSON output to file:**

```sh
./scanner --json examples/sample.yaml > results.json
```

### Custom Policy File

Extend scanner behavior with a custom JSON policy:

```sh
./scanner --policy examples/policy.custom.json --json examples/sample.json
./scanner --policy examples/policy.custom.json examples/sample.yaml
```

Supported policy fields:

- `entropy_threshold` (number)
- `min_entropy_length` (integer)
- `ignored_values` (string array)
- `secret_patterns` (string array): additional key patterns treated as secret-like
- `misconfig_true_keys` (string array): keys flagged when set to `true`
- `misconfig_false_keys` (string array): keys flagged when set to `false`

See [POLICY_GUIDE.md](POLICY_GUIDE.md) for a full policy authoring guide and template workflow.

### Optional Tuning Flags

- `--entropy-threshold <float>` (default `3.8`)
- `--min-entropy-length <int>` (default `10`)

```sh
./scanner --entropy-threshold 4.0 --min-entropy-length 12 config.yaml
```

---

## How to Run Tests

```sh
dune runtest
```

---

## Example Commands with Expected Output

**Scan a YAML config file (text output):**

```text
./scanner examples/sample.yaml

[SECRET] password at line 3
  Key:    password
  Path:   config.password
  Risk:   Hardcoded credential may be exposed in version control
  Fix:    Use an environment variable or secrets manager

[MISCONFIG] debug at line 7
  Key:    debug
  Path:   config.debug
  Risk:   Debug mode enabled in configuration
  Fix:    Set debug to false in production

2 finding(s) — exit code 2
```

**Scan a JSON file with JSON output:**

```text
./scanner --json examples/sample.json

[
  {
    "category": "SECRET",
    "severity": "HIGH",
    "issue_type": "hardcoded_secret",
    "key": "api_key",
    "path": "app.api_key",
    "line": 5,
    "source": "examples/sample.json",
    "risk": "Hardcoded API key may be exposed",
    "recommendation": "Move to environment variable",
    "explanation": "Key name matches secret pattern"
  }
]
```

**Scan with a custom policy:**

```sh
./scanner --policy examples/policy.json --json examples/sample.yaml
```

**Scan an IMP file:**

```sh
./scanner examples/sample.imp
```

---

## Output Format

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

---

## Exit Codes

| Code | Meaning |
| --- | --- |
| `0` | Scan succeeded, no findings |
| `2` | Scan succeeded, findings produced |
| `1` | Parse/usage/runtime error |

---

## Architecture

- `src/ast.ml` — IMP-Core AST (`Assign`, literals)
- `src/parser.ml` — IMP parser with line tracking
- `src/jsonScanner.ml` — recursive JSON traversal with path extraction
- `src/yamlScanner.ml` — recursive YAML traversal with path extraction
- `src/entropy.ml` — Shannon entropy implementation
- `src/rules.ml` — context-aware security/misconfiguration rules and thresholds
- `src/policy.ml` — loads and validates custom policy JSON, maps to runtime rule config
- `src/scanner.ml` — orchestrates parser/scanners + rule engine
- `src/report.ml` — text and JSON reporting
- `src/main.ml` — CLI entrypoint
- `src/types.ml` — shared finding/value types

---

## Common Mistakes

- Passing unsupported flags like `--yaml` (not needed — type is auto-detected).
- Using unsupported file extensions.
- Policy file not valid JSON or wrong field types.

If there is a policy/parse error, the scanner prints a specific message and exits with code `1`.
