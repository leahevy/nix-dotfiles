#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../"
REPO_ROOT="$(pwd)"

export BOOTSTRAP_NEEDS_NIX=true
source "$SCRIPT_DIR/../utils/pre-check.sh"

if [[ "$UID" == 0 ]]; then
  echo -e "${RED}Do NOT run as root!${RESET}" >&2
  exit 1
fi

if [[ "$PWD" != "$HOME/.config/nx/nxcore" ]]; then
  echo -e "${RED}Enclosing configuration directory must be placed at ${WHITE}$HOME/.config/nx/nxcore${RESET}" >&2
  exit 1
fi

perm=$(ls -ld "$PWD" | awk '{print $1}')
owner=$(ls -ld "$PWD" | awk '{print $3}')

if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
  echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
  exit 1
fi
# ===================================================== #

CONFIG_DIR=""
if [[ -d "$HOME/.config/nx/nxconfig" ]]; then
    CONFIG_DIR="$HOME/.config/nx/nxconfig"
    export CONFIG_DIR
    check_git_worktrees_clean
else
    if [[ "$(git status --porcelain)" != "" ]]; then
        echo -e "${RED}!!! Git worktree is dirty!${RESET}" >&2
        echo >&2
        echo -e "Main repository ${WHITE}(.config/nx/nxcore)${RESET}:" >&2
        git status --porcelain >&2
        echo >&2
        exit 1
    fi
fi

EXTRA_ARGS=()

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
TIMEOUT=3600

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --timeout)
      TIMEOUT="${2:-3600}"
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
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Build a NixOS live ISO with the nxcore repository embedded."
      echo "The ISO is built for the current host architecture ($SYSTEM)."
      echo ""
      echo "Options:"
      echo "  --timeout SECONDS              Build timeout in seconds (default: 3600)"
      echo "  --output-dir DIR               Output directory (default: ./result)"
      echo "  --offline                      Build without network access"
      echo "  --help                         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                             # Build for host architecture"
      echo "  $0 --offline                   # Build without network access"
      echo "  $0 --timeout 7200               # Build with 2-hour timeout"
      exit 0
      ;;
    -*|--*)
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

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
  if [[ -n "${CONFIG_DIR:-}" ]] && [[ -f "$CONFIG_DIR/.git-crypt-key" ]]; then
    echo -e "${YELLOW}Cleaning up git-crypt key...${RESET}"
    rm -f "$CONFIG_DIR/.git-crypt-key"
  fi
}
trap cleanup EXIT

echo -e "${GREEN}Building NixOS ISO for architecture: ${WHITE}$SYSTEM${RESET}"
echo -e "Output directory: ${WHITE}$OUTPUT_DIR${RESET}"

echo ""

ISO_NAME="nxcore-${SYSTEM}-$(date +"%d-%m-%y_%H-%M").iso"

if [[ -n "$CONFIG_DIR" ]]; then
    echo -e "Using config directory: ${WHITE}$CONFIG_DIR${RESET}"
    EXTRA_ARGS+=("--override-input" "config" "path:$CONFIG_DIR")
    
    if [[ -d "$CONFIG_DIR/.git/git-crypt" ]]; then
        echo -e "${GREEN}Detected git-crypt encryption in config repository${RESET}"
        echo -e "Exporting git-crypt key for ISO..."
        
        cd "$CONFIG_DIR"
        if git-crypt export-key "$CONFIG_DIR/.git-crypt-key"; then
            echo -e "${GREEN}Git-crypt key exported successfully${RESET}"
            cd "$REPO_ROOT"
        else
            echo -e "${RED}Error: Failed to export git-crypt key${RESET}" >&2
            echo -e "Make sure the repository is unlocked and you have ${WHITE}git-crypt${RESET} installed" >&2
            cd "$REPO_ROOT"
            exit 1
        fi
    else
        echo -e "Config repository is not encrypted (no git-crypt detected)"
    fi
fi

echo -e "${YELLOW}Building ISO image (this may take a while)...${RESET}"
timeout "${TIMEOUT}s" nix build --impure ".#isoConfigurations.$SYSTEM.config.system.build.isoImage" "${EXTRA_ARGS[@]:-}" -o "$TEMP_DIR/result"

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
echo -e "${GREEN}ISO created: ${WHITE}$OUTPUT_DIR/$ISO_NAME${RESET}"

echo -e "Generating SHA256 checksum..."
cd "$OUTPUT_DIR"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
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
