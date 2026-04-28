#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
INVOCATION_DIR="$(pwd)"
deployment_script_setup "vm"

umask 077

if [[ "$(uname)" != "Linux" ]]; then
    print_error "nx vm is only supported on Linux!"
    exit 1
fi

KEEP=false
NO_RUN=false
REUSE_LATEST=false
CLEANUP=false
CLEANUP_ALL=false
SELECT_VERSION=""
LIST_VERSIONS=false
LIST_ALL=false

DANGEROUSLY_USE_HOST_SOPS=false
NO_USER_AGE=false
AGE_FILE=""
AGE_SYSTEM_FILE=""
AGE_USER_FILE=""

NX_VM_LOCK="${NX_VM_LOCK:-/tmp/.nx-vm-lock}"
NX_VM_RUNTIME_SHARE="${NX_VM_RUNTIME_SHARE:-/tmp/nx-vm}"
NX_VM_RUNTIME="${NX_VM_RUNTIME_SHARE}/nx-vm"

LOCK_ACQUIRED=false
RUNTIME_CREATED=false

EPHEMERAL_CLEANUP=false
EPHEMERAL_VM_FOLDER=""
EPHEMERAL_VM_RESULT=""
EPHEMERAL_VM_IMAGE=""

cleanup() {
    set +e

    if [[ "${RUNTIME_CREATED}" == "true" && -n "${NX_VM_RUNTIME:-}" && -d "${NX_VM_RUNTIME}" ]]; then
        for key_file in "${NX_VM_RUNTIME}/system/keys.txt" "${NX_VM_RUNTIME}/user/keys.txt"; do
            if [[ -f "${key_file}" && ! -L "${key_file}" ]]; then
                if command -v shred >/dev/null 2>&1; then
                    shred -u -- "${key_file}" 2>/dev/null || rm -f -- "${key_file}"
                else
                    rm -f -- "${key_file}"
                fi
            fi
        done
    fi

    if [[ "${EPHEMERAL_CLEANUP}" == "true" ]]; then
        rm -f -- "${EPHEMERAL_VM_IMAGE}" "${EPHEMERAL_VM_RESULT}" 2>/dev/null || true
        rm -rf -- "${EPHEMERAL_VM_FOLDER}" 2>/dev/null || true
    fi

    if [[ "${RUNTIME_CREATED}" == "true" && -n "${NX_VM_RUNTIME_SHARE:-}" && "${NX_VM_RUNTIME_SHARE:-}" != "/" ]]; then
        rm -rf -- "${NX_VM_RUNTIME_SHARE}" 2>/dev/null || true
    fi

    if [[ "${LOCK_ACQUIRED}" == "true" && -n "${NX_VM_LOCK:-}" && "${NX_VM_LOCK:-}" != "/" ]]; then
        rm -rf -- "${NX_VM_LOCK}" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM HUP QUIT

build_args=()
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        --age-file)
            [[ $# -lt 2 ]] && { print_error "--age-file requires a file path"; exit 1; }
            AGE_FILE="$2"
            shift 2
            ;;
        --age-system-file)
            [[ $# -lt 2 ]] && { print_error "--age-system-file requires a file path"; exit 1; }
            AGE_SYSTEM_FILE="$2"
            shift 2
            ;;
        --age-user-file)
            [[ $# -lt 2 ]] && { print_error "--age-user-file requires a file path"; exit 1; }
            AGE_USER_FILE="$2"
            shift 2
            ;;
        --dangerously-use-host-sops)
            DANGEROUSLY_USE_HOST_SOPS=true
            shift
            ;;
        --no-user-age)
            NO_USER_AGE=true
            shift
            ;;
        --keep)
            KEEP=true
            shift
            ;;
        --no-run)
            NO_RUN=true
            shift
            ;;
        --reuse-latest)
            REUSE_LATEST=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --cleanup-all)
            CLEANUP_ALL=true
            shift
            ;;
        --select)
            [[ $# -lt 2 ]] && { print_error "--select requires a version name"; exit 1; }
            SELECT_VERSION="$2"
            shift 2
            ;;
        --list)
            LIST_VERSIONS=true
            shift
            ;;
        --list-all)
            LIST_ALL=true
            shift
            ;;
        --diff|--show-derivation|--nixos|--standalone|--dry-run|--raw)
            print_error "Option $1 is not supported for 'nx vm'"
            exit 1
            ;;
        --*)
            print_error "Unknown option: $1"
            exit 1
            ;;
        *)
            build_args+=("$1")
            shift
            ;;
    esac
done

if [[ "${REUSE_LATEST}" == "true" && "${SELECT_VERSION}" != "" ]]; then
    print_error "--reuse-latest and --select cannot be used together!"
    exit 1
fi
if [[ ("${REUSE_LATEST}" == "true" || "${SELECT_VERSION}" != "") && "${NO_RUN}" == "true" ]]; then
    print_error "--reuse-latest/--select and --no-run cannot be used together!"
    exit 1
fi
if [[ "${KEEP}" == "true" && ("${REUSE_LATEST}" == "true" || "${SELECT_VERSION}" != "") ]]; then
    print_error "--keep cannot be used with --reuse-latest or --select!"
    exit 1
fi

resolve_arg_path() {
    local p="${1:-}"
    if [[ -z "${p}" ]]; then
        echo ""
        return 0
    fi
    if [[ "${p}" == /* ]]; then
        echo "${p}"
        return 0
    fi
    if [[ "${p}" == "~" ]]; then
        echo "${HOME}"
        return 0
    fi
    # shellcheck disable=SC2088
    if [[ "${p}" == "~/"* ]]; then
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

AGE_FILE="$(resolve_arg_path "${AGE_FILE}")"
AGE_SYSTEM_FILE="$(resolve_arg_path "${AGE_SYSTEM_FILE}")"
AGE_USER_FILE="$(resolve_arg_path "${AGE_USER_FILE}")"

if [[ "${NO_RUN}" == "true" ]]; then
    if [[ -n "${AGE_FILE}" || -n "${AGE_SYSTEM_FILE}" || -n "${AGE_USER_FILE}" || "${NO_USER_AGE}" == "true" || "${DANGEROUSLY_USE_HOST_SOPS}" == "true" ]]; then
        print_error "--no-run cannot be used with age key options (keys are only needed when running the VM)"
        exit 1
    fi
fi

if [[ -n "${AGE_FILE}" && ( -n "${AGE_SYSTEM_FILE}" || -n "${AGE_USER_FILE}" ) ]]; then
    print_error "--age-file is mutually exclusive with --age-system-file/--age-user-file"
    exit 1
fi
if [[ "${NO_USER_AGE}" == "true" && -n "${AGE_USER_FILE}" ]]; then
    print_error "--no-user-age is mutually exclusive with --age-user-file"
    exit 1
fi
if [[ "${NO_USER_AGE}" == "true" && -n "${AGE_FILE}" ]]; then
    print_error "--no-user-age is mutually exclusive with --age-file (use --age-system-file instead)"
    exit 1
fi
if [[ -n "${AGE_SYSTEM_FILE}" && -z "${AGE_USER_FILE}" && "${NO_USER_AGE}" != "true" ]]; then
    print_error "--age-user-file must be provided unless --no-user-age is set"
    exit 1
fi
if [[ -z "${AGE_SYSTEM_FILE}" && -n "${AGE_USER_FILE}" ]]; then
    print_error "--age-user-file requires --age-system-file"
    exit 1
fi

WILL_RUN_VM=false
if [[ "${NO_RUN}" != "true" && "${LIST_VERSIONS}" != "true" && "${LIST_ALL}" != "true" && "${CLEANUP}" != "true" && "${CLEANUP_ALL}" != "true" ]]; then
    WILL_RUN_VM=true
fi

if [[ "${WILL_RUN_VM}" == "true" ]]; then
    if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "develop" ]]; then
        PERSIST_PATH=$(nix eval --raw --override-input core "path:$NXCORE_DIR" .#variables.persist)
    else
        PERSIST_PATH=$(nix eval --raw .#variables.persist)
    fi

    if [[ -n "${AGE_FILE}" ]]; then
        [[ -f "${AGE_FILE}" ]] || { print_error "Age key file does not exist: ${AGE_FILE}"; exit 1; }
    elif [[ -n "${AGE_SYSTEM_FILE}" ]]; then
        [[ -f "${AGE_SYSTEM_FILE}" ]] || { print_error "System age key file does not exist: ${AGE_SYSTEM_FILE}"; exit 1; }
        if [[ "${NO_USER_AGE}" != "true" ]]; then
            [[ -f "${AGE_USER_FILE}" ]] || { print_error "User age key file does not exist: ${AGE_USER_FILE}"; exit 1; }
        fi
    else
        if [[ "${DANGEROUSLY_USE_HOST_SOPS}" != "true" ]]; then
            print_error "Missing age key input."
            echo
            echo -e "${WHITE}Provide either:${RESET}"
            echo -e "  ${GREEN}--age-file <path>${RESET}  (sets both system+user)"
            echo -e "  ${GREEN}--age-system-file <path> --age-user-file <path>${RESET}"
            echo -e "  ${GREEN}--age-system-file <path> --no-user-age${RESET}"
            echo
            echo -e "Or explicitly opt into host key copying with: ${ORANGE}--dangerously-use-host-sops${RESET}"
            exit 1
        fi

        system_key_found=""
        if [[ -f "${PERSIST_PATH}/etc/sops/age/keys.txt" ]]; then
            system_key_found="${PERSIST_PATH}/etc/sops/age/keys.txt"
        elif [[ -f "/etc/sops/age/keys.txt" ]]; then
            system_key_found="/etc/sops/age/keys.txt"
        fi
        [[ -n "${system_key_found}" ]] || { print_error "No system SOPS age key found on host"; exit 1; }

        if [[ "${NO_USER_AGE}" != "true" ]]; then
            user_key_found=""
            if [[ -f "${PERSIST_PATH}${HOME}/.config/sops/age/keys.txt" ]]; then
                user_key_found="${PERSIST_PATH}${HOME}/.config/sops/age/keys.txt"
            elif [[ -f "${HOME}/.config/sops/age/keys.txt" ]]; then
                user_key_found="${HOME}/.config/sops/age/keys.txt"
            fi
            [[ -n "${user_key_found}" ]] || { print_error "No user SOPS age key found on host (use --no-user-age to skip)"; exit 1; }
        fi
    fi
fi

if [[ -L "${NX_VM_LOCK}" ]]; then
    print_error "Refusing to use symlink lock path: ${NX_VM_LOCK}"
    exit 1
fi
if ! mkdir -m 700 "${NX_VM_LOCK}" 2>/dev/null; then
    stale_pid=""
    if [[ -f "${NX_VM_LOCK}/info" ]]; then
        stale_pid="$(cut -d: -f1 "${NX_VM_LOCK}/info" 2>/dev/null || true)"
    fi
    if [[ -n "${stale_pid}" && "${stale_pid}" =~ ^[0-9]+$ ]] && ! kill -0 "${stale_pid}" 2>/dev/null; then
        rm -rf -- "${NX_VM_LOCK}" 2>/dev/null || true
        if ! mkdir -m 700 "${NX_VM_LOCK}" 2>/dev/null; then
            print_error "Failed to acquire lock at ${NX_VM_LOCK}"
            exit 1
        fi
    else
        lock_info=""
        [[ -f "${NX_VM_LOCK}/info" ]] && lock_info=" ($(cat "${NX_VM_LOCK}/info"))"
        print_error "Another nx vm process is already running!${lock_info}"
        exit 1
    fi
fi
LOCK_ACQUIRED=true
echo "$$:vm:$(date +%s)" > "${NX_VM_LOCK}/info"

VM_CACHE="${HOME}/.cache/nx/vms"

shopt -s nullglob
stale_removed=()
for version_dir in "${VM_CACHE}"/*/*/; do
    result_link="${version_dir}result"
    if [[ -L "${result_link}" && ! -e "${result_link}" ]]; then
        version="$(basename "${version_dir%/}")"
        profile="$(basename "$(dirname "${version_dir%/}")")"
        stale_removed+=("${profile}/${version}")
        rm -f -- "${result_link}" "${version_dir}result.qcow2" || true
        rmdir -- "${version_dir%/}" 2>/dev/null || true
        rmdir -- "$(dirname "${version_dir%/}")" 2>/dev/null || true
    fi
done
shopt -u nullglob
if [[ ${#stale_removed[@]} -gt 0 ]]; then
    print_info "Removed stale VM cache entries (nix store GC):"
    for entry in "${stale_removed[@]}"; do
        echo "  ${entry}"
    done
    echo
fi

if [[ "${CLEANUP_ALL}" == "true" ]]; then
    if [[ -d "${NX_VM_RUNTIME_SHARE}" ]]; then
        print_error "Cannot cleanup: a VM is currently running!"
        exit 1
    fi
    shopt -s nullglob
    to_remove=("${VM_CACHE}"/*)
    shopt -u nullglob
    if [[ ${#to_remove[@]} -gt 0 ]]; then
        rm -rf -- "${to_remove[@]}"
    fi
    print_success "All VM image caches cleared"
    exit 0
fi

if [[ "${LIST_ALL}" == "true" ]]; then
    running_version=""
    [[ -f "${NX_VM_RUNTIME}/version" ]] && running_version="$(cat "${NX_VM_RUNTIME}/version")"
    running_profile=""
    [[ -f "${NX_VM_RUNTIME}/version" ]] && running_profile="$(ls -1 "${VM_CACHE}" 2>/dev/null | while read -r p; do
        if [[ -d "${VM_CACHE}/${p}/${running_version}" ]]; then
            echo "${p}"
            break
        fi
    done)"
    shopt -s nullglob
    profile_dirs=("${VM_CACHE}"/*)
    shopt -u nullglob
    if [[ ${#profile_dirs[@]} -eq 0 ]]; then
        print_info "No VM images found"
        exit 0
    fi
    found_any=false
    for profile_dir in "${profile_dirs[@]}"; do
        [[ -d "${profile_dir}" ]] || continue
        shopt -s nullglob
        version_dirs=("${profile_dir}"/*)
        shopt -u nullglob
        [[ ${#version_dirs[@]} -eq 0 ]] && continue
        found_any=true
        profile="$(basename "${profile_dir}")"
        echo -e "${WHITE}VM images for ${profile}:${RESET}"
        for version_dir in "${version_dirs[@]}"; do
            [[ -d "${version_dir}" ]] || continue
            version="$(basename "${version_dir}")"
            running_tag=""
            [[ "${version}" == "${running_version}" && "${profile}" == "${running_profile}" ]] && running_tag="${GREEN} [RUNNING]${RESET}"
            status_parts=()
            [[ -L "${version_dir}/result" ]] && status_parts+=("result")
            [[ -f "${version_dir}/result.qcow2" ]] && status_parts+=("qcow2")
            status_str=""
            [[ ${#status_parts[@]} -gt 0 ]] && status_str=" ($(IFS=,; echo "${status_parts[*]}"))"
            echo -e "  ${YELLOW}${version}${RESET}${running_tag}${status_str}"
        done
    done
    if [[ "${found_any}" == "false" ]]; then
        print_info "No VM images found"
    fi
    exit 0
fi

parse_build_deployment_args "${build_args[@]}"

PROFILE="$(retrieve_active_profile)"

base_profile="${PROFILE%--*}"
if [[ -n "${BUILD_OVERRIDE_PROFILE:-}" ]]; then
    base_profile="${BUILD_OVERRIDE_PROFILE}"
fi

if [[ -n "${BUILD_OVERRIDE_ARCH:-}" ]]; then
    PROFILE="$(construct_profile_name "${base_profile}" "${BUILD_OVERRIDE_ARCH}")"
elif [[ -n "${BUILD_OVERRIDE_PROFILE:-}" ]]; then
    PROFILE="$(construct_profile_name "${base_profile}")"
fi

PROFILE_CACHE="${VM_CACHE}/${PROFILE}"

mkdir -p "${PROFILE_CACHE}"

if [[ "${CLEANUP}" == "true" ]]; then
    if [[ -d "${NX_VM_RUNTIME_SHARE}" ]]; then
        print_error "Cannot cleanup ${PROFILE}: a VM is currently running!"
        exit 1
    fi
    rm -rf -- "${PROFILE_CACHE}"
    print_success "VM image cache for ${PROFILE} cleared"
    exit 0
fi

if [[ "${LIST_VERSIONS}" == "true" ]]; then
    shopt -s nullglob
    version_dirs=("${PROFILE_CACHE}"/*)
    shopt -u nullglob
    if [[ ${#version_dirs[@]} -eq 0 ]]; then
        print_info "No VM images found for ${PROFILE}"
        exit 0
    fi
    running_version=""
    [[ -f "${NX_VM_RUNTIME}/version" ]] && running_version="$(cat "${NX_VM_RUNTIME}/version")"
    echo -e "${WHITE}VM images for ${PROFILE}:${RESET}"
    for version_dir in "${version_dirs[@]}"; do
        [[ -d "${version_dir}" ]] || continue
        version="$(basename "${version_dir}")"
        running_tag=""
        [[ "${version}" == "${running_version}" ]] && running_tag="${GREEN} [RUNNING]${RESET}"
        status_parts=()
        [[ -L "${version_dir}/result" ]] && status_parts+=("result")
        [[ -f "${version_dir}/result.qcow2" ]] && status_parts+=("qcow2")
        status_str=""
        [[ ${#status_parts[@]} -gt 0 ]] && status_str=" ($(IFS=,; echo "${status_parts[*]}"))"
        echo -e "  ${YELLOW}${version}${RESET}${running_tag}${status_str}"
    done
    exit 0
fi

verify_commits

if [[ "${REUSE_LATEST}" == "true" ]]; then
    latest_version=""
    shopt -s nullglob
    for version_dir in "${PROFILE_CACHE}"/*/; do
        version="$(basename "${version_dir%/}")"
        [[ "${version}" == "ephemeral" ]] && continue
        [[ -z "${latest_version}" || "${version}" > "${latest_version}" ]] && latest_version="${version}"
    done
    shopt -u nullglob
    if [[ -z "${latest_version}" ]]; then
        print_error "No saved VM images found for ${PROFILE}. Build with --keep first!"
        exit 1
    fi
    VM_VERSION="${latest_version}"
elif [[ "${SELECT_VERSION}" != "" ]]; then
    VM_VERSION="${SELECT_VERSION}"
    if [[ ! -d "${PROFILE_CACHE}/${VM_VERSION}" ]]; then
        print_error "VM version '${VM_VERSION}' not found for ${PROFILE}. Use --list to see available versions."
        exit 1
    fi
else
    if [[ "${KEEP}" == "true" ]]; then
        VM_VERSION="$(date +%Y-%m-%d_%H-%M-%S)"
    else
        VM_VERSION="ephemeral"
    fi
fi

VM_FOLDER="${PROFILE_CACHE}/${VM_VERSION}"
VM_RESULT="${VM_FOLDER}/result"
VM_IMAGE="${VM_FOLDER}/result.qcow2"

if [[ "${REUSE_LATEST}" == "true" || "${SELECT_VERSION}" != "" ]]; then
    if [[ ! -L "${VM_RESULT}" || ! -f "${VM_IMAGE}" ]]; then
        print_error "VM image at ${VM_FOLDER} is incomplete!"
        exit 1
    fi
else
    mkdir -p "${VM_FOLDER}"
    if [[ -d "${VM_IMAGE}" && ! -L "${VM_IMAGE}" ]]; then
        rm -rf -- "${VM_IMAGE}"
    else
        rm -f -- "${VM_IMAGE}"
    fi
    if [[ -d "${VM_RESULT}" && ! -L "${VM_RESULT}" ]]; then
        rm -rf -- "${VM_RESULT}"
    else
        rm -f -- "${VM_RESULT}"
    fi

    VM_HOST="${PROFILE}--VIRTUAL"
    nh_args=(
        --hostname "${VM_HOST}"
        --out-link "${VM_RESULT}"
        --print-build-logs
    )

    print_info "Building image at ${YELLOW}$VM_RESULT"
    echo

    if GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null timeout "${TIMEOUT}s" nh os build-vm "${nh_args[@]}" . -- "${EXTRA_ARGS[@]:-}"; then
      notify_success "VM (build)"
    else
      notify_error "VM (build)"
      exit 1
    fi
    echo
fi

if [[ "${NO_RUN}" != "true" ]]; then
    if [[ -d "${NX_VM_RUNTIME_SHARE}" ]]; then
        print_error "A VM is already running!"
        exit 1
    fi
    if [[ -L "${NX_VM_RUNTIME_SHARE}" ]]; then
        print_error "Refusing to use symlink shared dir path: ${NX_VM_RUNTIME_SHARE}"
        exit 1
    fi
    mkdir -m 700 "${NX_VM_RUNTIME_SHARE}"
    RUNTIME_CREATED=true
    mkdir -m 700 "${NX_VM_RUNTIME}"
    mkdir -m 700 "${NX_VM_RUNTIME}/system" "${NX_VM_RUNTIME}/user"
    echo "${VM_VERSION}" > "${NX_VM_RUNTIME}/version"

    system_key_src=""
    user_key_src=""

    if [[ -n "${AGE_FILE}" ]]; then
        system_key_src="${AGE_FILE}"
        user_key_src="${AGE_FILE}"
    elif [[ -n "${AGE_SYSTEM_FILE}" ]]; then
        system_key_src="${AGE_SYSTEM_FILE}"
        if [[ "${NO_USER_AGE}" != "true" ]]; then
            user_key_src="${AGE_USER_FILE}"
        fi
	    else
	        if [[ "${DANGEROUSLY_USE_HOST_SOPS}" != "true" ]]; then
	            print_error "Missing age key input!"
	            exit 1
	        fi
	        if [[ -f "${PERSIST_PATH}/etc/sops/age/keys.txt" ]]; then
	            system_key_src="${PERSIST_PATH}/etc/sops/age/keys.txt"
	        elif [[ -f "/etc/sops/age/keys.txt" ]]; then
            system_key_src="/etc/sops/age/keys.txt"
        fi
        if [[ -f "${PERSIST_PATH}${HOME}/.config/sops/age/keys.txt" ]]; then
            user_key_src="${PERSIST_PATH}${HOME}/.config/sops/age/keys.txt"
        elif [[ -f "${HOME}/.config/sops/age/keys.txt" ]]; then
            user_key_src="${HOME}/.config/sops/age/keys.txt"
        fi
    fi

    if [[ -z "${system_key_src}" ]]; then
        print_error "No system age key file found."
        exit 1
    fi

    if [[ ! -f "${system_key_src}" ]]; then
        print_error "System age key file does not exist: ${system_key_src}"
        exit 1
    fi

    echo
    if [[ "${DANGEROUSLY_USE_HOST_SOPS}" == "true" && -z "${AGE_FILE}" && -z "${AGE_SYSTEM_FILE}" ]]; then
        print_info "Copying system SOPS age key with sudo ${ORANGE}(requires elevated privileges)"
        notify_info "vm" "Require authentication for copying sops keys..."
        sudo install -m 600 -o "$(id -u)" -g "$(id -g)" "${system_key_src}" "${NX_VM_RUNTIME}/system/keys.txt"
    else
        print_info "Copying system age key from ${WHITE}${system_key_src}${RESET}"
        install -m 600 "${system_key_src}" "${NX_VM_RUNTIME}/system/keys.txt"
    fi
    echo

    if [[ -f "${NX_VM_RUNTIME}/system/keys.txt" ]]; then
      if [[ "${NO_USER_AGE}" == "true" ]]; then
          print_info "Skipping user age key due to ${ORANGE}--no-user-age${RESET}"
          touch "${NX_VM_RUNTIME}/user/keys.txt"
      else
          if [[ -z "${user_key_src}" ]]; then
              print_error "No user age key file found. Provide --age-user-file or set --no-user-age"
              exit 1
          fi
          if [[ ! -f "${user_key_src}" ]]; then
              print_error "User age key file does not exist: ${user_key_src}"
              exit 1
          fi
          print_info "Copying user age key from ${WHITE}${user_key_src}${RESET}"
          install -m 600 "${user_key_src}" "${NX_VM_RUNTIME}/user/keys.txt"
      fi
    fi

    if [[ ! -f "${NX_VM_RUNTIME}/system/keys.txt" || ! -f "${NX_VM_RUNTIME}/user/keys.txt" ]]; then
      echo -e "\n${RED}Sops key copying did not work!${RESET}"
      notify_error "VM (run)"
      exit 1
    fi

    if [[ "${KEEP}" != "true" && "${REUSE_LATEST}" != "true" && "${SELECT_VERSION}" == "" ]]; then
        EPHEMERAL_CLEANUP=true
        EPHEMERAL_VM_FOLDER="${VM_FOLDER}"
        EPHEMERAL_VM_RESULT="${VM_RESULT}"
        EPHEMERAL_VM_IMAGE="${VM_IMAGE}"
    fi
    export NIX_DISK_IMAGE="${VM_IMAGE}"
    export SHARED_DIR="${NX_VM_RUNTIME_SHARE}"
    "${VM_RESULT}/bin/run-${base_profile}-vm"
fi
