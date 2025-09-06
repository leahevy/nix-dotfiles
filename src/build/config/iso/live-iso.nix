{
  config,
  pkgs,
  lib,
  modulesPath,
  variables,
  nx-repositories,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    http-connections = variables.httpConnections;
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PermitEmptyPasswords = "no";
  };

  security.sudo.wheelNeedsPassword = false;

  environment.interactiveShellInit = ''
    if [ "$PWD" = "$HOME" ] && [ -d "/nxcore" ]; then
      cd /nxcore
    fi

    alias ll='ls -la'
    alias la='ls -la'
    alias nx='/nxcore/nx'

    if [ "$USER" = "nixos" ] && [ -z "$NX_STARTUP_CHECKED" ]; then
      export NX_STARTUP_CHECKED=1
      
      echo
      echo -e "\033[1;33mChecking NX Live setup status...\033[0m"
      echo
      
      TIMEOUT=15
      ELAPSED=0
      
      while [ $ELAPSED -lt $TIMEOUT ]; do
        SERVICES_READY=true

        for svc in nx-setup nx-network-available nx-git-config nx-nxcore-git-init nx-nxconfig-git-init; do
          if ! systemctl is-active --quiet $svc.service 2>/dev/null; then
            SERVICES_READY=false
            break
          fi
        done
        
        if [ "$SERVICES_READY" = "true" ]; then
          echo -e "\033[1;32mNX Live setup completed successfully!\033[0m"
          break
        fi

        sleep 1
        ELAPSED=$((ELAPSED + 1))
      done
      
      if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "\033[1;31m\033[1mWARNING: NX Live setup failed or timed out!\033[0m"
        echo
        echo -e "\033[1;31mService status:\033[0m"

        for svc in nx-setup nx-network-available nx-git-config nx-nxcore-git-init nx-nxconfig-git-init; do
          status=$(systemctl is-active $svc.service 2>/dev/null)

          if [ -z "$status" ]; then
            status="inactive"
          fi
          
          if [ "$status" = "active" ]; then
            echo -e "  \033[1;37m$svc\033[0m: \033[1;32m$status\033[0m"
          else
            echo -e "  \033[1;37m$svc\033[0m: \033[1;31m$status\033[0m"
          fi
        done
        echo
        echo -e "\033[1;33mRun 'systemctl status <service-name>' for details\033[0m"
      fi

      echo
      echo -e "\033[1;37mPress any key to continue....\033[0m"
      read -n1
    fi
  '';

  programs.bash.promptInit = ''
    if [ "$UID" = 0 ]; then
      PS1='\[\033[01;31m\][nx-live]\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \$ '
    else
      PS1='\[\033[01;32m\][nx-live]\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \$ '
    fi
  '';

  networking.networkmanager.enable = true;
  networking.wireless.enable = false;

  networking.useDHCP = lib.mkDefault true;

  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  networking.hostName = "nx-live";

  systemd.services.networkd-dispatcher.enable = false;

  environment.systemPackages = with pkgs; [
    git
    htop
    vim
    disko
    curl
    rsync
    wget
    tree
    jq
    sops
    age
    gnupg
    git-crypt
    wpa_supplicant
    iw
    dig
    iotop
    nethogs
    parted
    gptfdisk
    cryptsetup
    btrfs-progs
    lvm2
    lshw
    smartmontools
    pciutils
    usbutils
  ];

  systemd.services.nx-setup = {
    description = "Setup NX directories from packages";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.service" ];
    before = [
      "display-manager.service"
      "getty@tty1.service"
      "nx-git-init.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo "Setting up NX directories..."

      REPO_PKG="${nx-repositories}"

      if [ -d "$REPO_PKG/nxcore" ]; then
        echo "Found nx-repositories at: $REPO_PKG"
        
        mkdir -p /nxcore /nxconfig
        cp -r "$REPO_PKG/nxcore"/. /nxcore/
        cp -r "$REPO_PKG/nxconfig"/. /nxconfig/
        
        chmod -R u+w /nxcore /nxconfig
        chown -R nixos:users /nxcore /nxconfig
        
        echo "NX directories setup complete"
      else
        echo "Error: nx-repositories package not found at: $REPO_PKG"
        ls -la "$REPO_PKG" || echo "Path does not exist"
        exit 1
      fi
    '';
  };

  systemd.services.nx-network-available = {
    description = "Wait for network connectivity";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nixos";
      RemainAfterExit = true;
    };
    script = ''
      echo "Checking network connectivity..."
      RETRY_COUNT=0
      MAX_RETRIES=10
      NETWORK_OK=false

      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if ${pkgs.curl}/bin/curl -s --connect-timeout 5 --max-time 10 https://github.com >/dev/null 2>&1; then
          echo "Network connectivity established (attempt $((RETRY_COUNT + 1)))"
          NETWORK_OK=true
          break
        else
          echo "Network not ready, waiting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
          RETRY_COUNT=$((RETRY_COUNT + 1))
          sleep 3
        fi
      done

      if [ "$NETWORK_OK" != true ]; then
        echo "Warning: Could not establish network connectivity after $MAX_RETRIES attempts."
        exit 1
      fi

      echo "Network connectivity confirmed"
    '';
  };

  systemd.services.nx-git-config = {
    description = "Configure git globally for NX Live environment";
    wantedBy = [ "multi-user.target" ];
    after = [ "nx-setup.service" ];
    requires = [ "nx-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nixos";
      RemainAfterExit = true;
    };
    script = ''
      echo "Configuring git globally for live environment..."
      ${pkgs.git}/bin/git config --global user.name "NX Live User"
      ${pkgs.git}/bin/git config --global user.email "nx@live.local"
      ${pkgs.git}/bin/git config --global credential.helper "store"
      echo "Global git configuration complete"
    '';
  };

  systemd.services.nx-nxcore-git-init = {
    description = "Initialize nx git repository";
    wantedBy = [ "multi-user.target" ];
    after = [
      "nx-setup.service"
      "nx-git-config.service"
      "nx-network-available.service"
    ];
    requires = [
      "nx-setup.service"
      "nx-git-config.service"
      "nx-network-available.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "nixos";
      WorkingDirectory = "/nxcore";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -d .git ]; then
        echo "Initializing git repository for nxcore..."
        ${pkgs.git}/bin/git init
      else
        echo "Found existing git repository for nxcore"
      fi

      echo "Configuring remote origin for live environment..."
      if ${pkgs.git}/bin/git remote get-url origin >/dev/null 2>&1; then
        ${pkgs.git}/bin/git remote set-url origin "${variables.coreRepoIsoUrl}"
        echo "Updated existing remote origin to: ${variables.coreRepoIsoUrl}"
      else
        ${pkgs.git}/bin/git remote add origin "${variables.coreRepoIsoUrl}"
        echo "Added remote origin: ${variables.coreRepoIsoUrl}"
      fi

      echo "Attempting to fetch from remote repository..."
      if ${pkgs.git}/bin/git fetch origin main; then
        echo "Fetch successful, setting up main branch..."
        if ${pkgs.git}/bin/git rev-parse --verify main >/dev/null 2>&1; then
          echo "Local main branch exists, updating it..."
          ${pkgs.git}/bin/git checkout main
          ${pkgs.git}/bin/git reset --hard origin/main
        else
          echo "Creating main branch from remote..."
          ${pkgs.git}/bin/git checkout -b main
          ${pkgs.git}/bin/git reset --hard origin/main
        fi
        ${pkgs.git}/bin/git branch --set-upstream-to=origin/main main
        echo "Git repository configured successfully with latest main branch!"
      else
        echo "Error: Git fetch failed for nxcore repository."
        echo "This service requires network connectivity and valid repository access."
        exit 1
      fi
    '';
  };

  systemd.services.nx-nxconfig-git-init = {
    description = "Initialize nx config git repository";
    wantedBy = [ "multi-user.target" ];
    after = [
      "nx-setup.service"
      "nx-git-config.service"
      "nx-network-available.service"
    ];
    requires = [
      "nx-setup.service"
      "nx-git-config.service"
      "nx-network-available.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "nixos";
      WorkingDirectory = "/nxconfig";
      RemainAfterExit = true;
    };
    script = ''
      if [ -n "${variables.configRepoIsoUrl}" ] && [ "${variables.configRepoIsoUrl}" != "" ]; then
        if [ ! -d .git ]; then
          echo "Initializing git repository for nxconfig..."
          ${pkgs.git}/bin/git init
        else
          echo "Found existing git repository for nxconfig"
        fi
        
        echo "Configuring remote origin for live environment..."
        if ${pkgs.git}/bin/git remote get-url origin >/dev/null 2>&1; then
          ${pkgs.git}/bin/git remote set-url origin "${variables.configRepoIsoUrl}"
          echo "Updated existing remote origin to: ${variables.configRepoIsoUrl}"
        else
          ${pkgs.git}/bin/git remote add origin "${variables.configRepoIsoUrl}"
          echo "Added remote origin: ${variables.configRepoIsoUrl}"
        fi
        
        echo "Attempting to fetch from remote repository..."
        if ${pkgs.git}/bin/git fetch origin main; then
          echo "Config git repository configured successfully with latest main branch!"
        else
          echo "Error: Git fetch failed for nxconfig repository."
          echo "This service requires network connectivity and valid repository access."
          echo "Exiting with 0 as repository can be manually fetched with bootstrap script: 00-fetch-latest-config.sh"
          exit 0
        fi
      else
        echo "No configRepoIsoUrl configured, skipping config git initialization"
      fi
    '';
  };

  system.stateVersion = variables.state-version;
}
