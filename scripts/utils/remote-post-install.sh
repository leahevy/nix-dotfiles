#!/usr/bin/env bash
set -euo pipefail

MIGRATE_JSON="${1:-/tmp/migrate.json}"
[[ -f $MIGRATE_JSON ]] || {
	echo "migrate.json not found: $MIGRATE_JSON"
	exit 1
}

require_cmd() {
	local c="${1:-}"
	[[ -n "$c" ]] || return 0
	command -v "$c" >/dev/null 2>&1 || {
		echo "Missing required command: $c"
		exit 1
	}
}

reject_newlines() {
	local v="${1:-}" label="${2:-value}"
	if [[ "$v" == *$'\n'* || "$v" == *$'\r'* ]]; then
		echo "$label contains newline characters, refusing to operate!"
		exit 1
	fi
}

is_uint() {
	local v="${1:-}"
	[[ -n "$v" && "$v" != "null" ]] || return 1
	[[ "$v" =~ ^[0-9]+$ ]] || return 1
	return 0
}

validate_username() {
	local u="${1:-}"
	[[ -n "$u" && "$u" != "null" ]] || {
		echo "migrate.json: user is empty or null!"
		exit 1
	}
	reject_newlines "$u" "username"
	if [[ "$u" == *"/"* ]]; then
		echo "migrate.json: user contains '/': $u"
		exit 1
	fi
	if [[ ! "$u" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		echo "migrate.json: user contains unsafe characters: $u"
		exit 1
	fi
}

is_safe_system_path() {
	local p="${1:-}"
	[[ -n "$p" && "$p" != "null" ]] || return 1
	reject_newlines "$p" "system path"
	[[ "$p" == /* ]] || return 1
	[[ "$p" != "/" ]] || return 1
	[[ "$p" != "/." ]] || return 1
	[[ "$p" != "/.." ]] || return 1
	[[ "$p" != *"/./"* ]] || return 1
	[[ "$p" != *"/." ]] || return 1
	[[ "$p" != *".."* ]] || return 1
	return 0
}

is_safe_user_relpath() {
	local p="${1:-}"
	[[ -n "$p" && "$p" != "null" ]] || return 1
	reject_newlines "$p" "user relative path"
	[[ "$p" != "." ]] || return 1
	[[ "$p" != ".." ]] || return 1
	[[ "$p" != /* ]] || return 1
	[[ "$p" != *"/./"* ]] || return 1
	[[ "$p" != *"/." ]] || return 1
	[[ "$p" != *".."* ]] || return 1
	return 0
}

assert_under_dir() {
	local base="${1:-}" path="${2:-}"
	[[ -n "$base" && -n "$path" ]] || return 1
	case "$path" in
	"$base"/*) return 0 ;;
	*) return 1 ;;
	esac
}

require_cmd jq

IMPERMANENCE=$(jq -r '.impermanence' "$MIGRATE_JSON")
if [[ $IMPERMANENCE != "true" ]]; then
	echo "No impermanence configured. Nothing to migrate."
	exit 0
fi

require_cmd rsync
require_cmd git

PERSIST_SYSTEM=$(jq -r '.persist_path' "$MIGRATE_JSON")
USERNAME=$(jq -r '.user' "$MIGRATE_JSON")
USER_UID=$(jq -r '.uid' "$MIGRATE_JSON")
USER_GID=$(jq -r '.gid' "$MIGRATE_JSON")

validate_username "$USERNAME"
[[ -n "$PERSIST_SYSTEM" && "$PERSIST_SYSTEM" != "null" ]] || {
	echo "migrate.json: persist_path is empty or null!"
	exit 1
}
reject_newlines "$PERSIST_SYSTEM" "persist_path"
is_uint "$USER_UID" || {
	echo "migrate.json: uid is invalid!"
	exit 1
}
is_uint "$USER_GID" || {
	echo "migrate.json: gid is invalid!"
	exit 1
}

MNT_PERSIST="/mnt${PERSIST_SYSTEM}"

normalize_git_origin_url() {
	local url="$1"
	if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
		echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
		return 0
	fi
	echo "$url"
}

sanitize_repo_git() {
	local repo_dir="$1"

	[[ -d "$repo_dir/.git" ]] || return 0

	local remotes_out
	if ! remotes_out="$(git -c safe.directory="$repo_dir" -C "$repo_dir" remote 2>/dev/null)"; then
		echo "  warning: could not list remotes for $repo_dir, skipping remote sanitization"
		return 0
	fi

	local remotes=()
	while IFS= read -r remote; do
		[[ -n "$remote" ]] && remotes+=("$remote")
	done <<<"$remotes_out"

	local remote
	for remote in "${remotes[@]}"; do
		[[ "$remote" == "origin" ]] && continue
		if ! git -c safe.directory="$repo_dir" -C "$repo_dir" remote remove "$remote" >/dev/null 2>&1; then
			echo "  warning: could not remove remote '$remote' from $repo_dir"
		fi
	done

	local origin_url
	origin_url="$(git -c safe.directory="$repo_dir" -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")"
	if [[ -n "$origin_url" ]]; then
		local new_origin_url
		new_origin_url="$(normalize_git_origin_url "$origin_url")"
		if [[ "$new_origin_url" != "$origin_url" ]]; then
			if ! git -c safe.directory="$repo_dir" -C "$repo_dir" remote set-url origin "$new_origin_url" >/dev/null 2>&1; then
				echo "  warning: could not normalize origin URL for $repo_dir (was: $origin_url)"
			fi
		fi
	fi

	if ! git -c safe.directory="$repo_dir" -C "$repo_dir" checkout -- . >/dev/null 2>&1; then
		echo "  warning: could not reset tracked files in $repo_dir"
	fi
	if ! git -c safe.directory="$repo_dir" -C "$repo_dir" clean -fd --exclude='.nx-profile.conf' >/dev/null 2>&1; then
		echo "  warning: could not remove untracked files in $repo_dir"
	fi
}

migrate_system_directory() {
	local dir="$1"
	[[ -n "$dir" && "$dir" != "null" ]] || {
		echo "system directory path is empty or null, refusing to operate!"
		exit 1
	}
	is_safe_system_path "$dir" || {
		echo "system directory path is unsafe: $dir"
		exit 1
	}
	if [[ -d "/mnt$dir" ]]; then
		echo "  -> $dir (migrating)"
		mkdir -p "${MNT_PERSIST}$dir"
		rsync -av "/mnt$dir/" "${MNT_PERSIST}$dir/"
		rm -rf -- "/mnt${dir:?}"
	elif [[ -d "${MNT_PERSIST}$dir" ]]; then
		echo "  -> $dir (already migrated, skipping)"
	else
		echo "  -> $dir (not found, creating empty)"
		mkdir -p "${MNT_PERSIST}$dir"
	fi
}

migrate_system_file() {
	local file="$1"
	[[ -n "$file" && "$file" != "null" ]] || {
		echo "system file path is empty or null, refusing to operate!"
		exit 1
	}
	is_safe_system_path "$file" || {
		echo "system file path is unsafe: $file"
		exit 1
	}
	if [[ -f "${MNT_PERSIST}$file" ]]; then
		echo "  -> $file (already migrated, skipping)"
	elif [[ -f "/mnt$file" ]]; then
		echo "  -> $file (migrating)"
		mkdir -p "${MNT_PERSIST}$(dirname "$file")"
		rsync -av "/mnt$file" "${MNT_PERSIST}$file"
		rm -- "/mnt${file:?}"
	fi
}

migrate_user_directory() {
	local dir="$1" user="$2"
	[[ -n "$dir" && "$dir" != "null" ]] || {
		echo "user directory path is empty or null, refusing to operate!"
		exit 1
	}
	is_safe_user_relpath "$dir" || {
		echo "user directory path is unsafe: $dir"
		exit 1
	}
	[[ -n "$user" && "$user" != "null" ]] || {
		echo "user component is empty or null, refusing to operate!"
		exit 1
	}
	local base="/mnt/home/$user"
	local full_path="$base/$dir"
	assert_under_dir "$base" "$full_path" || {
		echo "Refusing to operate outside user home: $full_path"
		exit 1
	}
	if [[ -d $full_path ]]; then
		echo "  -> ~/$dir (migrating)"
		mkdir -p "${MNT_PERSIST}/home/$user/$dir"
		rsync -av "$full_path/" "${MNT_PERSIST}/home/$user/$dir/"
		rm -rf -- "$full_path"
	elif [[ -d "${MNT_PERSIST}/home/$user/$dir" ]]; then
		echo "  -> ~/$dir (already migrated, skipping)"
	else
		echo "  -> ~/$dir (not found, creating empty)"
		mkdir -p "${MNT_PERSIST}/home/$user/$dir"
		chown "$USER_UID:$USER_GID" "${MNT_PERSIST}/home/$user/$dir"
	fi
}

migrate_user_file() {
	local file="$1" user="$2"
	[[ -n "$file" && "$file" != "null" ]] || {
		echo "user file path is empty or null, refusing to operate!"
		exit 1
	}
	is_safe_user_relpath "$file" || {
		echo "user file path is unsafe: $file"
		exit 1
	}
	[[ -n "$user" && "$user" != "null" ]] || {
		echo "user component is empty or null, refusing to operate!"
		exit 1
	}
	local base="/mnt/home/$user"
	local full_path="$base/$file"
	assert_under_dir "$base" "$full_path" || {
		echo "Refusing to operate outside user home: $full_path"
		exit 1
	}
	if [[ -f "${MNT_PERSIST}/home/$user/$file" ]]; then
		echo "  -> ~/$file (already migrated, skipping)"
	elif [[ -f $full_path ]]; then
		echo "  -> ~/$file (migrating)"
		mkdir -p "${MNT_PERSIST}/home/$user/$(dirname "$file")"
		rsync -av "$full_path" "${MNT_PERSIST}/home/$user/$file"
		rm -- "$full_path"
	fi
}

echo "Migrating system directories..."
system_dirs_list="$(jq -r '.system_dirs[]' "$MIGRATE_JSON")"
while IFS= read -r dir; do
	[[ -n $dir ]] && migrate_system_directory "$dir"
done <<<"$system_dirs_list"

echo "Migrating system files..."
system_files_list="$(jq -r '.system_files[]' "$MIGRATE_JSON")"
while IFS= read -r file; do
	[[ -n $file ]] && migrate_system_file "$file"
done <<<"$system_files_list"

echo "Migrating user directories for $USERNAME..."
mkdir -p "${MNT_PERSIST}/home/$USERNAME"
user_dirs_list="$(jq -r '.user_dirs[]' "$MIGRATE_JSON")"
while IFS= read -r dir; do
	[[ -n $dir ]] && migrate_user_directory "$dir" "$USERNAME"
done <<<"$user_dirs_list"

echo "Migrating user files for $USERNAME..."
user_files_list="$(jq -r '.user_files[]' "$MIGRATE_JSON")"
while IFS= read -r file; do
	[[ -n $file ]] && migrate_user_file "$file" "$USERNAME"
done <<<"$user_files_list"

echo "Handling machine-id..."
mkdir -p "${MNT_PERSIST}/etc"
if [[ -f "${MNT_PERSIST}/etc/machine-id" ]]; then
	echo "  machine-id already in persist (migrated), skipping."
elif [[ -f "/mnt/etc/machine-id" ]]; then
	cp -p "/mnt/etc/machine-id" "${MNT_PERSIST}/etc/"
else
	if command -v systemd-machine-id-setup >/dev/null 2>&1; then
		systemd-machine-id-setup --root="${MNT_PERSIST}" 2>/dev/null ||
			dbus-uuidgen >"${MNT_PERSIST}/etc/machine-id"
	else
		require_cmd dbus-uuidgen
		dbus-uuidgen >"${MNT_PERSIST}/etc/machine-id"
	fi
fi

echo "Sanitizing git repos..."
NX_BASE="${MNT_PERSIST}/home/${USERNAME}/.config/nx"
sanitize_repo_git "${NX_BASE}/nxconfig"
sanitize_repo_git "${NX_BASE}/nxcore"

echo "Writing IMPERMANENCE marker..."
{
	echo "IMPERMANENCE_ENABLED=true"
	echo "MIGRATION_DATE=$(date -Iseconds)"
	echo "MIGRATION_SCRIPT=remote-post-install.sh"
} >"${MNT_PERSIST}/etc/IMPERMANENCE"

echo "Fixing ownership..."
[[ -d "${MNT_PERSIST}/etc" ]] && chown -R 0:0 "${MNT_PERSIST}/etc"
[[ -d "${MNT_PERSIST}/var" ]] && chown -R 0:0 "${MNT_PERSIST}/var"
[[ -d "${MNT_PERSIST}/home/$USERNAME" ]] && chown -R "$USER_UID:$USER_GID" "${MNT_PERSIST}/home/$USERNAME"
[[ -d "${MNT_PERSIST}/home/$USERNAME" ]] && chmod 700 "${MNT_PERSIST}/home/$USERNAME"

echo "Cleaning up temporary files..."
rm -f -- "$MIGRATE_JSON" 2>/dev/null || true
rm -f -- "/migrate.json" 2>/dev/null || true
rm -f -- "/tmp/remote-post-install.sh" 2>/dev/null || true

echo "Migration complete."
