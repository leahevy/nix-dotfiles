#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/pre-check.sh"

if [ ! -e /etc/NIXOS ]; then
  echo -e "${RED}Error: This script must be run on a NixOS live system${RESET}" >&2
  exit 1
fi

if [ ! -d /nxconfig ]; then
  echo -e "${RED}Error: ${WHITE}/nxconfig${RED} directory not found${RESET}" >&2
  echo -e "${RED}Make sure the ${WHITE}nx-setup${RED} service has run successfully${RESET}" >&2
  exit 1
fi

cd /nxconfig

if [ ! -d .git ]; then
  echo -e "${RED}Error: ${WHITE}/nxconfig${RED} is not a git repository${RESET}" >&2
  echo -e "${RED}Make sure the ${WHITE}nx-config-git-init${RED} service has run successfully${RESET}"
  echo -e "This usually means ${WHITE}configRepoIsoUrl${RESET} is not configured in ${WHITE}variables.nix${RESET}" >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo -e "${RED}Error: No remote ${WHITE}'origin'${RED} configured in git repository${RESET}" >&2
  echo -e "${RED}Make sure the ${WHITE}nx-config-git-init${RED} service has run successfully${RESET}"
  exit 1
fi

REMOTE_URL="$(git remote get-url origin)"
echo -e "Config repository remote: ${WHITE}$REMOTE_URL${RESET}"
echo
echo -e "${GREEN}This script fetches the latest config repository from remote.${RESET}"
echo

USES_CRYPT=false
if [ -d .git/git-crypt ]; then
  USES_CRYPT=true
  echo -e "${GREEN}Detected git-crypt encryption in config repository${RESET}"
else
  echo -e "${GREEN}Config repository is not encrypted (no git-crypt detected)${RESET}"
fi

echo
echo -e "${GREEN}Checking network connectivity...${RESET}"
RETRY_COUNT=0
MAX_RETRIES=10
NETWORK_OK=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s --connect-timeout 5 --max-time 10 https://github.com >/dev/null 2>&1; then
    echo -e "Network connectivity established (attempt $((RETRY_COUNT + 1)))"
    NETWORK_OK=true
    break
  else
    echo -e "Network not ready, waiting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 3
  fi
done

if [ "$NETWORK_OK" != "true" ]; then
  echo -e "${RED}Error: Could not establish network connectivity after ${WHITE}$MAX_RETRIES${RED} attempts${RESET}" >&2
  echo -e "${RED}Please check your network connection and try again${RESET}" >&2
  exit 1
fi

echo
echo -e "${GREEN}Fetching latest config repository...${RESET}"
while true; do
  echo -e "${MAGENTA}You will be prompted for credentials if needed${RESET}"
  
  if git fetch origin main; then
    echo -e "${GREEN}Fetch successful!${RESET}"
    break
  else
    echo
    echo -e "${YELLOW}Fetch failed. This could be due to:${RESET}"
    echo -e "${YELLOW}- Authentication failure (wrong username/token)${RESET}"
    echo -e "${YELLOW}- Network issues${RESET}"
    echo -e "${YELLOW}- Repository access issues${RESET}"
    echo
    echo -e "${MAGENTA}Try again? (y/n)${RESET}"
    read -r retry
    if [[ "$retry" != "y" && "$retry" != "Y" ]]; then
      echo -e "${YELLOW}Aborted by user${RESET}"
      exit 1
    fi
  fi
done

echo -e "${GREEN}Updating working directory to latest remote state...${RESET}"
git reset --hard origin/main

if [ "$USES_CRYPT" = "true" ]; then
  echo -e "${GREEN}Repository uses git-crypt, attempting to unlock...${RESET}"
  
  CRYPT_KEY=""
  for pkg in /nix/store/*-nx-repositories*; do
    if [ -f "$pkg/keys/git-crypt-key" ]; then
      CRYPT_KEY="$pkg/keys/git-crypt-key"
      break
    fi
  done
  
  if [ -n "$CRYPT_KEY" ] && [ -f "$CRYPT_KEY" ]; then
    echo -e "${GREEN}Found git-crypt key, unlocking repository...${RESET}"
    if git-crypt unlock "$CRYPT_KEY"; then
      echo -e "${GREEN}Repository unlocked successfully${RESET} - deleting local git-crypt-key"
      rm -f .git-crypt-key
    else
      echo -e "${RED}Error: Failed to unlock repository with git-crypt${RESET}" >&2
      echo -e "${RED}Files may still be encrypted${RESET}" >&2
      exit 1
    fi
  else
    echo -e "${RED}Error: git-crypt key not found in ${WHITE}nx-repositories${RED} package${RESET}" >&2
    echo -e "${RED}The ISO was built without a git-crypt key - make sure the config repository${RESET}" >&2
    echo -e "${RED}was unlocked when the ISO was built, then rebuild the ISO.${RESET}" >&2
    exit 1
  fi
else
  echo -e "${YELLOW}Skipping git-crypt unlock (repository is not encrypted)${RESET}"
fi

echo
echo -e "${GREEN}Config repository successfully updated!${RESET}"
