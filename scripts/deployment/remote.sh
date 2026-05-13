#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
INVOCATION_DIR="$(pwd)"
deployment_script_setup "remote"

umask 077

cd "$CONFIG_DIR"

if ! has_nx_command "remote"; then
	print_error "nx remote is not enabled on this machine!"
	exit 1
fi

_INSTALL_TMPDIR=""

cleanup() {
	set +e
	if [[ -n "${_INSTALL_TMPDIR:-}" && -d "${_INSTALL_TMPDIR}" ]]; then
		while IFS= read -r -d '' f; do
			if command -v shred >/dev/null 2>&1; then
				shred -u -- "${f}" 2>/dev/null || rm -f -- "${f}"
			else
				rm -f -- "${f}"
			fi
		done < <(find "${_INSTALL_TMPDIR}" -type f -print0 2>/dev/null)
		rm -rf -- "${_INSTALL_TMPDIR}" 2>/dev/null || true
	fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM HUP QUIT

_AGE_FILE="" _AGE_SYSTEM_FILE="" _AGE_USER_FILE=""
_NO_USER_AGE=false _DANGEROUSLY_USE_HOST_SOPS=false
_FORCE=false _BUILD_ON_REMOTE=false _ALLOW_OWN_PROFILE=false _ALLOW_LOCALHOST=false _CONNECT_ONLY=false _DRY_RUN=false _ASK=false _DRY_RUN_CMD=""
_PROFILE="" _FULL_PROFILE="" _TARGET="" _REMOTE_ADDR=""
_PERSIST_PATH="" _DEP_MODE=""
_USES_IMPERMANENCE=false _USERNAME=""
_USER_UID="" _USER_GID=""
_SYSTEM_DIRS='[]' _SYSTEM_FILES='[]' _USER_DIRS='[]' _USER_FILES='[]'
_SYSTEM_KEY_SRC="" _USER_KEY_SRC=""
_EXTRA_FILES_BASE="" _NA_ARGS=()
_RESOLVED_HOST="" _RESOLVED_PORT="22"
_RESOLVED_STRICT_HOST_CHECKING="" _RESOLVED_USER_KNOWN_HOSTS_FILE=""
_RESOLVED_USER=""
_RESOLVED_SSH_EXTRA_OPTS=()
_RESOLVED_IDENTITY_FILES=""
_SSH_IDENTITY_FILE=""
_INSTALL_SSH_ALIAS=""
_INSTALL_KNOWN_HOSTS_FILE=""
_INSTALL_SSH_OVERRIDE_OPTS=()

require_cmd() {
	local c="${1:-}"
	[[ -n "$c" ]] || return 0
	command -v "$c" >/dev/null 2>&1 || {
		print_error "Missing required command: $c!"
		exit 1
	}
}

prompt_confirm() {
	local message="${1:-}"
	local default_yes="${2:-false}"

	local suffix suffix_color
	if [[ "$default_yes" == "true" ]]; then
		suffix="[Y/n]"
		suffix_color="$YELLOW"
	else
		suffix="[y/N]"
		suffix_color="$RED"
	fi

	echo -e "${WHITE}${message}${RESET}"
	echo
	echo -en "${WHITE}Do you want to proceed? ${suffix_color}${suffix}${RESET}: "

	local resp
	read -r resp

	if [[ -z "$resp" ]]; then
		[[ "$default_yes" == "true" ]] && return 0
		return 1
	fi
	[[ "$resp" =~ ^[yY] ]] && return 0
	return 1
}

_ask_tty() {
	[[ "${_ASK:-false}" == "true" ]] || return 0
	echo -e "${WHITE}About to run: $*${RESET}" >/dev/tty
	echo >/dev/tty
	echo -en "${WHITE}Do you want to proceed? ${YELLOW}[Y/n]: ${RESET}" >/dev/tty
	local resp
	read -r resp </dev/tty
	if [[ -n "$resp" && ! "$resp" =~ ^[yY] ]]; then
		echo -e "${ORANGE}Aborted.${RESET}" >/dev/tty
		exit 1
	fi
}

ask_run_tty() {
	_ask_tty "$@"
	"$@"
}

eval_expected_hostname() {
	local full_profile="${1:-}"
	[[ -n "$full_profile" ]] || {
		print_error "Internal error: missing full profile name!"
		exit 1
	}
	require_cmd nix
	local out
	print_debug "Evaluating nx.profile.host.hostname"
	if ! out="$(nix eval --raw ".#nixosConfigurations.$full_profile.config.nx.profile.host.hostname" "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate nx.profile.host.hostname for $full_profile!"
		exit 1
	fi
	out="${out//$'\r'/}"
	[[ -n "$out" ]] || {
		print_error "nx.profile.host.hostname evaluated to empty string for $full_profile!"
		exit 1
	}
	echo "$out"
}

require_json() {
	local json="${1:-}"
	local label="${2:-JSON value}"
	require_cmd jq
	if [[ -z "$json" ]]; then
		print_error "$label was empty!"
		exit 1
	fi
	if ! echo "$json" | jq -e . >/dev/null 2>&1; then
		print_error "$label was not valid JSON!"
		exit 1
	fi
}

remote_hostname_over_ssh() {
	local target="${1:-}"
	shift || true

	[[ -n "$target" ]] || {
		print_error "Internal error: missing SSH target!"
		exit 1
	}
	require_cmd ssh

	local out
	if ! out="$(ssh "$@" "$target" "hostname" 2>/dev/null | head -n1)"; then
		print_error "Failed to query remote hostname via SSH!"
		exit 1
	fi
	out="${out//$'\r'/}"
	[[ -n "$out" ]] || {
		print_error "Remote hostname query returned empty output!"
		exit 1
	}
	echo "$out"
}

resolve_arg_path() {
	local p="${1:-}"
	if [[ -z ${p} ]]; then
		echo ""
		return 0
	fi
	if [[ ${p} == /* ]]; then
		echo "${p}"
		return 0
	fi
	if [[ ${p} == "~" ]]; then
		echo "${HOME}"
		return 0
	fi
	# shellcheck disable=SC2088
	if [[ ${p} == "~/"* ]]; then
		echo "${HOME}/${p#~/}"
		return 0
	fi
	if command -v realpath >/dev/null 2>&1; then
		realpath -m -- "${INVOCATION_DIR}/${p}"
		return 0
	fi
	if command -v readlink >/dev/null 2>&1; then
		readlink -f -- "${INVOCATION_DIR}/${p}" 2>/dev/null || echo "${INVOCATION_DIR}/${p}"
		return 0
	fi
	echo "${INVOCATION_DIR}/${p}"
}

resolve_identity_file() {
	local f="${1:-}"
	local identityfiles_nl="${2:-}"
	local allow_unmatched_pub_selector="${3:-false}"
	[[ -z "$f" ]] && {
		echo ""
		return
	}

	local resolved_base
	[[ "$f" == /* ]] && resolved_base="$f" || resolved_base="$HOME/.ssh/$f"
	if [[ "$resolved_base" == *" "* ]]; then
		print_error "SSH identity file path must not contain spaces: $resolved_base!"
		exit 1
	fi
	local unsafe_chars=(
		";"
		"&"
		"|"
		"\`"
		"<"
		">"
		"$"
		"("
		")"
		"{"
		"}"
		"!"
		"\""
		"'"
		"\\"
	)
	local ch
	for ch in "${unsafe_chars[@]}"; do
		if [[ "$resolved_base" == *"$ch"* ]]; then
			print_error "SSH identity file path contains unsafe characters: $resolved_base!"
			exit 1
		fi
	done

	local resolved=""
	if [[ -f "$resolved_base" ]]; then
		resolved="$resolved_base"
	elif [[ -f "${resolved_base}.pub" ]]; then
		resolved="${resolved_base}.pub"
	else
		print_error "SSH identity file does not exist: $resolved_base (also checked ${resolved_base}.pub)!"
		exit 1
	fi

	if [[ "$resolved" == *.pub ]]; then
		local selector_base selector_base_pub
		selector_base="$(basename -- "$resolved_base")"
		selector_base_pub="${selector_base}.pub"

		local matched=false
		if [[ -n "$identityfiles_nl" ]]; then
			local identityfile base base_no_pub
			while IFS= read -r identityfile; do
				[[ -n "$identityfile" ]] || continue
				base="$(basename -- "$identityfile")"
				base_no_pub="${base%.pub}"
				if [[ "$base" == "$selector_base" || "$base" == "$selector_base_pub" || "$base_no_pub" == "$selector_base" ]]; then
					matched=true
					break
				fi
			done <<<"$identityfiles_nl"
		fi

		if [[ "$matched" != "true" && "$allow_unmatched_pub_selector" != "true" ]]; then
			print_error "SSH identity file resolved to a .pub key ($resolved) but does not match any IdentityFile from ssh config for the target!"
			print_error "Either ensure $resolved_base exists (private key), or update SSH config IdentityFile entries so the agent-selected key matches this basename!"
			exit 1
		fi
	fi

	echo "$resolved"
}

resolve_ssh_target() {
	local addr="${1}"
	require_cmd ssh
	local ssh_config
	ssh_config="$(ssh -G "$addr" 2>/dev/null || true)"
	if [[ -z "${ssh_config}" ]]; then
		_RESOLVED_HOST="$addr"
		_RESOLVED_PORT="22"
		_RESOLVED_STRICT_HOST_CHECKING=""
		_RESOLVED_USER_KNOWN_HOSTS_FILE=""
		_RESOLVED_USER=""
		_RESOLVED_SSH_EXTRA_OPTS=()
		_RESOLVED_IDENTITY_FILES=""
		return 0
	fi
	_RESOLVED_HOST="$(echo "$ssh_config" | grep '^hostname ' | head -n1 | cut -d' ' -f2-)"
	_RESOLVED_PORT="$(echo "$ssh_config" | grep '^port ' | head -n1 | cut -d' ' -f2-)"
	_RESOLVED_HOST="${_RESOLVED_HOST:-$addr}"
	_RESOLVED_PORT="${_RESOLVED_PORT:-22}"
	_RESOLVED_USER="$(echo "$ssh_config" | grep '^user ' | head -n1 | cut -d' ' -f2-)"
	_RESOLVED_USER="${_RESOLVED_USER:-}"
	_RESOLVED_STRICT_HOST_CHECKING="$(echo "$ssh_config" | grep '^stricthostkeychecking ' | head -n1 | cut -d' ' -f2-)"
	_RESOLVED_USER_KNOWN_HOSTS_FILE="$(echo "$ssh_config" | grep '^userknownhostsfile ' | head -n1 | cut -d' ' -f2-)"
	_RESOLVED_IDENTITY_FILES="$(echo "$ssh_config" | grep '^identityfile ' | cut -d' ' -f2- || true)"
	_RESOLVED_SSH_EXTRA_OPTS=()
	if [[ "$_RESOLVED_HOST" == *$'\n'* || "$_RESOLVED_HOST" == *$'\r'* ]]; then
		print_error "Resolved SSH hostname contains newline characters!"
		exit 1
	fi
	if [[ "$_RESOLVED_PORT" == *$'\n'* || "$_RESOLVED_PORT" == *$'\r'* ]]; then
		print_error "Resolved SSH port contains newline characters!"
		exit 1
	fi
	if [[ ! "$_RESOLVED_PORT" =~ ^[0-9]+$ ]]; then
		print_error "Resolved SSH port is not numeric: $_RESOLVED_PORT!"
		exit 1
	fi
	if ((_RESOLVED_PORT < 1 || _RESOLVED_PORT > 65535)); then
		print_error "Resolved SSH port is out of range: $_RESOLVED_PORT!"
		exit 1
	fi
	if [[ -n "$_RESOLVED_STRICT_HOST_CHECKING" && "$_RESOLVED_STRICT_HOST_CHECKING" != "null" ]]; then
		case "$_RESOLVED_STRICT_HOST_CHECKING" in
		yes | no | ask | accept-new | off | true | false) ;;
		*)
			print_error "Resolved StrictHostKeyChecking is invalid: $_RESOLVED_STRICT_HOST_CHECKING!"
			exit 1
			;;
		esac
	fi
	if [[ -n "$_RESOLVED_USER_KNOWN_HOSTS_FILE" && "$_RESOLVED_USER_KNOWN_HOSTS_FILE" != "null" ]]; then
		if [[ "$_RESOLVED_USER_KNOWN_HOSTS_FILE" == *$'\n'* || "$_RESOLVED_USER_KNOWN_HOSTS_FILE" == *$'\r'* ]]; then
			print_error "Resolved UserKnownHostsFile contains newline characters!"
			exit 1
		fi
		if [[ "$_RESOLVED_USER_KNOWN_HOSTS_FILE" == *' '* ]]; then
			print_error "Resolved UserKnownHostsFile contains spaces and cannot be passed via rsync -e!"
			exit 1
		fi
	fi
	if [[ "$_RESOLVED_USER" == *$'\n'* || "$_RESOLVED_USER" == *$'\r'* ]]; then
		print_error "Resolved SSH user contains newline characters!"
		exit 1
	fi
	[[ -z "$_RESOLVED_STRICT_HOST_CHECKING" ]] || _RESOLVED_SSH_EXTRA_OPTS+=(-o "StrictHostKeyChecking=$_RESOLVED_STRICT_HOST_CHECKING")
	[[ -z "$_RESOLVED_USER_KNOWN_HOSTS_FILE" ]] || _RESOLVED_SSH_EXTRA_OPTS+=(-o "UserKnownHostsFile=$_RESOLVED_USER_KNOWN_HOSTS_FILE")
}

ssh_config_has_explicit_host() {
	local host_alias="${1:-}"
	[[ -n "$host_alias" ]] || return 1

	local cfg="$HOME/.ssh/config"
	[[ -f "$cfg" ]] || return 1

	awk -v host="$host_alias" '
		/^[[:space:]]*Host[[:space:]]/ {
			for (i = 2; i <= NF; i++) {
				if ($i == host) { found = 1; exit }
			}
		}
		END { exit !found }
	' "$cfg"
}

is_loopback_alias() {
	local addr="${1:-}"
	case "$addr" in
	localhost | 127.* | ::1) return 0 ;;
	esac
	return 1
}

ensure_localhost_target_port_is_not_local_sshd() {
	local allow_localhost="${1:-false}"
	local resolved_host="${2:-}"
	local resolved_port="${3:-}"

	[[ "$allow_localhost" == "true" ]] || return 0
	is_loopback_alias "$resolved_host" || return 0

	require_cmd nix
	require_cmd jq

	local local_profile
	local_profile="$(retrieve_active_profile)"

	local local_extra_args=()
	if [[ ${NX_DEPLOYMENT_MODE:-develop} == "develop" ]]; then
		local_extra_args=("--override-input" "core" "path:$NXCORE_DIR")
	fi

	local ports_json
	print_debug "Evaluating services.openssh.ports"
	if ! ports_json="$(nix eval --json ".#nixosConfigurations.$local_profile.config.services.openssh.ports" "${local_extra_args[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate local services.openssh.ports for $local_profile. Refusing localhost deployment!"
		exit 1
	fi
	require_json "$ports_json" "local services.openssh.ports JSON for $local_profile"

	local ports=()
	while IFS= read -r p; do
		[[ -n "$p" ]] && ports+=("$p")
	done < <(echo "$ports_json" | jq -r '.[]?' 2>/dev/null || true)

	[[ ${#ports[@]} -gt 0 ]] || return 0

	local port
	for port in "${ports[@]}"; do
		if [[ "$resolved_port" == "$port" ]]; then
			print_error "Refusing localhost deployment: resolved target port $resolved_port matches this machine's SSH port ($port)!"
			exit 1
		fi
	done
}

check_deployment_mode() {
	local subcommand="${1}" dep_mode="${2}" profile="${3}"
	if [[ $dep_mode == "develop" ]]; then
		print_error "nx remote $subcommand cannot target a develop-mode profile!"
		exit 1
	fi
	if [[ $dep_mode == "local" ]]; then
		print_warning "Profile $profile is in local mode. Are you sure you want to push remotely?"
		echo -en "${WHITE}Continue? ${YELLOW}[y/N]: ${RESET}"
		local resp
		read -r resp
		[[ $resp =~ ^[yY] ]] || {
			echo -e "${ORANGE}Aborted.${RESET}"
			exit 1
		}
	fi
}

check_own_profile() {
	local profile="${1}" allow_own="${2}"
	if [[ -f /etc/NIXOS ]]; then
		local current_hostname
		current_hostname=$(hostname)
		if [[ "$profile" == "$current_hostname" && $allow_own != "true" ]]; then
			print_error "Profile '$profile' matches the current machine's hostname. Use --allow-own-profile to deploy to your own machine!"
			exit 1
		fi
	fi
}

check_localhost_target() {
	local addr="${1}" allow_localhost="${2}"
	local resolved_ips=()
	if command -v getent >/dev/null 2>&1; then
		while IFS= read -r line; do
			[[ -n "$line" ]] && resolved_ips+=("$(echo "$line" | awk '{print $1}')")
		done < <(getent hosts "$addr" 2>/dev/null)
	elif command -v dig >/dev/null 2>&1; then
		while IFS= read -r line; do
			[[ -n "$line" ]] && resolved_ips+=("$line")
		done < <(dig +short "$addr" 2>/dev/null)
	fi
	local check_addrs=("$addr" "${resolved_ips[@]+"${resolved_ips[@]}"}")
	local a
	for a in "${check_addrs[@]}"; do
		case "$a" in
		localhost | 127.* | ::1)
			if [[ $allow_localhost != "true" ]]; then
				print_error "Remote address '$addr' resolves to loopback ($a). Use --allow-localhost if this is intentional!"
				exit 1
			fi
			;;
		esac
	done
}

remote_keygen() {
	local PROFILE="${1:-}"
	[[ -n $PROFILE ]] || {
		print_error "profile argument required!"
		exit 1
	}
	[[ "$PROFILE" =~ ^[a-zA-Z0-9._-]+$ ]] || {
		print_error "Profile name '$PROFILE' contains invalid characters!"
		exit 1
	}
	shift || true

	local SHARED_KEY=false
	while [[ $# -gt 0 ]]; do
		case "${1:-}" in
		--shared-key)
			SHARED_KEY=true
			shift
			;;
		*)
			print_error "Unknown option: $1!"
			exit 1
			;;
		esac
	done

	require_cmd age-keygen

	local KEY_BASE_DIR="$HOME/.local/share/nx/deploy-keys"
	local KEY_DIR="$KEY_BASE_DIR/$PROFILE"
	mkdir -p "$KEY_BASE_DIR"
	if [[ -e "$KEY_DIR" ]]; then
		print_error "Age key directory already exists at $KEY_DIR -> delete it first to regenerate!"
		exit 1
	fi
	mkdir "$KEY_DIR"
	chmod 700 "$KEY_DIR"

	local key_files=()
	if [[ "$SHARED_KEY" == "true" ]]; then
		key_files=("$KEY_DIR/age-shared.txt")
	else
		key_files=("$KEY_DIR/age-system.txt" "$KEY_DIR/age-user.txt")
	fi

	local f
	for f in "${key_files[@]}"; do
		age-keygen -o "$f"
		chmod 600 "$f"
	done

	echo
	print_info "SOPS age key(s) generated at: $KEY_DIR"
	echo
	echo -e "${WHITE}Add the following to .sops.yaml creation rules for $PROFILE:${RESET}"
	if [[ "$SHARED_KEY" == "true" ]]; then
		echo -e "  (system and user): ${GREEN}$(age-keygen -y "${key_files[0]}")${RESET}"
	else
		echo -e "  System: ${GREEN}$(age-keygen -y "${key_files[0]}")${RESET}"
		echo -e "  User:   ${GREEN}$(age-keygen -y "${key_files[1]}")${RESET}"
	fi
	echo
	echo -e "${WHITE}Next steps:${RESET}"
	echo -e "  1. Add the age public key(s) above to .sops.yaml"
	echo -e "  2. Re-encrypt secrets and commit"
	echo -e "  3. Run: ${GREEN}nx remote install $PROFILE${RESET}"
}

_remote_deploy() {
	local CMD="${1:-}"
	local PROFILE="${2:-}"
	[[ -n $PROFILE ]] || {
		print_error "profile argument required!"
		exit 1
	}
	[[ "$PROFILE" =~ ^[a-zA-Z0-9._-]+$ ]] || {
		print_error "Profile name '$PROFILE' contains invalid characters!"
		exit 1
	}
	shift 2 || true

	local BUILD_ON_HOST=false ALLOW_OWN_PROFILE=false ALLOW_LOCALHOST=false CONNECT_ONLY=false DRY_RUN=false ASK=false
	local remaining_args=()
	while [[ $# -gt 0 ]]; do
		case "${1:-}" in
		--build-on-host)
			BUILD_ON_HOST=true
			shift
			;;
		--allow-own-profile)
			ALLOW_OWN_PROFILE=true
			shift
			;;
		--allow-localhost)
			ALLOW_LOCALHOST=true
			shift
			;;
		--connect-only)
			CONNECT_ONLY=true
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--ask)
			ASK=true
			shift
			;;
		*)
			remaining_args+=("$1")
			shift
			;;
		esac
	done
	parse_common_deployment_args "${remaining_args[@]+"${remaining_args[@]}"}"
	[[ $DRY_RUN != "true" ]] || _DRY_RUN_CMD="echo"
	_ASK=$ASK

	require_cmd nix
	require_cmd jq
	require_cmd ssh
	require_cmd nixos-rebuild

	local FULL_PROFILE
	FULL_PROFILE="$(construct_profile_name "$PROFILE")"

	DRY_RUN_TEXT=""
	if [[ "$DRY_RUN" == "true" ]]; then
		DRY_RUN_TEXT="${YELLOW} (DRY-RUN)${RESET}"
	fi
	ASK_TEXT=""
	if [[ "$_ASK" == "true" ]]; then
		ASK_TEXT="${ORANGE} (ASK)${RESET}"
	fi
	case "${CMD:-}" in
	sync)
		echo -e "${GREEN}Running ${WHITE}Sync${GREEN} on ${WHITE}$PROFILE${GREEN}...${RESET}${DRY_RUN_TEXT:-}${ASK_TEXT:-}"
		echo
		;;
	boot)
		echo -e "${MAGENTA}Running ${WHITE}Boot${MAGENTA} on ${WHITE}$PROFILE${MAGENTA}...${RESET}${DRY_RUN_TEXT:-}${ASK_TEXT:-}"
		echo
		;;
	test)
		echo -e "${BLUE}Running ${WHITE}Test${BLUE} on ${WHITE}$PROFILE${BLUE}...${RESET}${DRY_RUN_TEXT:-}${ASK_TEXT:-}"
		echo
		;;
	*) ;;
	esac

	print_info "Evaluating profile configuration for $CMD..."

	local HOST_JSON
	print_debug "Evaluating nx.profile.host"
	if ! HOST_JSON="$(nix eval --json ".#nixosConfigurations.$FULL_PROFILE.config.nx.profile.host" "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate nx.profile.host for $FULL_PROFILE!"
		exit 1
	fi
	require_json "$HOST_JSON" "nx.profile.host JSON for $FULL_PROFILE"
	local DEP_MODE REMOTE_ADDR MAIN_USER
	DEP_MODE=$(echo "$HOST_JSON" | jq -r '.deploymentMode')
	REMOTE_ADDR=$(echo "$HOST_JSON" | jq -r '.remote.address // empty')
	MAIN_USER=$(echo "$HOST_JSON" | jq -r '.mainUser.username // empty')

	check_deployment_mode "$CMD" "$DEP_MODE" "$PROFILE"
	[[ -n $REMOTE_ADDR && $REMOTE_ADDR != "null" ]] || {
		print_error "host.remote.address is not set in profile $PROFILE!"
		exit 1
	}
	[[ -n "$MAIN_USER" && "$MAIN_USER" != "null" ]] || {
		print_error "host.mainUser.username is not set in profile $PROFILE!"
		exit 1
	}
	local TARGET="nx-deployment---${PROFILE}---deploy"
	if ! ssh_config_has_explicit_host "$TARGET"; then
		print_error "Deploy SSH alias '$TARGET' not found in ~/.ssh/config!"
		exit 1
	fi
	resolve_ssh_target "$TARGET"
	if [[ "$_RESOLVED_USER" == "root" ]]; then
		print_error "Deploy SSH alias '$TARGET' resolves to user root - deploy must not run as root!"
		exit 1
	fi
	if [[ -z "$_RESOLVED_IDENTITY_FILES" ]]; then
		print_error "Deploy SSH alias '$TARGET' does not have an IdentityFile in ssh config!"
		exit 1
	fi
	check_own_profile "$PROFILE" "$ALLOW_OWN_PROFILE"
	check_localhost_target "$_RESOLVED_HOST" "$ALLOW_LOCALHOST"
	ensure_localhost_target_port_is_not_local_sshd "$ALLOW_LOCALHOST" "$_RESOLVED_HOST" "$_RESOLVED_PORT"

	local insecure_deploy=false
	case "${_RESOLVED_STRICT_HOST_CHECKING:-}" in
	no | off | false) insecure_deploy=true ;;
	esac
	[[ "${_RESOLVED_USER_KNOWN_HOSTS_FILE:-}" != "/dev/null" ]] || insecure_deploy=true
	if [[ "$insecure_deploy" == "true" ]]; then
		echo
		print_warning "Deploy SSH alias '$TARGET' has host key verification disabled (StrictHostKeyChecking=${_RESOLVED_STRICT_HOST_CHECKING:-}, UserKnownHostsFile=${_RESOLVED_USER_KNOWN_HOSTS_FILE:-})."
	fi

	check_git_worktrees_clean
	[[ $DRY_RUN == "true" ]] || verify_commits

	local ssh_reach_args=(-o BatchMode=yes -o ConnectTimeout=10)
	print_info "Checking SSH reachability to $TARGET..."
	echo
	if [[ $DRY_RUN == "true" ]]; then
		print_info "(dry run) Would run: ssh ${ssh_reach_args[*]} $TARGET true"
		echo
	else
		ask_run_tty ssh "${ssh_reach_args[@]}" "$TARGET" true ||
			{
				print_error "Cannot reach $TARGET via SSH!"
				exit 1
			}
	fi
	if [[ $CONNECT_ONLY == "true" ]]; then
		if [[ $DRY_RUN == "true" ]]; then
			print_success "Connected to $TARGET (dry run)"
		else
			print_success "Connected to $TARGET"
		fi
		exit 0
	fi

	if [[ $DRY_RUN != "true" ]]; then
		local expected_hostname remote_hostname
		expected_hostname="$(eval_expected_hostname "$FULL_PROFILE")"
		print_info "Querying remote hostname..."
		_ask_tty ssh "${ssh_reach_args[@]}" "$TARGET" "hostname"
		remote_hostname="$(remote_hostname_over_ssh "$TARGET" "${ssh_reach_args[@]}")"

		if [[ "$remote_hostname" != "$expected_hostname" ]]; then
			print_warning "Remote hostname '$remote_hostname' does not match configured hostname '$expected_hostname' for profile $FULL_PROFILE!"
			if ! prompt_confirm "Proceed to '$CMD' on mismatched host '$remote_hostname'?" false; then
				echo -e "${ORANGE}Aborted.${RESET}"
				exit 1
			fi
		else
			if ! prompt_confirm "Proceed to '$CMD' on host '$remote_hostname'?" true; then
				echo -e "${ORANGE}Aborted.${RESET}"
				exit 1
			fi
		fi
	fi

	local build_host_args=()
	[[ $BUILD_ON_HOST == "true" ]] || build_host_args=("--build-host" "$TARGET")

	local nr_cmd
	case "$CMD" in
	boot) nr_cmd="boot" ;;
	sync) nr_cmd="switch" ;;
	test) nr_cmd="test" ;;
	*)
		print_error "Internal error: unknown remote deploy command '$CMD'!"
		exit 1
		;;
	esac

	local sudo_mode
	if [[ "$_RESOLVED_USER" == "nx-deployment" ]]; then
		sudo_mode="--sudo"
	else
		sudo_mode="--ask-sudo-password"
	fi
	local sudo_args=("$sudo_mode")

	if [[ $DRY_RUN == "true" ]]; then
		echo nixos-rebuild "$nr_cmd" \
			--flake ".#$FULL_PROFILE" \
			--target-host "$TARGET" \
			"${build_host_args[@]+"${build_host_args[@]}"}" \
			--print-build-logs \
			"${sudo_args[@]+"${sudo_args[@]}"}" \
			"${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
		notify_success "Remote $CMD ($PROFILE)"
	else
		print_info "Deploying $CMD to $TARGET..."
		if ask_run_tty nixos-rebuild "$nr_cmd" \
			--flake ".#$FULL_PROFILE" \
			--target-host "$TARGET" \
			"${build_host_args[@]+"${build_host_args[@]}"}" \
			--print-build-logs \
			"${sudo_args[@]+"${sudo_args[@]}"}" \
			"${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"; then
			echo
			print_success "Remote $CMD succeeded."
			notify_success "Remote $CMD ($PROFILE)"
		else
			echo
			print_error "Remote $CMD failed!"
			notify_error "Remote $CMD ($PROFILE)"
			exit 1
		fi
	fi
}

remote_sync() { _remote_deploy sync "$@"; }
remote_boot() { _remote_deploy boot "$@"; }
remote_test() { _remote_deploy test "$@"; }

validate_sops_flags() {
	if [[ -n ${_AGE_FILE} && (-n ${_AGE_SYSTEM_FILE} || -n ${_AGE_USER_FILE}) ]]; then
		print_error "--age-file is mutually exclusive with --age-system-file/--age-user-file!"
		exit 1
	fi
	if [[ ${_NO_USER_AGE} == "true" && -n ${_AGE_USER_FILE} ]]; then
		print_error "--no-user-age is mutually exclusive with --age-user-file!"
		exit 1
	fi
	if [[ ${_NO_USER_AGE} == "true" && -n ${_AGE_FILE} ]]; then
		print_error "--no-user-age is mutually exclusive with --age-file (use --age-system-file instead)!"
		exit 1
	fi
	if [[ -n ${_AGE_SYSTEM_FILE} && -z ${_AGE_USER_FILE} && ${_NO_USER_AGE} != "true" ]]; then
		print_error "--age-user-file must be provided unless --no-user-age is set!"
		exit 1
	fi
	if [[ -z ${_AGE_SYSTEM_FILE} && -n ${_AGE_USER_FILE} ]]; then
		print_error "--age-user-file requires --age-system-file!"
		exit 1
	fi
	if [[ ${_DANGEROUSLY_USE_HOST_SOPS} == "true" && (-n ${_AGE_FILE} || -n ${_AGE_SYSTEM_FILE} || -n ${_AGE_USER_FILE}) ]]; then
		print_error "--dangerously-use-host-sops cannot be combined with --age-file/--age-system-file/--age-user-file!"
		exit 1
	fi
}

eval_install_profile() {
	print_info "Evaluating profile configuration for install..."

	local VARS_JSON
	print_debug "Evaluating variables"
	if ! VARS_JSON="$(nix eval --json .#variables "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate variables!"
		exit 1
	fi
	require_json "$VARS_JSON" "variables JSON"
	_PERSIST_PATH=$(echo "$VARS_JSON" | jq -r '.persist')
	[[ -n "$_PERSIST_PATH" && "$_PERSIST_PATH" != "null" ]] || {
		print_error "variables.persist evaluated to empty value!"
		exit 1
	}
	if [[ "$_PERSIST_PATH" != /* || "$_PERSIST_PATH" == *$'\n'* || "$_PERSIST_PATH" == *$'\r'* ]]; then
		print_error "variables.persist must be an absolute path without newlines!"
		exit 1
	fi
	local _unsafe_char
	# shellcheck disable=SC1003
	for _unsafe_char in ';' '&' '|' '`' '<' '>' '$' '(' ')' '{' '}' '!' '"' "'" '\\' ' '; do
		if [[ "$_PERSIST_PATH" == *"$_unsafe_char"* ]]; then
			print_error "variables.persist contains unsafe character: $_unsafe_char!"
			exit 1
		fi
	done

	local HOST_JSON
	print_debug "Evaluating nx.profile.host"
	if ! HOST_JSON="$(nix eval --json ".#nixosConfigurations.$_FULL_PROFILE.config.nx.profile.host" "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate nx.profile.host for $_FULL_PROFILE!"
		exit 1
	fi
	require_json "$HOST_JSON" "nx.profile.host JSON for $_FULL_PROFILE"
	_DEP_MODE=$(echo "$HOST_JSON" | jq -r '.deploymentMode')
	_REMOTE_ADDR=$(echo "$HOST_JSON" | jq -r '.remote.address // empty')
	_USES_IMPERMANENCE=$(echo "$HOST_JSON" | jq -r '.impermanence')
	_USERNAME=$(echo "$HOST_JSON" | jq -r '.mainUser.username')
	[[ -n "$_USERNAME" && "$_USERNAME" != "null" ]] || {
		print_error "host.mainUser.username is not set in profile $_PROFILE!"
		exit 1
	}
	if [[ "$_USERNAME" == *$'\n'* || "$_USERNAME" == *$'\r'* || "$_USERNAME" == *"/"* ]]; then
		print_error "host.mainUser.username contains unsafe characters!"
		exit 1
	fi
	if [[ ! "$_USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		print_error "host.mainUser.username contains unsafe characters: $_USERNAME!"
		exit 1
	fi
	_SSH_IDENTITY_FILE=""
	_INSTALL_SSH_ALIAS="nx-deployment---${_PROFILE}---install"
	[[ -z "$_REMOTE_ADDR" || "$_REMOTE_ADDR" == "null" ]] || resolve_ssh_target "$_INSTALL_SSH_ALIAS"

	local USER_JSON
	print_debug "Evaluating users.users.$_USERNAME"
	if ! USER_JSON="$(nix eval --json ".#nixosConfigurations.$_FULL_PROFILE.config.users.users.$_USERNAME" "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate users.users.$_USERNAME for $_FULL_PROFILE!"
		exit 1
	fi
	require_json "$USER_JSON" "users.users.$_USERNAME JSON for $_FULL_PROFILE"
	_USER_UID=$(echo "$USER_JSON" | jq -r '.uid')
	local GROUP
	GROUP=$(echo "$USER_JSON" | jq -r '.group')
	print_debug "Evaluating users.users.groups.$GROUP.gid"
	local gid_json
	if ! gid_json="$(nix eval --json ".#nixosConfigurations.$_FULL_PROFILE.config.users.groups.$GROUP.gid" "${EXTRA_ARGS[@]}" 2>/dev/null)"; then
		print_error "Failed to evaluate users.groups.$GROUP.gid for $_FULL_PROFILE!"
		exit 1
	fi
	require_json "$gid_json" "users.groups.$GROUP.gid JSON for $_FULL_PROFILE"
	_USER_GID="$(echo "$gid_json" | jq -r '.')"

	_TARGET="$_INSTALL_SSH_ALIAS"
}

check_install_preflight() {
	require_cmd ssh
	[[ $_DEP_MODE != "develop" ]] || {
		print_error "nx remote install cannot target a develop-mode profile!"
		exit 1
	}
	if [[ $_DEP_MODE != "managed" ]]; then
		echo
		print_warning "Profile is in $_DEP_MODE mode!"
		echo
	fi
	[[ -n $_REMOTE_ADDR && $_REMOTE_ADDR != "null" ]] || {
		print_error "host.remote.address is not set in profile $_PROFILE!"
		exit 1
	}

	if ! ssh_config_has_explicit_host "$_INSTALL_SSH_ALIAS"; then
		print_error "Install SSH alias '$_INSTALL_SSH_ALIAS' not found in ~/.ssh/config!"
		exit 1
	fi

	local ssh_conf_user ssh_conf_identityfile _install_ssh_g_out
	_install_ssh_g_out="$(ssh -G "$_INSTALL_SSH_ALIAS" 2>/dev/null || true)"
	ssh_conf_user="$(echo "$_install_ssh_g_out" | grep '^user ' | head -n1 | cut -d' ' -f2- || true)"
	ssh_conf_identityfile="$(echo "$_install_ssh_g_out" | grep '^identityfile ' | head -n1 | cut -d' ' -f2- || true)"
	if [[ "$ssh_conf_user" != "root" ]]; then
		print_error "Install SSH alias $_INSTALL_SSH_ALIAS does not resolve to user root via ssh config!"
		exit 1
	fi
	if [[ -z "$ssh_conf_identityfile" ]]; then
		print_error "Install SSH alias $_INSTALL_SSH_ALIAS does not have an IdentityFile in ssh config!"
		exit 1
	fi

	check_own_profile "$_PROFILE" "$_ALLOW_OWN_PROFILE"
	check_localhost_target "$_RESOLVED_HOST" "$_ALLOW_LOCALHOST"
	ensure_localhost_target_port_is_not_local_sshd "$_ALLOW_LOCALHOST" "$_RESOLVED_HOST" "$_RESOLVED_PORT"
	[[ -n $_USERNAME && $_USERNAME != "null" ]] || {
		print_error "host.mainUser.username is not set in profile $_PROFILE!"
		exit 1
	}
	[[ -n $_USER_UID && $_USER_UID != "null" ]] || {
		print_error "users.users.$_USERNAME.uid is not set in profile $_PROFILE (UID must be explicitly defined for remote install)!"
		exit 1
	}
	[[ -n $_USER_GID && $_USER_GID != "null" ]] || {
		print_error "users.$_USERNAME primary group gid is not set in profile $_PROFILE (GID must be explicitly defined for remote install)!"
		exit 1
	}

	local DISK_NIX="profiles/nixos/$_PROFILE/disk.nix"
	[[ -f $DISK_NIX ]] || {
		print_error "Disk configuration not found: $DISK_NIX!"
		exit 1
	}

	check_git_worktrees_clean
	if [[ $_DRY_RUN != "true" && ${ALLOW_DIRTY_GIT} != "true" ]]; then
		local config_remote_head config_local_head core_remote_head core_local_head
		config_remote_head=$(git ls-remote origin HEAD 2>/dev/null | cut -f1)
		config_local_head=$(git rev-parse HEAD)
		core_remote_head=$(cd "$NXCORE_DIR" && git ls-remote origin HEAD 2>/dev/null | cut -f1)
		core_local_head=$(cd "$NXCORE_DIR" && git rev-parse HEAD)
		if [[ -z "$config_remote_head" || -z "$core_remote_head" ]]; then
			print_warning "Could not reach origin to verify sync (offline?). Skipping remote sync check."
		elif [[ $config_remote_head != "$config_local_head" || $core_remote_head != "$core_local_head" ]]; then
			print_error "Local repos are not synced with origin. Push first, or use --allow-dirty-git!"
			exit 1
		fi
	fi
	[[ $_DRY_RUN == "true" || $_SKIP_VERIFICATION == "true" ]] || verify_commits

	local insecure_install=false
	case "${_RESOLVED_STRICT_HOST_CHECKING:-}" in
	no | off | false) insecure_install=true ;;
	esac
	[[ "${_RESOLVED_USER_KNOWN_HOSTS_FILE:-}" != "/dev/null" ]] || insecure_install=true

	if [[ "$insecure_install" == "true" ]]; then
		require_cmd ssh-keyscan
		require_cmd ssh-keygen

		local scan_cmd=(ssh-keyscan -T 5 -p "$_RESOLVED_PORT" -t "ed25519,rsa" "$_RESOLVED_HOST")

		if [[ $_DRY_RUN == "true" ]]; then
			echo
			print_warning "SSH host key verification is disabled for install target $_TARGET (StrictHostKeyChecking=${_RESOLVED_STRICT_HOST_CHECKING:-}, UserKnownHostsFile=${_RESOLVED_USER_KNOWN_HOSTS_FILE:-})."
			print_info "(dry run) Would run: ${scan_cmd[*]}"
			print_info "(dry run) Would require confirmation, then proceed with StrictHostKeyChecking=yes and a temporary UserKnownHostsFile."
			echo
		else
			echo
			print_warning "SSH host key verification is disabled for install target $_TARGET (StrictHostKeyChecking=${_RESOLVED_STRICT_HOST_CHECKING:-}, UserKnownHostsFile=${_RESOLVED_USER_KNOWN_HOSTS_FILE:-})."
			print_warning "To reduce risk, nx will fetch host keys with ssh-keyscan and require confirmation before continuing!"
			echo
			print_info "Fetching SSH host keys via ssh-keyscan..."

			local scan_out scan_lines
			scan_out="$("${scan_cmd[@]}" 2>/dev/null || true)"
			scan_lines="$(echo "$scan_out" | grep -v '^#' || true)"
			if [[ -z "$scan_lines" ]]; then
				print_error "ssh-keyscan returned no host keys for $_RESOLVED_HOST:$_RESOLVED_PORT!"
				exit 1
			fi

			echo
			print_info "ssh-keyscan results:"
			echo "$scan_lines"
			echo

			_INSTALL_KNOWN_HOSTS_FILE="$(mktemp -t nx-install-known-hosts.XXXXXX)"
			printf '%s\n' "$scan_lines" >"$_INSTALL_KNOWN_HOSTS_FILE"
			append_trap "rm -f -- \"$_INSTALL_KNOWN_HOSTS_FILE\" 2>/dev/null || true" EXIT INT TERM

			print_info "Fingerprints:"
			ssh-keygen -l -f "$_INSTALL_KNOWN_HOSTS_FILE" || true
			echo
			print_info "Verify on the target console if possible:"
			print_info "  sudo ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub"
			print_info "  sudo ssh-keygen -l -f /etc/ssh/ssh_host_rsa_key.pub"
			echo

			if ! prompt_confirm "Proceed with install using these scanned host keys?" false; then
				echo -e "${ORANGE}Aborted.${RESET}"
				exit 1
			fi

			_INSTALL_SSH_OVERRIDE_OPTS=(-o "StrictHostKeyChecking=yes" -o "UserKnownHostsFile=$_INSTALL_KNOWN_HOSTS_FILE" -o "UpdateHostKeys=no")
		fi
	fi

	local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)
	ssh_opts+=("${_INSTALL_SSH_OVERRIDE_OPTS[@]+"${_INSTALL_SSH_OVERRIDE_OPTS[@]}"}")

	print_info "Checking SSH reachability to $_TARGET..."

	if [[ $_DRY_RUN == "true" ]]; then
		print_info "(dry run) Would run: ssh ${ssh_opts[*]} $_TARGET true"
		echo
	else
		ask_run_tty ssh "${ssh_opts[@]}" "$_TARGET" true 2>/dev/null ||
			{
				print_error "Cannot reach $_TARGET via SSH!"
				exit 1
			}
	fi
	if [[ $_CONNECT_ONLY == "true" ]]; then
		if [[ $_DRY_RUN == "true" ]]; then
			print_success "Connected to $_TARGET (dry run)"
		else
			print_success "Connected to $_TARGET"
		fi
		exit 0
	fi

	if [[ $_DRY_RUN != "true" ]]; then
		local expected_hostname remote_hostname
		expected_hostname="$(eval_expected_hostname "$_FULL_PROFILE")"
		print_info "Querying remote hostname..."
		_ask_tty ssh "${ssh_opts[@]}" "$_TARGET" "hostname"
		remote_hostname="$(remote_hostname_over_ssh "$_TARGET" "${ssh_opts[@]}")"

		local msg hostname_matches=true
		msg="Found host '$remote_hostname'."
		if [[ "$remote_hostname" != "$expected_hostname" ]]; then
			hostname_matches=false
			msg+="\nExpected hostname from profile: '$expected_hostname'."
			print_warning "Remote hostname does not match configured hostname for profile $_FULL_PROFILE!"
		fi

		if ! prompt_confirm "$msg" "$hostname_matches"; then
			echo -e "${ORANGE}Aborted.${RESET}"
			exit 1
		fi
	fi

	if [[ $_DRY_RUN != "true" ]]; then
		print_info "Checking if target already has NixOS installed..."
		_ask_tty ssh "${ssh_opts[@]}" "$_TARGET" "test -f /etc/NIXOS && ! grep -q '^nixos:' /etc/passwd 2>/dev/null"
		if ssh "${ssh_opts[@]}" "$_TARGET" "test -f /etc/NIXOS && ! grep -q '^nixos:' /etc/passwd 2>/dev/null" 2>/dev/null; then
			if [[ $_FORCE != "true" ]]; then
				print_error "Target $_TARGET already has NixOS. Use 'nx remote sync $_PROFILE' to update it, or --force to reinstall!"
				exit 1
			else
				print_warning "Target already has NixOS. Proceeding due to --force"
				echo -en "${WHITE}This will WIPE the target disk. Continue? ${RESET}[y/N]: "
				local resp
				read -r resp
				[[ $resp =~ ^[yY] ]] || {
					echo -e "${ORANGE}Aborted.${RESET}"
					exit 1
				}
			fi
		fi
	fi
}

fetch_impermanence_lists() {
	if [[ $_USES_IMPERMANENCE == "true" ]]; then
		local USER_PERSIST_KEY="$_PERSIST_PATH"

		local system_dirs_json
		print_debug "Evaluating environment.persistence.$_PERSIST_PATH.directories"
		if ! system_dirs_json="$(nix eval --json \
			".#nixosConfigurations.$_FULL_PROFILE.config.environment.persistence.\"$_PERSIST_PATH\".directories" \
			--apply 'dirs: builtins.map (d: if builtins.typeOf d == "string" then d else d.directory) dirs' \
			"${EXTRA_ARGS[@]}" 2>/dev/null)"; then
			print_error "Failed to evaluate system persistence directories!"
			exit 1
		fi
		_SYSTEM_DIRS="$system_dirs_json"

		local system_files_json
		print_debug "Evaluating environment.persistence.$_PERSIST_PATH.files"
		if ! system_files_json="$(nix eval --json \
			".#nixosConfigurations.$_FULL_PROFILE.config.environment.persistence.\"$_PERSIST_PATH\".files" \
			--apply 'files: builtins.map (f: if builtins.typeOf f == "string" then f else f.file) files' \
			"${EXTRA_ARGS[@]}" 2>/dev/null)"; then
			print_error "Failed to evaluate system persistence files!"
			exit 1
		fi
		_SYSTEM_FILES="$system_files_json"

		local user_dirs_json
		print_debug "Evaluating home.persistence.$USER_PERSIST_KEY.directories"
		if ! user_dirs_json="$(nix eval --json \
			".#nixosConfigurations.$_FULL_PROFILE.config.home-manager.users.$_USERNAME.home.persistence.\"$USER_PERSIST_KEY\".directories" \
			--apply 'dirs: builtins.map (d: if builtins.typeOf d == "string" then d else d.directory) dirs' \
			"${EXTRA_ARGS[@]}" 2>/dev/null)"; then
			print_error "Failed to evaluate user persistence directories!"
			exit 1
		fi
		_USER_DIRS="$user_dirs_json"

		local user_files_json
		print_debug "Evaluating home.persistence.$USER_PERSIST_KEY.files"
		if ! user_files_json="$(nix eval --json \
			".#nixosConfigurations.$_FULL_PROFILE.config.home-manager.users.$_USERNAME.home.persistence.\"$USER_PERSIST_KEY\".files" \
			--apply 'files: builtins.map (f: if builtins.typeOf f == "string" then f else f.file) files' \
			"${EXTRA_ARGS[@]}" 2>/dev/null)"; then
			print_error "Failed to evaluate user persistence files!"
			exit 1
		fi
		_USER_FILES="$user_files_json"

		local system_dirs_len
		local system_files_len
		local user_dirs_len
		local user_files_len

		system_dirs_len="$(echo "$_SYSTEM_DIRS" | jq -e 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)"
		system_files_len="$(echo "$_SYSTEM_FILES" | jq -e 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)"
		user_dirs_len="$(echo "$_USER_DIRS" | jq -e 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)"
		user_files_len="$(echo "$_USER_FILES" | jq -e 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)"

		if ((system_dirs_len == 0 && system_files_len == 0)); then
			print_error "Impermanence enabled but no system persistence paths were returned!"
			exit 1
		fi

		if ((user_dirs_len == 0 && user_files_len == 0)); then
			print_error "Impermanence enabled but no user persistence paths were returned!"
			exit 1
		fi
	fi
}

resolve_sops_key_sources() {
	if [[ ${_DRY_RUN:-false} == "true" ]]; then
		echo
		print_info "(dry run) Would resolve SOPS age key sources (host keys or provided --age-* files)."
		_SYSTEM_KEY_SRC="<age-system-key>"
		_USER_KEY_SRC="<age-user-key>"
		return 0
	fi
	if [[ -n ${_AGE_FILE} ]]; then
		_SYSTEM_KEY_SRC="${_AGE_FILE}"
		_USER_KEY_SRC="${_AGE_FILE}"
	elif [[ -n ${_AGE_SYSTEM_FILE} ]]; then
		_SYSTEM_KEY_SRC="${_AGE_SYSTEM_FILE}"
		if [[ ${_NO_USER_AGE} != "true" ]]; then
			_USER_KEY_SRC="${_AGE_USER_FILE}"
		fi
	else
		if [[ ${_DANGEROUSLY_USE_HOST_SOPS} != "true" ]]; then
			print_error "Missing age key input!"
			echo
			echo -e "${WHITE}Provide either:${RESET}"
			echo -e "  ${GREEN}--age-file <path>${RESET}  (sets both system+user)"
			echo -e "  ${GREEN}--age-system-file <path> --age-user-file <path>${RESET}"
			echo -e "  ${GREEN}--age-system-file <path> --no-user-age${RESET}"
			echo
			echo -e "Or explicitly opt into host key copying with: ${ORANGE}--dangerously-use-host-sops${RESET}"
			exit 1
		fi
		if [[ -f "${_PERSIST_PATH}/etc/sops/age/keys.txt" ]]; then
			_SYSTEM_KEY_SRC="${_PERSIST_PATH}/etc/sops/age/keys.txt"
		elif [[ -f "/etc/sops/age/keys.txt" ]]; then
			_SYSTEM_KEY_SRC="/etc/sops/age/keys.txt"
		fi
		[[ -n ${_SYSTEM_KEY_SRC} ]] || {
			print_error "No system SOPS age key found on host!"
			exit 1
		}
		if [[ ${_NO_USER_AGE} != "true" ]]; then
			if [[ -f "${_PERSIST_PATH}${HOME}/.config/sops/age/keys.txt" ]]; then
				_USER_KEY_SRC="${_PERSIST_PATH}${HOME}/.config/sops/age/keys.txt"
			elif [[ -f "${HOME}/.config/sops/age/keys.txt" ]]; then
				_USER_KEY_SRC="${HOME}/.config/sops/age/keys.txt"
			fi
			[[ -n ${_USER_KEY_SRC} ]] || {
				print_error "No user SOPS age key found on host (use --no-user-age to skip)!"
				exit 1
			}
		fi
	fi
	[[ -f ${_SYSTEM_KEY_SRC} ]] || {
		print_error "System age key file does not exist: ${_SYSTEM_KEY_SRC}!"
		exit 1
	}
	if [[ -n ${_USER_KEY_SRC} ]]; then
		[[ -f ${_USER_KEY_SRC} ]] || {
			print_error "User age key file does not exist: ${_USER_KEY_SRC}!"
			exit 1
		}
	fi
}

build_extra_files() {
	require_cmd mktemp
	require_cmd install
	if [[ ${_DRY_RUN:-false} == "true" ]]; then
		print_info "(dry run) Would create a temp dir containing extra files (age keys, migrate.json)."
		_INSTALL_TMPDIR="<tmpdir>"
		if [[ $_USES_IMPERMANENCE == "true" ]]; then
			_EXTRA_FILES_BASE="<tmpdir>$_PERSIST_PATH"
		else
			_EXTRA_FILES_BASE="<tmpdir>"
		fi
		return 0
	fi
	_INSTALL_TMPDIR=$(mktemp -d)

	if [[ $_USES_IMPERMANENCE == "true" ]]; then
		_EXTRA_FILES_BASE="$_INSTALL_TMPDIR$_PERSIST_PATH"
	else
		_EXTRA_FILES_BASE="$_INSTALL_TMPDIR"
	fi

	install -d -m755 "$_EXTRA_FILES_BASE/etc/sops/age"
	if [[ ${_DANGEROUSLY_USE_HOST_SOPS} == "true" && -z ${_AGE_FILE} && -z ${_AGE_SYSTEM_FILE} ]]; then
		print_info "Copying system SOPS age key with sudo ${ORANGE}(requires elevated privileges)"
		sudo install -m 600 -o "$(id -u)" -g "$(id -g)" "${_SYSTEM_KEY_SRC}" "$_EXTRA_FILES_BASE/etc/sops/age/keys.txt"
	else
		install -m 600 "${_SYSTEM_KEY_SRC}" "$_EXTRA_FILES_BASE/etc/sops/age/keys.txt"
	fi

	if [[ -n ${_USER_KEY_SRC} ]]; then
		install -d -m755 "$_EXTRA_FILES_BASE/home/$_USERNAME/.config/sops/age"
		if [[ ${_DANGEROUSLY_USE_HOST_SOPS} == "true" && -z ${_AGE_FILE} && -z ${_AGE_SYSTEM_FILE} ]]; then
			sudo install -m 600 -o "$(id -u)" -g "$(id -g)" "${_USER_KEY_SRC}" "$_EXTRA_FILES_BASE/home/$_USERNAME/.config/sops/age/keys.txt"
		else
			install -m 600 "${_USER_KEY_SRC}" "$_EXTRA_FILES_BASE/home/$_USERNAME/.config/sops/age/keys.txt"
		fi
	fi

	jq -n \
		--arg user "$_USERNAME" \
		--argjson uid "$_USER_UID" \
		--argjson gid "$_USER_GID" \
		--argjson impermanence "$_USES_IMPERMANENCE" \
		--arg persist_path "$_PERSIST_PATH" \
		--argjson sysd "$_SYSTEM_DIRS" --argjson sysf "$_SYSTEM_FILES" \
		--argjson usrd "$_USER_DIRS" --argjson usrf "$_USER_FILES" \
		'{user:$user, uid:$uid, gid:$gid, impermanence:$impermanence,
          persist_path:$persist_path,
          system_dirs:$sysd, system_files:$sysf,
          user_dirs:$usrd, user_files:$usrf}' \
		>"$_INSTALL_TMPDIR/migrate.json"
}

run_nixos_anywhere() {
	require_cmd nixos-anywhere
	require_cmd nix
	local build_on_remote_args=()
	[[ $_BUILD_ON_REMOTE != "true" ]] || build_on_remote_args=("--build-on" "remote")

	local chown_args=()
	if [[ -n ${_USER_KEY_SRC} ]]; then
		local user_key_target_dir
		if [[ $_USES_IMPERMANENCE == "true" ]]; then
			user_key_target_dir="$_PERSIST_PATH/home/$_USERNAME"
		else
			user_key_target_dir="/home/$_USERNAME"
		fi
		chown_args=("--chown" "$user_key_target_dir" "$_USER_UID:$_USER_GID")
	fi

	local extra_ssh_args=()
	if [[ -n "${_INSTALL_KNOWN_HOSTS_FILE:-}" ]]; then
		extra_ssh_args+=(--ssh-option "StrictHostKeyChecking=yes")
		extra_ssh_args+=(--ssh-option "UserKnownHostsFile=$_INSTALL_KNOWN_HOSTS_FILE")
		extra_ssh_args+=(--ssh-option "UpdateHostKeys=no")
	fi

	local develop_mode=false
	[[ ${NX_DEPLOYMENT_MODE:-develop} != "develop" ]] || develop_mode=true

	local repos_clean=true
	if ! git_worktrees_clean; then
		repos_clean=false
	fi

	local use_store_paths=false
	if [[ "$develop_mode" == "true" && "$repos_clean" != "true" ]]; then
		use_store_paths=true
	fi

	if [[ "$use_store_paths" == "true" && $_BUILD_ON_REMOTE == "true" ]]; then
		print_error "Cannot use --build-on-remote with dirty worktrees in develop mode!"
		print_error "Either commit/stash changes (nxconfig + nxcore) or build locally so local nxcore overrides are included!"
		exit 1
	fi

	local disko_script_store_path="" nixos_system_store_path=""
	if [[ "$use_store_paths" == "true" ]]; then
		print_info "Develop mode with dirty worktrees detected. Using pre-built store paths for nixos-anywhere..."

		local build_disko_cmd=(nix build -L --print-out-paths --no-link ".#nixosConfigurations.$_FULL_PROFILE.config.system.build.diskoScript" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}")
		local build_toplevel_cmd=(nix build -L --print-out-paths --no-link ".#nixosConfigurations.$_FULL_PROFILE.config.system.build.toplevel" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}")

		if [[ "${_DRY_RUN:-false}" == "true" ]]; then
			echo
			print_info "(dry run) Would build diskoScript: ${build_disko_cmd[*]}"
			print_info "(dry run) Would build toplevel:   ${build_toplevel_cmd[*]}"
		else
			print_info "Building diskoScript..."
			if ! disko_script_store_path="$("${build_disko_cmd[@]}" | head -n1)"; then
				print_error "Failed to build diskoScript store path for $_FULL_PROFILE!"
				exit 1
			fi
			print_info "Building toplevel..."
			if ! nixos_system_store_path="$("${build_toplevel_cmd[@]}" | head -n1)"; then
				print_error "Failed to build toplevel store path for $_FULL_PROFILE!"
				exit 1
			fi
		fi
	fi

	local na_cmd=()
	if [[ "$use_store_paths" == "true" ]]; then
		na_cmd=(nixos-anywhere --store-paths "$disko_script_store_path" "$nixos_system_store_path")
	else
		if [[ "$develop_mode" == "true" && "$repos_clean" == "true" ]]; then
			print_info "Develop mode but nxconfig + nxcore are clean. Using flake.lock inputs for nixos-anywhere."
		fi
		na_cmd=(nixos-anywhere --flake ".#$_FULL_PROFILE")
	fi
	na_cmd+=(--target-host "$_TARGET" --extra-files "$_INSTALL_TMPDIR" --phases "kexec,disko,install")
	na_cmd+=("${extra_ssh_args[@]+"${extra_ssh_args[@]}"}")
	na_cmd+=("${chown_args[@]+"${chown_args[@]}"}")

	if [[ "$use_store_paths" != "true" ]]; then
		na_cmd+=("${build_on_remote_args[@]+"${build_on_remote_args[@]}"}")
	fi
	na_cmd+=("${_NA_ARGS[@]+"${_NA_ARGS[@]}"}")

	if [[ "${_DRY_RUN:-false}" == "true" ]]; then
		echo
		print_info "(dry run) Would run: ${na_cmd[*]}"
		echo
	else
		print_info "Running nixos-anywhere installation on $_TARGET..."
		ask_run_tty "${na_cmd[@]}"
	fi
}

copy_repos_to_target() {
	require_cmd ssh
	require_cmd rsync
	[[ -n "$_USERNAME" && "$_USERNAME" != "null" ]] || return 0
	[[ "$_DEP_MODE" != "managed" ]] || return 0
	[[ -n "${CONFIG_DIR:-}" ]] || {
		print_error "Internal error: CONFIG_DIR not set!"
		exit 1
	}
	[[ -n "${NXCORE_DIR:-}" ]] || {
		print_error "Internal error: NXCORE_DIR not set!"
		exit 1
	}

	local base_path
	if [[ "$_USES_IMPERMANENCE" == "true" ]]; then
		base_path="${_PERSIST_PATH}/home/${_USERNAME}/.config/nx"
	else
		base_path="/home/${_USERNAME}/.config/nx"
	fi

	local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=30)
	[[ -z "$_SSH_IDENTITY_FILE" ]] || ssh_opts+=(-i "$_SSH_IDENTITY_FILE")
	[[ "$_RESOLVED_PORT" == "22" ]] || ssh_opts+=(-p "$_RESOLVED_PORT")
	ssh_opts+=("${_RESOLVED_SSH_EXTRA_OPTS[@]+"${_RESOLVED_SSH_EXTRA_OPTS[@]}"}")

	local rsync_ssh=(ssh -o BatchMode=yes -o ConnectTimeout=30)
	[[ -z "$_SSH_IDENTITY_FILE" ]] || rsync_ssh+=(-i "$_SSH_IDENTITY_FILE")
	[[ "$_RESOLVED_PORT" == "22" ]] || rsync_ssh+=(-p "$_RESOLVED_PORT")
	rsync_ssh+=("${_RESOLVED_SSH_EXTRA_OPTS[@]+"${_RESOLVED_SSH_EXTRA_OPTS[@]}"}")

	if [[ ${_DRY_RUN:-false} == "true" ]]; then
		print_info "(dry run) Would create: ssh ${ssh_opts[*]} $_TARGET \"mkdir -p \\\"/mnt${base_path}\\\"\""
		print_info "(dry run) Would copy nxconfig: rsync -a --delete -e \"${rsync_ssh[*]}\" \"$CONFIG_DIR/\" \"$_TARGET:/mnt${base_path}/nxconfig/\""
		print_info "(dry run) Would write profile marker: printf '%s' \"$_PROFILE\" > \"$_INSTALL_TMPDIR/.nx-profile.conf\""
		print_info "(dry run) Would upload profile marker: rsync -a -e \"${rsync_ssh[*]}\" \"$_INSTALL_TMPDIR/.nx-profile.conf\" \"$_TARGET:/mnt${base_path}/nxconfig/.nx-profile.conf\""
		if [[ "$_DEP_MODE" == "local" || "$_DEP_MODE" == "develop" ]]; then
			print_info "(dry run) Would copy nxcore: rsync -a --delete -e \"${rsync_ssh[*]}\" \"$NXCORE_DIR/\" \"$_TARGET:/mnt${base_path}/nxcore/\""
		fi
		print_info "(dry run) Would chown: ssh ${ssh_opts[*]} $_TARGET \"chown -R \\\"${_USER_UID}:${_USER_GID}\\\" \\\"/mnt${base_path}\\\"\""
		return 0
	fi

	print_info "Preparing directory structure on $_TARGET..."
	# shellcheck disable=SC2029
	ask_run_tty ssh "${ssh_opts[@]}" "$_TARGET" "mkdir -p \"/mnt${base_path}\""

	print_info "Copying nxconfig to target..."
	ask_run_tty rsync -a --delete -e "${rsync_ssh[*]}" "$CONFIG_DIR/" "$_TARGET:/mnt${base_path}/nxconfig/"

	print_info "Selecting profile in copied nxconfig..."
	printf '%s' "$_PROFILE" >"$_INSTALL_TMPDIR/.nx-profile.conf"
	ask_run_tty rsync -a -e "${rsync_ssh[*]}" "$_INSTALL_TMPDIR/.nx-profile.conf" "$_TARGET:/mnt${base_path}/nxconfig/.nx-profile.conf"

	if [[ "$_DEP_MODE" == "local" || "$_DEP_MODE" == "develop" ]]; then
		print_info "Copying nxcore to target..."
		ask_run_tty rsync -a --delete -e "${rsync_ssh[*]}" "$NXCORE_DIR/" "$_TARGET:/mnt${base_path}/nxcore/"
	fi

	print_info "Setting ownership on $_TARGET..."
	# shellcheck disable=SC2029
	ask_run_tty ssh "${ssh_opts[@]}" "$_TARGET" "chown -R \"${_USER_UID}:${_USER_GID}\" \"/mnt${base_path}\""
	print_success "Repos copied to target."
}

run_post_install() {
	require_cmd scp
	require_cmd ssh
	local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=30)
	local scp_opts=(-o BatchMode=yes -o ConnectTimeout=30)
	[[ -z "$_SSH_IDENTITY_FILE" ]] || {
		ssh_opts+=(-i "$_SSH_IDENTITY_FILE")
		scp_opts+=(-i "$_SSH_IDENTITY_FILE")
	}
	[[ "$_RESOLVED_PORT" == "22" ]] || {
		ssh_opts+=(-p "$_RESOLVED_PORT")
		scp_opts+=(-P "$_RESOLVED_PORT")
	}
	ssh_opts+=("${_RESOLVED_SSH_EXTRA_OPTS[@]+"${_RESOLVED_SSH_EXTRA_OPTS[@]}"}")
	scp_opts+=("${_RESOLVED_SSH_EXTRA_OPTS[@]+"${_RESOLVED_SSH_EXTRA_OPTS[@]}"}")
	if [[ ${_DRY_RUN:-false} == "true" ]]; then
		print_info "(dry run) Would scp migrate.json: scp ${scp_opts[*]} $_INSTALL_TMPDIR/migrate.json $_TARGET:/tmp/migrate.json"
		print_info "(dry run) Would scp remote-post-install.sh: scp ${scp_opts[*]} $(dirname "$SCRIPT_DIR")/utils/remote-post-install.sh $_TARGET:/tmp/"
		print_info "(dry run) Would run post-install: ssh ${ssh_opts[*]} $_TARGET \"bash /tmp/remote-post-install.sh /tmp/migrate.json\""
		return 0
	fi
	print_info "Uploading migration data to $_TARGET..."
	ask_run_tty scp "${scp_opts[@]}" "$_INSTALL_TMPDIR/migrate.json" "$_TARGET:/tmp/migrate.json"
	print_info "Uploading post-install script..."
	ask_run_tty scp "${scp_opts[@]}" "$(dirname "$SCRIPT_DIR")/utils/remote-post-install.sh" "$_TARGET:/tmp/"
	print_info "Running post-install script on $_TARGET..."
	ask_run_tty ssh "${ssh_opts[@]}" "$_TARGET" "bash /tmp/remote-post-install.sh /tmp/migrate.json"
}

trigger_reboot() {
	require_cmd ssh
	local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)
	[[ -z "$_SSH_IDENTITY_FILE" ]] || ssh_opts+=(-i "$_SSH_IDENTITY_FILE")
	[[ "$_RESOLVED_PORT" == "22" ]] || ssh_opts+=(-p "$_RESOLVED_PORT")
	ssh_opts+=("${_RESOLVED_SSH_EXTRA_OPTS[@]+"${_RESOLVED_SSH_EXTRA_OPTS[@]}"}")
	print_info "Rebooting $_RESOLVED_HOST..."
	if [[ $_DRY_RUN == "true" ]]; then
		print_info "(dry run) Would run: ssh ${ssh_opts[*]} $_TARGET reboot"
		return 0
	fi
	ask_run_tty ssh "${ssh_opts[@]}" "$_TARGET" reboot || true
	print_success "Reboot triggered. Connect manually when the host is back up."
	notify_success "Remote install ($_PROFILE)"
}

remote_install() {
	require_cmd nix
	require_cmd jq
	require_cmd ssh
	if [[ ${NX_DEPLOYMENT_MODE:-develop} == "develop" ]]; then
		EXTRA_ARGS=("--override-input" "core" "path:$NXCORE_DIR")
	else
		EXTRA_ARGS=()
	fi
	ALLOW_DIRTY_GIT=false
	_SKIP_VERIFICATION=false
	_ASK=false

	_PROFILE="${1:-}"
	[[ -n $_PROFILE ]] || {
		print_error "profile argument required!"
		exit 1
	}
	[[ "$_PROFILE" =~ ^[a-zA-Z0-9._-]+$ ]] || {
		print_error "Profile name '$_PROFILE' contains invalid characters!"
		exit 1
	}
	shift || true

	while [[ $# -gt 0 ]]; do
		case "${1:-}" in
		--show-trace)
			EXTRA_ARGS+=("--show-trace")
			_NA_ARGS+=("--show-trace")
			shift
			;;
		--allow-ifd)
			EXTRA_ARGS+=("--option" "allow-import-from-derivation" "true")
			_NA_ARGS+=("--option" "allow-import-from-derivation" "true")
			shift
			;;
		--offline)
			EXTRA_ARGS+=("--option" "substitute" "false")
			_NA_ARGS+=("--option" "substitute" "false")
			shift
			;;
		--allow-dirty-git)
			ALLOW_DIRTY_GIT=true
			shift
			;;
		--skip-verification)
			_SKIP_VERIFICATION=true
			shift
			;;
		--age-file)
			[[ $# -ge 2 ]] || {
				print_error "--age-file requires a file path!"
				exit 1
			}
			_AGE_FILE="$2"
			shift 2
			;;
		--age-system-file)
			[[ $# -ge 2 ]] || {
				print_error "--age-system-file requires a file path!"
				exit 1
			}
			_AGE_SYSTEM_FILE="$2"
			shift 2
			;;
		--age-user-file)
			[[ $# -ge 2 ]] || {
				print_error "--age-user-file requires a file path!"
				exit 1
			}
			_AGE_USER_FILE="$2"
			shift 2
			;;
		--no-user-age)
			_NO_USER_AGE=true
			shift
			;;
		--dangerously-use-host-sops)
			_DANGEROUSLY_USE_HOST_SOPS=true
			shift
			;;
		--force)
			_FORCE=true
			shift
			;;
		--build-on-remote)
			_BUILD_ON_REMOTE=true
			shift
			;;
		--allow-own-profile)
			_ALLOW_OWN_PROFILE=true
			shift
			;;
		--allow-localhost)
			_ALLOW_LOCALHOST=true
			shift
			;;
		--connect-only)
			_CONNECT_ONLY=true
			shift
			;;
		--dry-run)
			_DRY_RUN=true
			shift
			;;
		--ask)
			_ASK=true
			shift
			;;
		-*)
			print_error "Unknown option: $1!"
			exit 1
			;;
		*)
			print_error "Unexpected argument: $1!"
			exit 1
			;;
		esac
	done

	DRY_RUN_TEXT=""
	if [[ "$_DRY_RUN" == "true" ]]; then
		DRY_RUN_TEXT="${YELLOW} (DRY-RUN)${RESET}"
	fi
	ASK_TEXT=""
	if [[ "$_ASK" == "true" ]]; then
		ASK_TEXT="${ORANGE} (ASK)${RESET}"
	fi
	echo -e "${RED}Running ${WHITE}Install${RED} on ${WHITE}$_PROFILE${RED}!!!${RESET}${DRY_RUN_TEXT:-}${ASK_TEXT:-}"
	echo

	_AGE_FILE="$(resolve_arg_path "${_AGE_FILE}")"
	_AGE_SYSTEM_FILE="$(resolve_arg_path "${_AGE_SYSTEM_FILE}")"
	_AGE_USER_FILE="$(resolve_arg_path "${_AGE_USER_FILE}")"

	if [[ -z "$_AGE_FILE" && -z "$_AGE_SYSTEM_FILE" && "$_DANGEROUSLY_USE_HOST_SOPS" != "true" ]]; then
		local _auto_key_dir="$HOME/.local/share/nx/deploy-keys/$_PROFILE"
		if [[ -f "$_auto_key_dir/age-shared.txt" ]]; then
			_AGE_FILE="$_auto_key_dir/age-shared.txt"
			print_info "Using auto-discovered shared age key: $_AGE_FILE"
		else
			if [[ -f "$_auto_key_dir/age-system.txt" ]]; then
				_AGE_SYSTEM_FILE="$_auto_key_dir/age-system.txt"
				print_info "Using auto-discovered system age key: $_AGE_SYSTEM_FILE"
			fi
			if [[ "$_NO_USER_AGE" != "true" && -f "$_auto_key_dir/age-user.txt" ]]; then
				_AGE_USER_FILE="$_auto_key_dir/age-user.txt"
				print_info "Using auto-discovered user age key: $_AGE_USER_FILE"
			fi
		fi
	fi

	validate_sops_flags

	if [[ -z "$_AGE_FILE" && -z "$_AGE_SYSTEM_FILE" && "$_DANGEROUSLY_USE_HOST_SOPS" != "true" ]]; then
		print_error "No age key provided and none auto-discovered for profile $_PROFILE!"
		echo
		echo -e "${WHITE}Provide either:${RESET}"
		echo -e "  ${GREEN}--age-file <path>${RESET}  (sets both system+user)"
		echo -e "  ${GREEN}--age-system-file <path> --age-user-file <path>${RESET}"
		echo -e "  ${GREEN}--age-system-file <path> --no-user-age${RESET}"
		echo
		echo -e "Or explicitly opt into host key copying with: ${ORANGE}--dangerously-use-host-sops${RESET}"
		exit 1
	fi

	_FULL_PROFILE="$(construct_profile_name "$_PROFILE")"
	[[ $_DRY_RUN != "true" ]] || _DRY_RUN_CMD="echo"

	eval_install_profile
	check_install_preflight
	fetch_impermanence_lists
	resolve_sops_key_sources
	build_extra_files
	run_nixos_anywhere
	copy_repos_to_target
	run_post_install
	trigger_reboot
}

SUBCOMMAND="${1:-}"
shift || true
case "$SUBCOMMAND" in
keygen) remote_keygen "$@" ;;
install) remote_install "$@" ;;
sync) remote_sync "$@" ;;
boot) remote_boot "$@" ;;
test) remote_test "$@" ;;
*)
	print_error "Unknown nx remote subcommand: $SUBCOMMAND!"
	exit 1
	;;
esac
