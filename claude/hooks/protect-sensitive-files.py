#!/usr/bin/env python3
import sys, json
from pathlib import Path

SENSITIVE = {
    '.env', '.pem', '.key', '.credential', '.token',
    'credentials.json', 'service-account.json',
    'google-credentials.json', '.npmrc', '.netrc'
}

SENSITIVE_EXTENSIONS = {'.pem', '.key', '.p12', '.pfx'}

data = json.load(sys.stdin)
path_str = data.get('tool_input', {}).get('file_path', '')
if not path_str:
    sys.exit(0)

path = Path(path_str)

if path.name in SENSITIVE or path.suffix in SENSITIVE_EXTENSIONS:
    print(
        f"BLOCKED: '{path.name}' is a sensitive file. "
        f"Use environment variables for secrets rather than reading credential files directly.",
        file=sys.stderr
    )
    sys.exit(2)

sys.exit(0)
