#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"

export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/pre-check.sh"

if [[ ! -f /etc/NIXOS ]]; then
  echo -e "${RED}Did not detect NixOS -> aborting migration...${RESET}" >&2
  exit 1
fi

if [[ "$UID" != 0 ]]; then
  echo -e "${RED}Requires root!${RESET}" >&2
  exit 1
fi

DRY_RUN=""
IS_DRY_RUN=0
HOSTNAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN="echo"
      IS_DRY_RUN=1
      shift
      ;;
    -*)
      echo -e "${RED}Error: Unknown option ${WHITE}$1${RESET}" >&2
      echo -e "${RED}Usage: ${WHITE}$0${RED} [--dry-run|-n] <HOSTNAME>${RESET}" >&2
      exit 1
      ;;
    *)
      HOSTNAME="$1"
      shift
      ;;
  esac
done

if [[ "$HOSTNAME" = "" ]]; then
  echo -e "${RED}Usage: ${WHITE}$0${RED} [--dry-run|-n] <HOSTNAME>${RESET}" >&2
  echo -e "${RED}Run with ${WHITE}<HOSTNAME>${RED} argument (from ${WHITE}/nxconfig/profiles/nixos${RED})!${RESET}" >&2
  exit 1
fi

check_config_directory "migrate-to-persistence" "bootstrap"

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

echo -e "Checking if impermanence is enabled for $HOSTNAME..."
FULL_PROFILE="$(construct_profile_name "$HOSTNAME")"

IMPERMANENCE_ENABLED="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$FULL_PROFILE.host.impermanence" 2>/dev/null || echo "false")"

if [[ "$IMPERMANENCE_ENABLED" != "true" ]]; then
  echo -e "Info: Impermanence is disabled for ${WHITE}$HOSTNAME${RESET}"
  echo -e "${GREEN}Skipping migration - system will use standard persistence${RESET}"
  exit 0
fi

echo -e "${GREEN}Impermanence enabled, proceeding with persistence migration...${RESET}"

if [[ ! -e "/mnt/etc/NIXOS" && ! -e "/mnt/persist/etc/NIXOS" ]]; then
  echo -e "${RED}Error: NixOS installation not found at ${WHITE}/mnt${RESET}" >&2
  echo -e "${RED}Please run nixos-install first${RESET}" >&2
  exit 1
fi

USERNAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$FULL_PROFILE.host.mainUser.username" 2>/dev/null || echo "null")"
if [[ -z "$USERNAME" || "$USERNAME" == "null" || "$USERNAME" == "\"null\"" ]]; then
  echo -e "${RED}Error: Could not determine main user from host configuration for ${WHITE}$HOSTNAME${RESET}" >&2
  exit 1
fi
USERNAME="${USERNAME//\"/}"

USER_UID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.uid")"
GROUP_NAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.group")"

if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$GROUP_NAME" || "$GROUP_NAME" == "null" ]]; then
  echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
  exit 1
fi

USER_UID="${USER_UID//\"/}"
GROUP_NAME="${GROUP_NAME//\"/}"

USER_GID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.groups.$GROUP_NAME.gid")"
if [[ -z "$USER_GID" || "$USER_GID" == "null" ]]; then
  echo -e "${RED}Error: Failed to extract valid group GID for group ${WHITE}$GROUP_NAME${RESET}" >&2
  exit 1
fi
USER_GID="${USER_GID//\"/}"

if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$USER_GID" || "$USER_GID" == "null" ]]; then
  echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
  exit 1
fi

echo
echo -e "${MAGENTA}Migrating nixos-install generated files to persistence storage...${RESET}"
echo -e "${MAGENTA}Main user: ${WHITE}$USERNAME${MAGENTA} (UID: ${WHITE}$USER_UID${MAGENTA}, GID: ${WHITE}$USER_GID${MAGENTA})${RESET}"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${WHITE}Creating persistence directory structure...${RESET}"
  $DRY_RUN mkdir -p /mnt/persist/home
  
  echo -e "Extracting persistence requirements from NixOS configuration..."
  
  PERSIST_SYSTEM="/persist"
  PERSIST_USER_FULL="/persist/home/$USERNAME"
  
  IGNORE_SYSTEM_FILES=(
    "/etc/.clean"
    "/etc/kernel/entry-token"
    "/root/.nix-channels"
    "/etc/group"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/subuid"
    "/etc/subgid"
    "/etc/sudoers"
  )
  
  IGNORE_USER_FILES=()
  
  migrate_system_directory() {
    local dir="$1"
    if [[ -d "/mnt/persist$dir" ]]; then
      echo -e "${YELLOW}  -> $dir (already migrated, skipping)${RESET}"
    elif [[ -d "/mnt$dir" ]]; then
      echo -e "${GREEN}  -> $dir (exists, migrating with permissions)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist$(dirname "$dir")"
      $DRY_RUN rsync -av "/mnt$dir/" "/mnt/persist$dir/"
      $DRY_RUN rm -rf "/mnt$dir"
    else
      echo -e "${GREEN}  -> $dir (not found, creating empty directory)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist$dir"
    fi
  }
  
  migrate_system_file() {
    local file="$1"
    if [[ -f "/mnt/persist$file" ]]; then
      echo -e "${YELLOW}  -> $file (already migrated, skipping)${RESET}"
    elif [[ -f "/mnt$file" ]]; then
      echo -e "${GREEN}  -> $file (exists, migrating)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist$(dirname "$file")"
      $DRY_RUN rsync -av "/mnt$file" "/mnt/persist$file"
      $DRY_RUN rm "/mnt$file"
    fi
  }
  
  migrate_user_directory() {
    local dir="$1"
    local user="$2"
    local full_path="/mnt/home/$user/$dir"
    if [[ -d "/mnt/persist/home/$user/$dir" ]]; then
      echo -e "${YELLOW}  -> ~/$dir (already migrated, skipping)${RESET}"
    elif [[ -d "$full_path" ]]; then
      echo -e "${GREEN}  -> ~/$dir (exists, migrating with permissions)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist/home/$user/$(dirname "$dir")"
      $DRY_RUN rsync -av "$full_path/" "/mnt/persist/home/$user/$dir/"
      $DRY_RUN rm -rf "$full_path"
    else
      echo -e "${GREEN}  -> ~/$dir (not found, creating empty directory)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist/home/$user/$dir"
      $DRY_RUN chown "$USER_UID:$USER_GID" "/mnt/persist/home/$user/$dir"
    fi
  }
  
  migrate_user_file() {
    local file="$1" 
    local user="$2"
    local full_path="/mnt/home/$user/$file"
    if [[ -f "/mnt/persist/home/$user/$file" ]]; then
      echo -e "${YELLOW}  -> ~/$file (already migrated, skipping)${RESET}"
    elif [[ -f "$full_path" ]]; then
      echo -e "${GREEN}  -> ~/$file (exists, migrating)${RESET}"
      $DRY_RUN mkdir -p "/mnt/persist/home/$user/$(dirname "$file")"
      $DRY_RUN rsync -av "$full_path" "/mnt/persist/home/$user/$file"
      $DRY_RUN rm "$full_path"
    fi
  }
  
  echo -e "${WHITE}Querying system persistence requirements...${RESET}"
  SYSTEM_PERSIST_DIRS="$(nix eval --json --override-input config "path:$CONFIG_DIR" \
    ".#nixosConfigurations.$FULL_PROFILE.config.environment.persistence.\"$PERSIST_SYSTEM\".directories" 2>/dev/null \
    | jq -r '.[] | if type == "string" then . else .directory end' 2>/dev/null || echo "")"
  
  SYSTEM_PERSIST_FILES="$(nix eval --json --override-input config "path:$CONFIG_DIR" \
    ".#nixosConfigurations.$FULL_PROFILE.config.environment.persistence.\"$PERSIST_SYSTEM\".files" 2>/dev/null \
    | jq -r '.[] | if type == "string" then . else .file end' 2>/dev/null || echo "")"
  
  echo -e "Querying user persistence requirements for ${WHITE}$USERNAME${RESET}..."
  USER_PERSIST_DIRS="$(nix eval --json --override-input config "path:$CONFIG_DIR" \
    ".#nixosConfigurations.$FULL_PROFILE.config.home-manager.users.$USERNAME.home.persistence.\"$PERSIST_USER_FULL\".directories" 2>/dev/null \
    | jq -r '.[] | if type == "string" then . else .directory end' 2>/dev/null || echo "")"
  
  USER_PERSIST_FILES="$(nix eval --json --override-input config "path:$CONFIG_DIR" \
    ".#nixosConfigurations.$FULL_PROFILE.config.home-manager.users.$USERNAME.home.persistence.\"$PERSIST_USER_FULL\".files" 2>/dev/null \
    | jq -r '.[] | if type == "string" then . else .file end' 2>/dev/null || echo "")"
  
  echo
  echo -e "${WHITE}Migrating system directories...${RESET}"
  if [[ -n "$SYSTEM_PERSIST_DIRS" ]]; then
    while IFS= read -r dir; do
      [[ -n "$dir" ]] && migrate_system_directory "$dir"
    done <<< "$(echo "$SYSTEM_PERSIST_DIRS" | sort)"
  else
    echo -e "  -> No system directories declared for persistence"
  fi
  
  echo
  echo -e "${WHITE}Migrating system files...${RESET}"
  if [[ -n "$SYSTEM_PERSIST_FILES" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && migrate_system_file "$file"
    done <<< "$(echo "$SYSTEM_PERSIST_FILES" | sort)"
  else
    echo -e "  -> No system files declared for persistence"
  fi
  
  echo
  echo -e "${WHITE}Ensuring critical system files...${RESET}"
  if [[ ! -f "/mnt/persist/etc/machine-id" ]]; then
    if [[ -f "/mnt/etc/machine-id" ]]; then
      echo -e "  -> /etc/machine-id (critical, migrating)"
      $DRY_RUN mkdir -p "/mnt/persist/etc"
      $DRY_RUN cp -p "/mnt/etc/machine-id" "/mnt/persist/etc/"
    else
      echo -e "  -> /etc/machine-id (critical, generating)"
      $DRY_RUN mkdir -p "/mnt/persist/etc"
      if (( IS_DRY_RUN )); then
        echo "systemd-machine-id-setup --root=/mnt/persist || dbus-uuidgen > /mnt/persist/etc/machine-id"
      else
        if ! systemd-machine-id-setup --root=/mnt/persist; then
          echo -e "${RED}Error: systemd-machine-id-setup failed, cannot generate ${WHITE}/etc/machine-id${RESET}" >&2
          exit 1
        fi
      fi
    fi
  fi
  
  echo
  echo -e "Migrating user directories for ${WHITE}$USERNAME${RESET}..."
  if [[ -n "$USER_PERSIST_DIRS" ]]; then
    while IFS= read -r dir; do
      [[ -n "$dir" ]] && migrate_user_directory "$dir" "$USERNAME"
    done <<< "$(echo "$USER_PERSIST_DIRS" | sort)"
  else
    echo -e "  -> No user directories declared for persistence"
  fi
  
  echo
  echo -e "Migrating user files for ${WHITE}$USERNAME${RESET}..."  
  if [[ -n "$USER_PERSIST_FILES" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && migrate_user_file "$file" "$USERNAME"
    done <<< "$(echo "$USER_PERSIST_FILES" | sort)"
  else
    echo -e "  -> No user files declared for persistence"
  fi
  
  echo
  echo -e "${WHITE}Ensuring user home directory structure...${RESET}"
  $DRY_RUN mkdir -p "/mnt/persist/home/$USERNAME"
  
  echo
  echo -e "${WHITE}Setting ownership for persistent data...${RESET}"
  [[ -d "/mnt/persist/etc" ]] && $DRY_RUN chown -R 0:0 /mnt/persist/etc
  [[ -d "/mnt/persist/var" ]] && $DRY_RUN chown -R 0:0 /mnt/persist/var  
  [[ -d "/mnt/persist/home/$USERNAME" ]] && $DRY_RUN chown -R "$USER_UID:$USER_GID" "/mnt/persist/home/$USERNAME"
  [[ -d "/mnt/persist/home/$USERNAME" ]] && $DRY_RUN chmod 700 "/mnt/persist/home/$USERNAME"
  
  echo
  echo -e "Creating impermanence marker file at ${WHITE}/etc/IMPERMANENCE${RESET}..."
  if (( IS_DRY_RUN )); then
    echo "echo IMPERMANENCE_ENABLED=true > /mnt/persist/etc/IMPERMANENCE"
    echo -e "echo MIGRATION_DATE=$(date -Iseconds) >> /mnt/persist/etc/IMPERMANENCE"
    echo "echo MIGRATION_SCRIPT=60-migrate-to-persistence.sh >> /mnt/persist/etc/IMPERMANENCE"
  else
    echo "IMPERMANENCE_ENABLED=true" > /mnt/persist/etc/IMPERMANENCE
    echo -e "MIGRATION_DATE=$(date -Iseconds)" >> /mnt/persist/etc/IMPERMANENCE
    echo "MIGRATION_SCRIPT=60-migrate-to-persistence.sh" >> /mnt/persist/etc/IMPERMANENCE
  fi
  
  echo
  echo -e "${WHITE}Checking existing files which were not migrated...${RESET}"
  
  PERSIST_PATHS=()
  [[ -n "$SYSTEM_PERSIST_DIRS" ]] && while IFS= read -r dir; do [[ -n "$dir" ]] && PERSIST_PATHS+=("$dir"); done <<< "$SYSTEM_PERSIST_DIRS"
  [[ -n "$SYSTEM_PERSIST_FILES" ]] && while IFS= read -r file; do [[ -n "$file" ]] && PERSIST_PATHS+=("$file"); done <<< "$SYSTEM_PERSIST_FILES"
  [[ -n "$USER_PERSIST_DIRS" ]] && while IFS= read -r dir; do [[ -n "$dir" ]] && PERSIST_PATHS+=("/home/$USERNAME/$dir"); done <<< "$USER_PERSIST_DIRS"
  [[ -n "$USER_PERSIST_FILES" ]] && while IFS= read -r file; do [[ -n "$file" ]] && PERSIST_PATHS+=("/home/$USERNAME/$file"); done <<< "$USER_PERSIST_FILES"
  
  is_ephemeral() {
    local item_path="$1"
    
    for persist_path in "${PERSIST_PATHS[@]}"; do
      if [[ "$item_path" == "$persist_path" ]]; then
        return 1
      fi
    done
    
    if [[ ${#IGNORE_SYSTEM_FILES[@]} -gt 0 ]]; then
      for ignore_file in "${IGNORE_SYSTEM_FILES[@]}"; do
        if [[ "$item_path" == "$ignore_file" ]]; then
          return 1
        fi
      done
    fi
    
    if [[ ${#IGNORE_USER_FILES[@]} -gt 0 ]]; then
      for ignore_file in "${IGNORE_USER_FILES[@]}"; do
        if [[ "$item_path" == "/home/$USERNAME/$ignore_file" ]]; then
          return 1
        fi
      done
    fi
    
    return 0
  }
  
  EPHEMERAL_ITEMS=()
  while IFS= read -r item; do
    item_path="${item#/mnt}"
    if is_ephemeral "$item_path"; then
      EPHEMERAL_ITEMS+=("$item_path")
    fi
  done < <(find /mnt -type f ! -lname "/nix/store/*" ! -path "/mnt/persist/*" ! -path "/mnt/boot/*" ! -path "/mnt/nix/*" ! -path "/mnt/dev/*" ! -path "/mnt/proc/*" ! -path "/mnt/run/*" ! -path "/mnt/sys/*" ! -path "/mnt/tmp/*" ! -path "/mnt/var/lib/nixos/*" ! -path "/mnt/var/log/*")
  
  if [[ ${#EPHEMERAL_ITEMS[@]} -gt 0 ]]; then
    echo
    echo -e "⚠️  ${RED}WARNING: Files/directories that will be DESTROYED on first boot:${RESET}"
    echo
    for item in "${EPHEMERAL_ITEMS[@]}"; do
      echo -e " ${RED}$item${RESET}"
    done
  else
    echo
    echo -e "${GREEN}All files were successfully migrated!${RESET}"
  fi
  
  echo
  echo
  echo -e "${GREEN}Persistent structure created:${RESET}"
  echo -e "  ${WHITE}/persist/${RESET}         - System files/directories"
  echo -e "  ${WHITE}/persist/home/${RESET}    - User files/directories" 
else
  exit 0
fi
