#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "# Checking files at path $PWD"
find . -type f -print0 | while IFS= read -r -d '' file; do
  if [[ "$(echo "$file" | grep .git)" = "" ]]; then
    if sops -d "$file" >/dev/null 2>&1; then
        echo "++ Updating keys for encrypted file: $file"
        sops updatekeys --yes "$file"
    else
        echo "-- DO not update file: $file"
    fi
  fi
done
