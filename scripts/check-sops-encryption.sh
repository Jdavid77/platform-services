#!/usr/bin/env bash
set -euo pipefail

status=0
for file in "$@"; do
  if ! grep -q '^sops:' "$file" || ! grep -q 'ENC\[AES256_GCM' "$file"; then
    echo "Not SOPS-encrypted: $file"
    status=1
  fi
done

exit "$status"
