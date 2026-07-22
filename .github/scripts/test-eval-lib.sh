#!/usr/bin/env bash
set -euo pipefail

: "${TE_CORE_DIR:?TE_CORE_DIR must be set by run-all-test-evals.sh}"
: "${TE_TEMPLATE_DIR:?TE_TEMPLATE_DIR must be set by run-all-test-evals.sh}"
: "${TE_CASE_NAME:?TE_CASE_NAME must be set by run-all-test-evals.sh}"
: "${TE_RESULTS_TSV:?TE_RESULTS_TSV must be set by run-all-test-evals.sh}"
: "${TE_DUMMY_AGE_PUBLIC_KEY:?TE_DUMMY_AGE_PUBLIC_KEY must be set by run-all-test-evals.sh}"
: "${TE_FIXED_EVAL_TIMESTAMP:?TE_FIXED_EVAL_TIMESTAMP must be set by run-all-test-evals.sh}"

te_setup() {
	TE_WORKDIR=$(mktemp -d)
	trap 'rm -rf "$TE_WORKDIR"' EXIT
	cp -a "$TE_TEMPLATE_DIR" "$TE_WORKDIR/config"
}

te_write_yaml_stub() {
	local dest="$1"
	mkdir -p "$(dirname "$dest")"
	printf 'placeholder: dummy\nsops:\n    age:\n        - recipient: %s\n' \
		"$TE_DUMMY_AGE_PUBLIC_KEY" >"$dest"
}

te_write_binary_stub() {
	local dest="$1"
	mkdir -p "$(dirname "$dest")"
	printf '{\n    "data": "dummy",\n    "sops": {\n        "age": [\n            {\n                "recipient": "%s"\n            }\n        ]\n    }\n}\n' \
		"$TE_DUMMY_AGE_PUBLIC_KEY" >"$dest"
}

te_secrets() {
	local scope="$1"
	local format="$2"
	shift 2

	local basedir
	case "$scope" in
	global)
		basedir="$TE_WORKDIR/config/secrets"
		;;
	nixos:*)
		basedir="$TE_WORKDIR/config/profiles/nixos/${scope#nixos:}/secrets"
		;;
	integrated:*)
		basedir="$TE_WORKDIR/config/profiles/home-integrated/${scope#integrated:}/secrets"
		;;
	standalone:*)
		basedir="$TE_WORKDIR/config/profiles/home-standalone/${scope#standalone:}/secrets"
		;;
	*)
		echo "te_secrets: unknown scope '$scope' (use global, nixos:NAME, integrated:NAME, standalone:NAME)" >&2
		return 1
		;;
	esac

	local writer
	case "$format" in
	yaml) writer=te_write_yaml_stub ;;
	binary) writer=te_write_binary_stub ;;
	*)
		echo "te_secrets: unknown format '$format' (use yaml or binary)" >&2
		return 1
		;;
	esac

	local file
	for file in "$@"; do
		"$writer" "$basedir/$file"
	done
}

te_git_commit_config() {
	local repo="$TE_WORKDIR/config"
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
		git -C "$repo" -c init.defaultBranch=main init -q
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
		git -C "$repo" add -A -f
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
		GIT_AUTHOR_DATE="@$TE_FIXED_EVAL_TIMESTAMP +0000" \
		GIT_COMMITTER_DATE="@$TE_FIXED_EVAL_TIMESTAMP +0000" \
		git -C "$repo" \
		-c user.name="nx-test-eval" \
		-c user.email="nx-test-eval@example.com" \
		-c commit.gpgsign=false \
		commit -q -m "test eval snapshot"
}

te_eval() {
	local kind="$1"
	local target="$2"

	local attr
	case "$kind" in
	nixos) attr="nixosConfigurations.$target.config.system.build.toplevel.drvPath" ;;
	nixos-vm) attr="nixosConfigurations.$target.config.system.build.vm.drvPath" ;;
	home) attr="homeConfigurations.$target.activationPackage.drvPath" ;;
	*)
		echo "te_eval: unknown kind '$kind' (use nixos, nixos-vm or home)" >&2
		return 1
		;;
	esac

	te_git_commit_config

	echo "Evaluating $attr..."
	local drv
	drv=$(nix eval --raw --no-write-lock-file \
		--override-input core "git+file://$TE_CORE_DIR" \
		"git+file://$TE_WORKDIR/config#$attr")
	echo "$drv"
	printf '%s\tOK\t%s\n' "$TE_CASE_NAME" "$drv" >>"$TE_RESULTS_TSV"
}
