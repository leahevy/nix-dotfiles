# NixOS Upgrade to next release

## Prerequisites

- [ ] Run `nx check --next-release` to check which packages have not yet been built on the target channel. Repeat periodically and wait for a good build ratio before proceeding.
- [ ] Ensure clean git state (all changes committed or stashed)

## Upgrade Steps

- [ ] 1. Run `nx switch-branch upgrade-nixos-<TARGET_VERSION>`
- [ ] 2. Run `nx dist-upgrade <TARGET_VERSION>` (requires clean git repo)
- [ ] 3. Read the release notes and apply any nxcore breaking-change fixes: https://nixos.org/manual/nixos/stable/release-notes#sec-release-<TARGET_VERSION>
- [ ] 4. Baseline checkpoint: verify eval succeeds and `nx build --keep` passes - do not proceed until clean
- [ ] 5. Update flake inputs not covered by automatic updates:
    - [ ] 5a. Forked inputs (sync the fork with upstream, verify no conflicts): **sops-nix**, **disko**, **impermanence**, **lanzaboote**, **nixos-anywhere**, **niri-flake** (also merge main into nx-patches branch), **nixos-hardware**
        - [ ] 5a-i. For tag-pinned forks, also bump the version tag in `flake.nix` (auto-update cannot move an immutable tag)
    - [ ] 5b. Third-party inputs (review diffs for breaking changes): **mac-app-util**, **nixpkgs-mac-app-util**, **nix-plist-manager**
    - [ ] 5c. Rolling-tag inputs (bump the tag in `flake.nix` after checking the upstream source for the current tag): **nixos-raspberrypi**
- [ ] 6. Consider removing packages specified as unstable in both `variables.nix` files
    - [ ] 6a. Clear temporarilyAllowedInsecurePackages` in `variables.nix` (packages only listed there because nixpkgs EOL'd them mid-release cycle; the new release should ship non-EOL replacements)
- [ ] 7. Fix evaluation warnings until configuration builds without warnings (use `NIX_ABORT_ON_WARN=true` with build command to find warning sources)
- [ ] 8. Final guard: eval succeeds and `nx build --diff` to see the changes
- [ ] 9. Commit everything with `nx commit`
- [ ] 10. Create pre-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 11. Boot into the new config via `nx boot` and `reboot`

## Post-Reboot

- [ ] 12. Check for service failures: `systemctl --failed` and `systemctl --user --failed`
- [ ] 13. Verify the new kernel is running: `uname -r`
- [ ] 14. Test that the new config can build our nx configuration: `nx sync`
- [ ] 15. Create post-boot impermanence logs with `nx impermanence check --home` and `nx impermanence check --system`
- [ ] 16. Check impermanence diffs with `nx impermanence diff --home` and `nx impermanence diff --system`
- [ ] 17. Search for `buildVimPlugin` in the repository to check if any should be replaced with:
    - [ ] 17a. packages that arrived in nixpkgs as `vimPlugins.*` at same or later version
    - [ ] 17b. supported nixvim plugins, e.g. `programs.nixvim.plugins.*`
- [ ] 18. Search for `fetchFromGitHub` in the repository to check if any derivations did arrive in `nixpkgs`
    - [ ] 18a. Bump the pinned GeoIP commit in `src/linux/networking/geo-ip.nix`: first sync the fork at https://github.com/leahevy/country-ip-blocks with upstream (ipverse/country-ip-blocks), then pick a recent commit and get its hash with `nix flake prefetch "github:leahevy/country-ip-blocks/COMMIT" --json 2>/dev/null | grep '"hash"'`
- [ ] 19. Push the feature branches: `nx push`
- [ ] 20. Change back to the **main** branch: `nx switch-branch main`
- [ ] 21. Tag main branch before the upgrade `git tag -a nixos-<TARGET_VERSION>-pre-upgrade -m "NixOS <OLD_VERSION> before upgrading to <TARGET_VERSION>"` and push with `git push --tags`
- [ ] 22. Merge the feature branches into main
- [ ] 23. Delete the upgrade feature branches locally and on remote (run in both nxcore and nxconfig): `git branch -d upgrade-nixos-<TARGET_VERSION>` and `git push origin --delete upgrade-nixos-<TARGET_VERSION>`
- [ ] 24. Push main branch: `nx push`
- [ ] 25. Tag with `git tag -a nixos-<TARGET_VERSION> -m "NixOS <TARGET_VERSION>"` and push with `git push --tags`
