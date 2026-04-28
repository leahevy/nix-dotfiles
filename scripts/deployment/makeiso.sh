#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME/.config/nx/nxconfig"
REPO_ROOT="$(pwd)"

export BOOTSTRAP_NEEDS_NIX=true
source "$SCRIPT_DIR/../utils/common.sh"

if [[ "$UID" == 0 ]]; then
  echo -e "${RED}Do NOT run as root!${RESET}" >&2
  exit 1
fi

if [[ "$PWD" != "$HOME/.config/nx/nxconfig" ]]; then
  echo -e "${RED}Enclosing configuration directory must be placed at ${WHITE}$HOME/.config/nx/nxconfig${RESET}" >&2
  exit 1
fi

# shellcheck disable=SC2012
perm=$(ls -ld "$PWD" | awk '{print $1}')
# shellcheck disable=SC2012
owner=$(ls -ld "$PWD" | awk '{print $3}')

if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
  echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
  exit 1
fi
# ===================================================== #

NXCORE_DIR="$HOME/.config/nx/nxcore"
export NXCORE_DIR
check_git_worktrees_clean
verify_commits

EXTRA_ARGS=()
SKIP_VERIFICATION=false

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "arm64" ]] || [[ "$HOST_ARCH" == "aarch64" ]]; then
  SYSTEM="aarch64-linux"
elif [[ "$HOST_ARCH" == "x86_64" ]]; then
  SYSTEM="x86_64-linux"
else
  echo -e "${RED}Unsupported host architecture: ${WHITE}$HOST_ARCH${RESET}" >&2
  exit 1
fi

OUTPUT_DIR="$(pwd)/result"
TIMEOUT=7200

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --timeout)
      TIMEOUT="${2:-7200}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-$OUTPUT_DIR}"
      shift 2
      ;;
    --offline)
      EXTRA_ARGS+=("--option" "substitute" "false")
      shift
      ;;
    --skip-verification)
      SKIP_VERIFICATION=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Build a NixOS live ISO with the nxcore repository embedded."
      echo "The ISO is built for the current host architecture ($SYSTEM)."
      echo ""
      echo "Options:"
      echo "  --timeout SECONDS              Build timeout in seconds (default: 7200)"
      echo "  --output-dir DIR               Output directory (default: ./result)"
      echo "  --offline                      Build without network access"
      echo "  --skip-verification            Skip commit signature verification"
      echo "  --help                         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                             # Build for host architecture"
      echo "  $0 --offline                   # Build without network access"
      echo "  $0 --timeout 7200               # Build with 2-hour timeout"
      exit 0
      ;;
    -*)
      echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}"
      echo -e "Use ${WHITE}--help${RESET} for usage information"
      exit 1
      ;;
    *)
      echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}"
      echo -e "Use ${WHITE}--help${RESET} for usage information"
      exit 1
      ;;
  esac
done

export SKIP_VERIFICATION

TEMP_DIR="$(mktemp -d)"
PLAIN_KEY_FILE=""
cleanup() {
  rm -rf "$TEMP_DIR"
  if [[ -f "$REPO_ROOT/.git-crypt-key" ]]; then
    echo
    echo -e "${YELLOW}Cleaning up git-crypt key...${RESET}"
    rm -f "$REPO_ROOT/.git-crypt-key"
  fi
  if [[ -n "$PLAIN_KEY_FILE" && -f "$PLAIN_KEY_FILE" ]]; then
    shred -u "$PLAIN_KEY_FILE" 2>/dev/null || rm -f "$PLAIN_KEY_FILE"
  fi
}
trap cleanup EXIT

echo -e "${GREEN}Building NixOS ISO for architecture: ${WHITE}$SYSTEM${RESET}"
echo -e "Output directory: ${WHITE}$OUTPUT_DIR${RESET}"

echo ""

ISO_NAME="nxcore-${SYSTEM}-$(date +"%d-%m-%y_%H-%M").iso"

if [[ -n "$NXCORE_DIR" ]]; then
    echo -e "Using core directory: ${WHITE}$NXCORE_DIR${RESET}"
    EXTRA_ARGS+=("--override-input" "core" "path:$NXCORE_DIR")

    if [[ -d "$REPO_ROOT/.git/git-crypt" ]]; then
        echo
        echo -e "${GREEN}Detected git-crypt encryption in config repository${RESET}"
        echo

        while true; do
            echo -e "${CYAN}Enter a password to protect the git-crypt key in the ISO:${RESET}"
            read -rs GIT_CRYPT_PASS1
            echo
            if [[ -z "$GIT_CRYPT_PASS1" ]]; then
                echo -e "${RED}Password must not be empty${RESET}"
                continue
            fi
            echo -e "${CYAN}Confirm password:${RESET}"
            read -rs GIT_CRYPT_PASS2
            echo
            if [[ "$GIT_CRYPT_PASS1" == "$GIT_CRYPT_PASS2" ]]; then
                break
            fi
            echo -e "${RED}Passwords do not match, please try again${RESET}"
        done

        echo -e "${WHITE}Exporting and encrypting git-crypt key for ISO...{RESET}"
        PLAIN_KEY_FILE="$(mktemp)"
        if git-crypt export-key "$PLAIN_KEY_FILE"; then
            if openssl enc -aes-256-cbc -pbkdf2 -in "$PLAIN_KEY_FILE" -out "$REPO_ROOT/.git-crypt-key" -pass stdin <<< "$GIT_CRYPT_PASS1"; then
                shred -u "$PLAIN_KEY_FILE" 2>/dev/null || rm -f "$PLAIN_KEY_FILE"
                PLAIN_KEY_FILE=""
                unset GIT_CRYPT_PASS1 GIT_CRYPT_PASS2
                echo
                echo -e "${GREEN}Git-crypt key exported and encrypted successfully${RESET}"
                echo
            else
                unset GIT_CRYPT_PASS1 GIT_CRYPT_PASS2
                echo
                echo -e "${RED}Error: Failed to encrypt git-crypt key${RESET}" >&2
                exit 1
            fi
        else
            unset GIT_CRYPT_PASS1 GIT_CRYPT_PASS2
            echo
            echo -e "${RED}Error: Failed to export git-crypt key${RESET}" >&2
            echo -e "Make sure the repository is unlocked and you have ${WHITE}git-crypt${RESET} installed" >&2
            exit 1
        fi
    else
        echo -e "Config repository is not encrypted (no git-crypt detected)"
    fi
fi

echo -e "${YELLOW}Building ISO image (this may take a while)...${RESET}"
timeout "${TIMEOUT}s" nix build "path:$(pwd)#isoConfigurations.$SYSTEM.config.system.build.isoImage" "${EXTRA_ARGS[@]:-}" -o "$TEMP_DIR/result"

if [[ ! -L "$TEMP_DIR/result" ]]; then
  echo -e "${RED}Error: Build failed - no store symlink created${RESET}" >&2
  exit 1
fi

ISO_FILE=$(find "$TEMP_DIR/result/" -name "*.iso" | head -1)
if [[ -z "$ISO_FILE" ]]; then
  echo -e "${RED}Error: No ISO file found in build result${RESET}" >&2
  exit 1
fi

echo -e "Copying ISO image out of store to ${WHITE}$OUTPUT_DIR/$ISO_NAME${RESET}"
mkdir -p "$OUTPUT_DIR"
cp "$ISO_FILE" "$OUTPUT_DIR/$ISO_NAME"
echo
echo -e "${GREEN}ISO created: ${WHITE}$OUTPUT_DIR/$ISO_NAME${RESET}"

echo -e "Generating SHA256 checksum..."
cd "$OUTPUT_DIR"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
echo
echo -e "${GREEN}Checksum created: ${WHITE}$OUTPUT_DIR/$ISO_NAME.sha256${RESET}"

echo ""
echo -e "${GREEN}=== ISO Build Complete ===${RESET}"
echo -e "${RED}ISO file:   ${WHITE}$OUTPUT_DIR/$ISO_NAME${RESET}"
echo -e "${RED}SHA256 SUM: ${WHITE}$(cat "$OUTPUT_DIR/$ISO_NAME.sha256" | cut -f 1 -d ' ')${RESET}"
echo -e "${RED}SHA256:     ${WHITE}$OUTPUT_DIR/$ISO_NAME.sha256${RESET}"
echo -e "${RED}Size:       ${WHITE}$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)${RESET}"
echo ""
echo -e "${YELLOW}To verify ISO integrity:${RESET}"
echo -e "  ${WHITE}cd $OUTPUT_DIR${RESET}"
echo -e "  ${WHITE}sha256sum -c $ISO_NAME.sha256${RESET}"
echo ""
echo -e "${YELLOW}To write to USB device (replace ${WHITE}/dev/sdX${RESET} with the device):${RESET}"
echo -e "  ${WHITE}sudo dd if=\"$OUTPUT_DIR/$ISO_NAME\" of=/dev/sdX bs=4M status=progress${RESET}"
echo ""
echo -e "${YELLOW}Validate USB device data with:${RESET}"
echo -e "  ${WHITE}sudo head -c \$(stat -c \"%s\" \"$OUTPUT_DIR/$ISO_NAME\") /dev/sdX | sha256sum${RESET}"
