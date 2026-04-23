#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "vm"

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

build_args=()
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
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
        --diff|--show-derivation|--nixos|--standalone|--dry-run|--raw)
            print_error "Option $1 is not supported for 'nx vm'"
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

NX_VM_LOCK="/tmp/.nx-vm-lock"
if ! mkdir "${NX_VM_LOCK}" 2>/dev/null; then
    lock_info=""
    [[ -f "${NX_VM_LOCK}/info" ]] && lock_info=" ($(cat "${NX_VM_LOCK}/info"))"
    print_error "Another nx vm process is already running!${lock_info}"
    exit 1
fi
echo "$$:vm:$(date +%s)" > "${NX_VM_LOCK}/info"
trap 'rm -rf -- "${NX_VM_LOCK}" || true' EXIT

VM_CACHE="${HOME}/.cache/nx/vms"
NX_VM_RUNTIME_SHARE="/tmp/nx-vm"
NX_VM_RUNTIME="${NX_VM_RUNTIME_SHARE}/nx-vm"

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
    echo "VM images for ${PROFILE}:"
    for version_dir in "${version_dirs[@]}"; do
        [[ -d "${version_dir}" ]] || continue
        version="$(basename "${version_dir}")"
        running_tag=""
        [[ "${version}" == "${running_version}" ]] && running_tag=" [RUNNING]"
        status_parts=()
        [[ -L "${version_dir}/result" ]] && status_parts+=("result")
        [[ -f "${version_dir}/result.qcow2" ]] && status_parts+=("qcow2")
        status_str=""
        [[ ${#status_parts[@]} -gt 0 ]] && status_str=" ($(IFS=,; echo "${status_parts[*]}"))"
        echo "  ${version}${running_tag}${status_str}"
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

    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null timeout "${TIMEOUT}s" nh os build-vm "${nh_args[@]}" . -- "${EXTRA_ARGS[@]:-}"
fi

if [[ "${NO_RUN}" != "true" ]]; then
    if [[ -d "${NX_VM_RUNTIME_SHARE}" ]]; then
        print_error "A VM is already running!"
        exit 1
    fi
    mkdir -m 700 "${NX_VM_RUNTIME_SHARE}"
    mkdir -m 700 "${NX_VM_RUNTIME}"
    mkdir "${NX_VM_RUNTIME}/system" "${NX_VM_RUNTIME}/user"
    trap 'rm -rf -- "${NX_VM_RUNTIME_SHARE}" || true; rm -rf -- "${NX_VM_LOCK}" || true' EXIT
    echo "${VM_VERSION}" > "${NX_VM_RUNTIME}/version"

    system_key=""
    if [[ -f "/persist/etc/sops/age/keys.txt" ]]; then
        system_key="/persist/etc/sops/age/keys.txt"
    elif [[ -f "/etc/sops/age/keys.txt" ]]; then
        system_key="/etc/sops/age/keys.txt"
    fi
    if [[ -z "${system_key}" ]]; then
        print_error "No system SOPS age key found!"
        exit 1
    fi
    echo
    print_info "Copying system SOPS age key with sudo ${ORANGE}(requires elevated privileges)"
    sudo install -m 600 -o "$(id -u)" -g "$(id -g)" "${system_key}" "${NX_VM_RUNTIME}/system/keys.txt"
    echo

    user_key=""
    if [[ -f "/persist${HOME}/.config/sops/age/keys.txt" ]]; then
        user_key="/persist${HOME}/.config/sops/age/keys.txt"
    elif [[ -f "${HOME}/.config/sops/age/keys.txt" ]]; then
        user_key="${HOME}/.config/sops/age/keys.txt"
    fi
    if [[ -n "${user_key}" ]]; then
        install -m 600 "${user_key}" "${NX_VM_RUNTIME}/user/keys.txt"
    fi

    if [[ "${KEEP}" != "true" && "${REUSE_LATEST}" != "true" && "${SELECT_VERSION}" == "" ]]; then
        trap 'rm -rf -- "${NX_VM_RUNTIME_SHARE}" || true; rm -f -- "${VM_IMAGE}" "${VM_RESULT}" || true; rm -rf -- "${VM_FOLDER}" || true; rm -rf -- "${NX_VM_LOCK}" || true' EXIT
    fi
    export NIX_DISK_IMAGE="${VM_IMAGE}"
    export SHARED_DIR="${NX_VM_RUNTIME_SHARE}"
    "${VM_RESULT}/bin/run-${base_profile}-vm"
fi
