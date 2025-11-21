args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "passwords";
  group = "mail-stack";
  input = "common";
  namespace = "home";

  settings = {
    service = "mail-stack";
  };

  custom = {
    mkPasswordCommand =
      accountKey: service:
      if self.isDarwin then
        "security find-generic-password -s ${service}-${accountKey} -w"
      else if self.isLinux then
        let
          desktopPreference = self.user.settings.desktopPreference;
        in
        if desktopPreference == "kde" then
          "kwalletcli -f Passwords -e ${service}-${accountKey}"
        else
          "secret-tool lookup service ${service}-${accountKey}"
      else
        throw "Unsupported platform for keyring authentication";
  };

  configuration =
    context@{ config, options, ... }:
    let
      desktopPreference = self.user.settings.desktopPreference;
      isKDE = desktopPreference == "kde";

      accountsConfig =
        if self.isModuleEnabled "mail-stack.accounts" then
          self.getModuleConfig "mail-stack.accounts"
        else
          { accounts = { }; };
      configuredAccountKeys = lib.attrNames accountsConfig.accounts;
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "mail-keyring-setup" ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [[ "$OSTYPE" == "darwin"* ]]; then
            KEYRING_TYPE="keychain"
            SETUP_CMD() {
              local service="$1"
              local account="$2"
              local password="$3"
              security add-generic-password -s "$service-$account" -a "$service" -w "$password" -U
            }
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              security find-generic-password -s "$service-$account" -w >/dev/null 2>&1
            }
          elif [[ "${if isKDE then "true" else "false"}" == "true" ]]; then
            KEYRING_TYPE="kwallet"
            SETUP_CMD() {
              local service="$1"
              local account="$2"
              local password="$3"
              local tmpfile=$(mktemp)
              chmod 600 "$tmpfile"
              echo "$password" > "$tmpfile"
              if kwalletcli -f "Passwords" -e "$service-$account" -P < "$tmpfile"; then
                rm -f "$tmpfile"
                return 0
              else
                rm -f "$tmpfile"
                return 1
              fi
            }
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              kwalletcli -f "Passwords" -e "$service-$account" >/dev/null 2>&1
            }
          else
            KEYRING_TYPE="gnome-keyring"
            SETUP_CMD() {
              local service="$1"
              local account="$2"
              local password="$3"
              local tmpfile=$(mktemp)
              chmod 600 "$tmpfile"
              echo "$password" > "$tmpfile"
              if secret-tool store --label="$service $account" service "$service-$account" < "$tmpfile"; then
                rm -f "$tmpfile"
                return 0
              else
                rm -f "$tmpfile"
                return 1
              fi
            }
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              secret-tool lookup service "$service-$account" >/dev/null 2>&1
            }
          fi

          echo "Mail Keyring Setup ($KEYRING_TYPE)"
          echo "================================="

          SERVICE="${self.settings.service}"
          CONFIGURED_ACCOUNTS=(${lib.escapeShellArgs configuredAccountKeys})

          if [[ $# -eq 0 ]]; then
            echo "Usage: $0 <account-key> [password]"
            echo ""
            if [[ ''${#CONFIGURED_ACCOUNTS[@]} -gt 0 ]]; then
              echo "Configured accounts:"
              for ACC in "''${CONFIGURED_ACCOUNTS[@]}"; do
                echo "  $ACC"
              done
            else
              echo "No accounts configured. Configure accounts in your profile first."
            fi
            exit 1
          fi

          ACCOUNT="$1"
          PASSWORD="''${2:-}"

          ACCOUNT_FOUND=false
          for CONFIGURED_ACCOUNT in "''${CONFIGURED_ACCOUNTS[@]}"; do
            if [[ "$ACCOUNT" == "$CONFIGURED_ACCOUNT" ]]; then
              ACCOUNT_FOUND=true
              break
            fi
          done

          if [[ "$ACCOUNT_FOUND" != "true" ]]; then
            echo "Error: Account '$ACCOUNT' not found in configuration."
            echo ""
            if [[ ''${#CONFIGURED_ACCOUNTS[@]} -gt 0 ]]; then
              echo "Available accounts:"
              for ACC in "''${CONFIGURED_ACCOUNTS[@]}"; do
                echo "  $ACC"
              done
            else
              echo "No accounts are configured."
            fi
            exit 1
          fi

          if [[ -z "$PASSWORD" ]]; then
            echo "Enter password for account '$ACCOUNT':"
            read -s PASSWORD
          fi

          if [[ -z "$PASSWORD" ]]; then
            echo "Error: Password cannot be empty"
            exit 1
          fi

          echo "Setting up keyring entry for account '$ACCOUNT'..."

          if SETUP_CMD "$SERVICE" "$ACCOUNT" "$PASSWORD"; then
            echo "Successfully stored password for account '$ACCOUNT' in $KEYRING_TYPE"
            echo

            if CHECK_CMD "$SERVICE" "$ACCOUNT"; then
              echo "Password retrieval test successful"
            else
              echo "Warning: Could not verify password retrieval"
            fi
          else
            echo "Failed to store password in $KEYRING_TYPE"
            exit 1
          fi

          echo "Password setup complete for account '$ACCOUNT'"
        '')

        (pkgs.writeShellScriptBin "mail-keyring-check-all" ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [[ "$OSTYPE" == "darwin"* ]]; then
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              security find-generic-password -s "$service-$account" -w >/dev/null 2>&1
            }
          elif [[ "${if isKDE then "true" else "false"}" == "true" ]]; then
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              kwalletcli -f "Passwords" -e "$service-$account" >/dev/null 2>&1
            }
          else
            CHECK_CMD() {
              local service="$1"
              local account="$2"
              secret-tool lookup service "$service-$account" >/dev/null 2>&1
            }
          fi

          echo "Mail Keyring Check (All Configured Accounts)"
          echo "============================================="

          SERVICE="${self.settings.service}"
          CONFIGURED_ACCOUNTS=(${lib.escapeShellArgs configuredAccountKeys})

          if [[ ''${#CONFIGURED_ACCOUNTS[@]} -eq 0 ]]; then
            echo "No mail accounts configured."
            echo "Configure accounts in your profile first."
            exit 0
          fi

          MISSING_PASSWORDS=()
          FOUND_PASSWORDS=()

          echo "Checking ''${#CONFIGURED_ACCOUNTS[@]} configured account(s)..."
          echo

          for ACCOUNT in "''${CONFIGURED_ACCOUNTS[@]}"; do
            echo -n "Checking account '$ACCOUNT'... "

            if CHECK_CMD "$SERVICE" "$ACCOUNT"; then
              echo "  Found"
              FOUND_PASSWORDS+=("$ACCOUNT")
            else
              echo "  Missing"
              MISSING_PASSWORDS+=("$ACCOUNT")
            fi
          done

          echo
          echo

          if [[ ''${#FOUND_PASSWORDS[@]} -gt 0 ]]; then
            echo "  Accounts with passwords: ''${FOUND_PASSWORDS[*]}"
          fi

          if [[ ''${#MISSING_PASSWORDS[@]} -gt 0 ]]; then
            echo "  Accounts missing passwords: ''${MISSING_PASSWORDS[*]}"
            echo
            echo "To set up missing passwords, run:"
            for MISSING in "''${MISSING_PASSWORDS[@]}"; do
              echo "  mail-keyring-setup $MISSING"
            done
            exit 1
          else
            echo
            echo "All configured accounts have passwords set up!"
            exit 0
          fi
        '')
      ]
      ++ lib.optionals (self.isLinux && isKDE) [
        pkgs.kdePackages.kwallet
      ]
      ++ lib.optionals (self.isLinux && !isKDE) [
        pkgs.gnome-keyring
      ];
    };
}
