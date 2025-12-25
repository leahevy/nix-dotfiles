# NixOS Upgrade Guide

## Prerequisites

- [ ] Ensure clean git state (all changes committed or stashed)

## Upgrade Steps

- [ ] 1. Run `nx switch-branch upgrade-nixos-<TARGET_VERSION>`, e.g. `25.11` as `<TARGET_VERSION>`
- [ ] 2. Run `nx dist-upgrade <TARGET_VERSION>` (requires clean git repo)
- [ ] 3. Verify if critical flake inputs should be updated via `nx update <INPUT>`: **sops-nix**, **disko**, **nixos-hardware**, **impermanence**, **lanzaboote**, **niri-flake**, **mac-app-util**, **nix-plist-manager**
- [ ] 4. Search for `buildVimPlugin` in the repository to check if any should be replaced with:
    - [ ] 4a. packages that arrived in nixpkgs as `vimPlugins.*` at same or later version
    - [ ] 4b. supported nixvim plugins, e.g. `programs.nixvim.plugins.*`
- [ ] 5. Search for `fetchFromGitHub` in the repository to check if any derivations did arrive in `nixpkgs`
- [ ] 6. Fix evaluation warnings until configuration builds without warnings (use `NIX_ABORT_ON_WARN=true` with build command to find warning sources)
- [ ] 7. Build with `nx build --diff` to see the changes
- [ ] 8. Commit everything with `nx commit`
- [ ] 9. Create pre-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 10. Boot into the new config via `nx boot` and `reboot`

## Post-Reboot Verification

- [ ] 11. Check for service failures: `systemctl --failed` and `systemctl --user --failed`
- [ ] 12. Test that the new config can build our nx configuration: `nx sync`
- [ ] 13. Create post-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 14. Check impermanence diffs with `nx impermanence diff --home` and `nx impermanence diff --system`
- [ ] 15. Push the feature branches: `nx push`
- [ ] 16. Change back to the **main** branch: `nx switch-branch main`
- [ ] 17. Merge the feature branches into main
- [ ] 18. Push main branch: `nx push`
