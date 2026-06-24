args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  validPname =
    p:
    let
      v = p.pname or null;
    in
    v != null && v != "" && !(lib.hasInfix "." v);

  collectPackageInventory =
    ignoredPnames: pkgList:
    let
      valid = builtins.filter (p: validPname p && !(builtins.elem (p.pname or "") ignoredPnames)) pkgList;
      unique = lib.unique (map (p: p.pname) valid);
      byPname = lib.listToAttrs (map (p: lib.nameValuePair p.pname p) valid);
    in
    map (pname: {
      inherit pname;
      version = byPname.${pname}.version or null;
      name = byPname.${pname}.name or null;
      storePath = builtins.unsafeDiscardStringContext byPname.${pname}.outPath;
      unfree =
        let
          lics = lib.toList (byPname.${pname}.meta.license or [ ]);
        in
        lib.any (l: if builtins.isAttrs l then !(l.free or true) else false) lics;
    }) unique;
in
{
  name = "packages";
  group = "core";
  input = "build";

  description = "Package inventory generator and Hydra build status checker";

  rawOptions = {
    nx.packages.extra = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to include in the inventory and Hydra checks, for packages installed via services rather than package lists";
    };
    nx.packages.ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Package pnames to exclude from the inventory and Hydra checks";
    };
  };

  module = {
    system = config: {
      environment.etc."nx/system-packages.json" = {
        text = builtins.toJSON (
          collectPackageInventory config.nx.packages.ignore (
            config.environment.systemPackages ++ config.nx.packages.extra
          )
        );
        mode = "0444";
      };
    };

    home =
      config:
      let
        archStr =
          if self.isX86_64 && self.isLinux then
            "x86_64-linux"
          else if self.isAARCH64 && self.isLinux then
            "aarch64-linux"
          else if self.isX86_64 && self.isDarwin then
            "x86_64-darwin"
          else
            "aarch64-darwin";
        nextRelease = helpers.nextNixOSRelease config.nx.global.currentRelease;
        dataHomeRel = lib.removePrefix "${config.home.homeDirectory}/" config.xdg.dataHome;

        mkScript =
          name: release:
          let
            channel = if self.isDarwin then "nixpkgs-${release}-darwin" else "nixos-${release}";
            nixpkgsLock = toString (self.inputs.nixpkgs.lastModified or 0);
            tsExpr = ''(.value[0].timestamp // "" | if . == "" then 0 else fromdateiso8601 end)'';
            pnameExtract =
              if self.isDarwin then
                ''.key | rtrimstr(".\($arch)")''
              else
                ''.key | sub("^[^.]+\\."; "") | rtrimstr(".\($arch)")'';
            failedFilter = "to_entries[] | select(.value[0].success != true) | select(${tsExpr} >= $lock) | ${pnameExtract}";
            pendingFilter = "to_entries[] | select(.value[0].success != true) | select(${tsExpr} < $lock) | ${pnameExtract}";
          in
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
              pkgs.hydra-check
              pkgs.jq
            ];
            text = ''
              RED=$(printf '\033[1;38;5;196m')
              GREEN=$(printf '\033[1;38;5;82m')
              YELLOW=$(printf '\033[1;38;5;220m')
              CYAN=$(printf '\033[1;38;5;51m')
              WHITE=$(printf '\033[0;38;5;15m')
              GRAY=$(printf '\033[38;5;250m')
              RESET=$(printf '\033[0m')

              CHANNEL="${channel}"
              ARCH="${archStr}"
              NIXPKGS_LOCK="${nixpkgsLock}"

              SYSTEM_PKGS=()
              if [[ -f /etc/nx/system-packages.json ]]; then
                while IFS= read -r pkg; do
                  [[ -n "$pkg" ]] && SYSTEM_PKGS+=("$pkg")
                done < <(jq -r '.[] | select(.unfree != true) | .pname' /etc/nx/system-packages.json)
              fi

              HOME_PKGS=()
              if [[ -f "${config.xdg.dataHome}/nx/home-packages.json" ]]; then
                while IFS= read -r pkg; do
                  [[ -n "$pkg" ]] && HOME_PKGS+=("$pkg")
                done < <(jq -r '.[] | select(.unfree != true) | .pname' "${config.xdg.dataHome}/nx/home-packages.json")
              fi

              if [[ $# -gt 0 ]]; then
                ALL_PACKAGES=("$@")
              else
                ALL_PACKAGES=("''${SYSTEM_PKGS[@]+"''${SYSTEM_PKGS[@]}"}" "''${HOME_PKGS[@]+"''${HOME_PKGS[@]}"}")
              fi

              if [[ ''${#ALL_PACKAGES[@]} -eq 0 ]]; then
                echo "''${YELLOW}No packages configured to check.''${RESET}"
                exit 0
              fi

              echo "''${WHITE}Checking ''${CYAN}''${#ALL_PACKAGES[@]}''${WHITE} packages on Hydra (channel: ''${CYAN}''${CHANNEL}''${WHITE}, arch: ''${CYAN}''${ARCH}''${WHITE})...''${RESET}"

              TOTAL_COUNT=''${#ALL_PACKAGES[@]}
              DONE=0
              MERGED_FILE=$(mktemp)
              RESULT_FILE=$(mktemp)
              echo "{}" > "''${MERGED_FILE}"
              trap 'rm -f "''${MERGED_FILE}" "''${RESULT_FILE}" "''${MERGED_FILE}.tmp"' EXIT
              printf "\n      ''${GRAY}0/%d''${RESET}" "''${TOTAL_COUNT}"
              i=0
              while [[ $i -lt ''${#ALL_PACKAGES[@]} ]]; do
                BATCH=("''${ALL_PACKAGES[@]:$i:10}")
                hydra-check --json --channel "''${CHANNEL}" "''${BATCH[@]}" > "''${RESULT_FILE}" 2>/dev/null || true
                if [[ -s "''${RESULT_FILE}" ]]; then
                  jq -s '.[0] * .[1]' "''${MERGED_FILE}" "''${RESULT_FILE}" > "''${MERGED_FILE}.tmp" 2>/dev/null \
                    && mv "''${MERGED_FILE}.tmp" "''${MERGED_FILE}" || true
                fi
                DONE=$((DONE + ''${#BATCH[@]}))
                printf "\r      ''${GRAY}%d/%d''${RESET}" "''${DONE}" "''${TOTAL_COUNT}"
                i=$((i + 10))
              done
              printf "\n\n"

              OUTPUT=$(cat "''${MERGED_FILE}")
              TOTAL=$(echo "''${OUTPUT}" | jq 'keys | length')
              SUCCEEDED=$(echo "''${OUTPUT}" | jq '[to_entries[] | select(.value[0].success == true)] | length')
              FAILED=$(echo "''${OUTPUT}" | jq --argjson lock "''${NIXPKGS_LOCK}" '[to_entries[] | select(.value[0].success != true) | select(${tsExpr} >= $lock)] | length')
              PENDING=$(echo "''${OUTPUT}" | jq --argjson lock "''${NIXPKGS_LOCK}" '[to_entries[] | select(.value[0].success != true) | select(${tsExpr} < $lock)] | length')

              if [[ "''${PENDING}" -gt 0 ]]; then
                echo "''${WHITE}Results: ''${GREEN}''${SUCCEEDED}/''${TOTAL}''${WHITE} succeeded, ''${RED}''${FAILED}''${WHITE} failed, ''${YELLOW}''${PENDING}''${WHITE} status unknown''${RESET}"
              else
                echo "''${WHITE}Results: ''${GREEN}''${SUCCEEDED}/''${TOTAL}''${WHITE} succeeded, ''${RED}''${FAILED}''${WHITE} failed''${RESET}"
              fi

              if [[ "''${FAILED}" -gt 0 ]]; then
                echo
                echo "''${WHITE}Failed packages:''${RESET}"
                CURRENT_LETTER=""
                CURRENT_LINE=""
                while IFS= read -r pkg_name; do
                  FIRST_UPPER=$(echo "''${pkg_name:0:1}" | tr '[:lower:]' '[:upper:]')
                  if [[ "''${FIRST_UPPER}" != "''${CURRENT_LETTER}" ]]; then
                    [[ -n "''${CURRENT_LINE}" ]] && echo "  ''${GRAY}''${CURRENT_LINE}''${RESET}"
                    CURRENT_LINE="''${pkg_name}"
                    CURRENT_LETTER="''${FIRST_UPPER}"
                  else
                    CURRENT_LINE="''${CURRENT_LINE} ''${pkg_name}"
                  fi
                done < <(echo "''${OUTPUT}" | jq -r --argjson lock "''${NIXPKGS_LOCK}" --arg arch "''${ARCH}" '${failedFilter}' | sort -f)
                [[ -n "''${CURRENT_LINE}" ]] && echo "  ''${WHITE}''${CURRENT_LINE}''${RESET}"
                echo
                echo "''${WHITE}Run ''${GRAY}\"hydra-check --channel ''${CHANNEL} <package>\"''${WHITE} to find out more details about a failed package!''${RESET}"
              fi

              if [[ "''${PENDING}" -gt 0 ]]; then
                echo
                echo "''${YELLOW}Status unknown (last Hydra build predates nixpkgs lock):''${RESET}"
                CURRENT_LETTER=""
                CURRENT_LINE=""
                while IFS= read -r pkg_name; do
                  FIRST_UPPER=$(echo "''${pkg_name:0:1}" | tr '[:lower:]' '[:upper:]')
                  if [[ "''${FIRST_UPPER}" != "''${CURRENT_LETTER}" ]]; then
                    [[ -n "''${CURRENT_LINE}" ]] && echo "  ''${GRAY}''${CURRENT_LINE}''${RESET}"
                    CURRENT_LINE="''${pkg_name}"
                    CURRENT_LETTER="''${FIRST_UPPER}"
                  else
                    CURRENT_LINE="''${CURRENT_LINE} ''${pkg_name}"
                  fi
                done < <(echo "''${OUTPUT}" | jq -r --argjson lock "''${NIXPKGS_LOCK}" --arg arch "''${ARCH}" '${pendingFilter}' | sort -f)
                [[ -n "''${CURRENT_LINE}" ]] && echo "  ''${GRAY}''${CURRENT_LINE}''${RESET}"
                echo
              fi
            '';
          };

        scriptCurrent = mkScript "hydra-check-current-release" config.nx.global.currentRelease;
        scriptNext = mkScript "hydra-check-next-release" nextRelease;
      in
      {
        home.packages = [ pkgs.hydra-check ];

        home.file."${dataHomeRel}/nx/home-packages.json".text = builtins.toJSON (
          collectPackageInventory config.nx.packages.ignore (config.home.packages ++ config.nx.packages.extra)
        );

        home.file."${defs.binDir}/hydra-check-current-release".source =
          "${scriptCurrent}/bin/hydra-check-current-release";
        home.file."${defs.binDir}/hydra-check-next-release".source =
          "${scriptNext}/bin/hydra-check-next-release";
      };
  };
}
