#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "gc"
check_deployment_conflicts "gc"

if [[ -e /etc/NIXOS ]]; then
	if nh clean all --keep-since 21d --keep 10; then
		notify_success "GC"
	else
		notify_error "GC"
		exit 1
	fi
else
	if nh clean user --keep-since 21d --keep 10; then
		notify_success "GC"
	else
		notify_error "GC"
		exit 1
	fi
fi
