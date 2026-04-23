# Policy Guide (for classmates)

This scanner supports custom policy files so anyone can define their own rules without editing OCaml code.

## 1) Create a policy JSON file

Copy the template in [examples/policy.template.json](examples/policy.template.json) and rename it, for example:

- `my-policy.json`

## 2) Run scanner with the policy

From project root:

- `./scanner --policy my-policy.json target-file.yaml`
- `./scanner --policy my-policy.json --json target-file.json`
- `./scanner --policy my-policy.json --json target-file.imp > results.json`

YAML and IMP examples:

- `./scanner --policy my-policy.json examples/sample.yaml`
- `./scanner --policy my-policy.json --json examples/sample.yaml`
- `./scanner --policy my-policy.json examples/sample.imp`
- `./scanner --policy my-policy.json --json examples/sample.imp`

Important:

- Do **not** use `--yaml` or `--imp` flags.
- The scanner auto-detects file type from extension (`.json`, `.yaml`, `.yml`, `.imp`).

If your classmate is on Windows and uses the Windows wrapper:

- `scanner.cmd --policy my-policy.json target-file.yaml`

## 3) Validate that the policy file is correct

Use any known sample file to smoke-test the policy:

- `./scanner --policy my-policy.json --json examples/sample.yaml`

If the policy JSON is malformed or has wrong field types, scanner exits with code `1` and prints an error.

Perfect Test: 

- `./scanner --policy examples/policy.json  --json examples/sample.json`

---

## Policy format

Top-level must be a JSON object.

All fields are optional.

```json
{
  "entropy_threshold": 3.8,
  "min_entropy_length": 10,
  "ignored_values": ["test", "example"],
  "secret_patterns": ["client_secret", "private_key", "auth_token"],
  "misconfig_true_keys": ["allow_http", "public_access"],
  "misconfig_false_keys": ["mfa_enabled", "encryption_enabled"]
}
```

### Field meanings

- `entropy_threshold` (number)
  - Minimum Shannon entropy for high-entropy secret findings.
- `min_entropy_length` (integer)
  - Minimum string length before entropy checks run.
- `ignored_values` (array of strings)
  - Values ignored by rules (case-insensitive).
- `secret_patterns` (array of strings)
  - Extra key-name patterns treated as secret-like.
  - Example: `"client_secret"` matches keys like `payment_client_secret`.
- `misconfig_true_keys` (array of strings)
  - Keys flagged as insecure when set to `true`.
- `misconfig_false_keys` (array of strings)
  - Keys flagged as insecure when set to `false`.

---

## Practical tips for classmates

- Keep key names descriptive in policy (for example `cert_validation`, `allow_http`).
- Start with defaults, then add only 2–5 custom keys at a time.
- Re-run on a known sample after each change.
- Save output to file for submissions:
  - `./scanner --policy my-policy.json --json config.yaml > findings.json`

## Exit codes

- `0` = scan ran, no findings
- `2` = scan ran, findings found
- `1` = usage/policy/parse/runtime error
