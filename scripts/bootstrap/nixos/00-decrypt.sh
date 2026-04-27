#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

if [ ! -e /etc/NIXOS ]; then
  echo -e "${RED}Error: This script must be run on a NixOS live system${RESET}" >&2
  exit 1
fi

if [ ! -d /nxconfig ]; then
  echo -e "${RED}Error: ${WHITE}/nxconfig${RED} directory not found${RESET}" >&2
  exit 1
fi

if [ ! -d /nxconfig/.git/git-crypt ]; then
  echo -e "${YELLOW}Config repository is not encrypted (no git-crypt detected), nothing to do${RESET}"
  exit 0
fi

CRYPT_KEY=""
for pkg in /nix/store/*-nx-repositories*; do
  if [ -f "$pkg/keys/git-crypt-key" ]; then
    CRYPT_KEY="$pkg/keys/git-crypt-key"
    break
  fi
done

if [ -z "$CRYPT_KEY" ]; then
  echo -e "${RED}Error: git-crypt key not found in ${WHITE}nx-repositories${RED} package${RESET}" >&2
  echo -e "${RED}The ISO was built without a git-crypt key - rebuild the ISO with an unlocked repository${RESET}" >&2
  exit 1
fi

TEMP_KEY="$(mktemp)"
cleanup_temp() {
  shred -u "$TEMP_KEY" 2>/dev/null || rm -f "$TEMP_KEY"
}
trap cleanup_temp EXIT

MAX_ATTEMPTS=3
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo -e "${GREEN}Enter the password used when building the ISO (attempt $ATTEMPT/$MAX_ATTEMPTS):${RESET}"
  read -rs GIT_CRYPT_PASS
  echo
  if openssl enc -d -aes-256-cbc -pbkdf2 -in "$CRYPT_KEY" -out "$TEMP_KEY" -pass stdin 2>/dev/null <<< "$GIT_CRYPT_PASS"; then
    unset GIT_CRYPT_PASS
    break
  fi
  unset GIT_CRYPT_PASS
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo -e "${RED}Error: Maximum password attempts exceeded${RESET}" >&2
    exit 1
  fi
  echo -e "${RED}Wrong password, please try again${RESET}"
done

cd /nxconfig
if git-crypt unlock "$TEMP_KEY"; then
  echo -e "${GREEN}Repository unlocked successfully${RESET}"
else
  echo -e "${RED}Error: Failed to unlock repository with git-crypt${RESET}" >&2
  exit 1
fi
