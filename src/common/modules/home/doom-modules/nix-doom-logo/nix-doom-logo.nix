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
  name = "nix-doom-logo";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/config/20-nix-doom-logo.el".text = ''
        (defun my-main-menu-banner ()
          "Insert Nix snowflake logo ASCII art."
          (let* ((banner '(""
                           ""
                           "       ◢██◣   ◥███◣  ◢██◣"
                           "       ◥███◣   ◥███◣◢███◤"
                           "        ◥███◣   ◥██████◤"
                           "    ◢█████████████████◤   ◢◣"
                           "   ◢██████████████████◣  ◢██◣"
                           "        ◢███◤      ◥███◣◢███◤"
                           "       ◢███◤        ◥██████◤"
                           "◢█████████◤          ◥█████████◣"
                           "◥█████████◣          ◢█████████◤"
                           "    ◢██████◣        ◢███◤"
                           "   ◢███◤◥███◣      ◢███◤"
                           "   ◥██◤  ◥██████████████████◤"
                           "    ◥◤   ◢█████████████████◤"
                           "        ◢██████◣   ◥███◣"
                           "       ◢███◤◥███◣   ◥███◣"
                           "       ◥██◤  ◥███◣   ◥██◤"
        		   ""))
                 (longest-line (apply #'max (mapcar #'length banner))))
            (dolist (line banner)
              (insert (+doom-dashboard--center
                       +doom-dashboard--width
                       (propertize (concat line (make-string (max 0 (- longest-line (length line))) 32))
                                  'face 'doom-dashboard-menu-title))
                      "\n"))
            (insert "\n")))

        (setq +doom-dashboard-ascii-banner-fn #'my-main-menu-banner)
      '';
    };
}
