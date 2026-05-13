# NixOS Upgrade Guide

## Prerequisites

- [ ] Ensure clean git state (all changes committed or stashed)

## Upgrade Steps

- [ ] 1. Run `nx switch-branch upgrade-nixos-<TARGET_VERSION>`, e.g. `25.11` as `<TARGET_VERSION>`
- [ ] 2. Run `nx dist-upgrade <TARGET_VERSION>` (requires clean git repo)
- [ ] 3. Update flake inputs not covered by automatic updates:
    - [ ] 3a. Forked inputs (sync with upstream, verify no conflicts): **sops-nix**, **disko**, **impermanence**, **lanzaboote**, **niri-flake**, **nixos-hardware**
    - [ ] 3b. Third-party inputs (review diffs for breaking changes): **mac-app-util**, **nix-plist-manager**
- [ ] 4. Search for `buildVimPlugin` in the repository to check if any should be replaced with:
    - [ ] 4a. packages that arrived in nixpkgs as `vimPlugins.*` at same or later version
    - [ ] 4b. supported nixvim plugins, e.g. `programs.nixvim.plugins.*`
- [ ] 5. Search for `fetchFromGitHub` in the repository to check if any derivations did arrive in `nixpkgs`
- [ ] 6. Consider removing packages specified as unstable in both `variables.nix` files
    - [ ] 6a. Verify `pythonName` in `nxcore/variables.nix` reflects the default Python version for this NixOS release and update if needed
- [ ] 7. Fix evaluation warnings until configuration builds without warnings (use `NIX_ABORT_ON_WARN=true` with build command to find warning sources)
- [ ] 8. Build with `nx build --diff` to see the changes
- [ ] 9. Commit everything with `nx commit`
- [ ] 10. Create pre-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 11. Boot into the new config via `nx boot` and `reboot`

## Post-Reboot Verification

- [ ] 12. Check for service failures: `systemctl --failed` and `systemctl --user --failed`
- [ ] 13. Test that the new config can build our nx configuration: `nx sync`
- [ ] 14. Create post-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 15. Check impermanence diffs with `nx impermanence diff --home` and `nx impermanence diff --system`
- [ ] 16. Push the feature branches: `nx push`
- [ ] 17. Change back to the **main** branch: `nx switch-branch main`
- [ ] 18. Tag main branch before the upgrade `git tag -a nixos-<TARGET_VERSION>-pre-upgrade -m "NixOS <OLD_VERSION> before upgrading to <TARGET_VERSION>"` and push with `git push --tags`
- [ ] 19. Merge the feature branches into main
- [ ] 20. Push main branch: `nx push`
- [ ] 21. Tag with `git tag -a nixos-<TARGET_VERSION> -m "NixOS <TARGET_VERSION>"` and push with `git push --tags`
