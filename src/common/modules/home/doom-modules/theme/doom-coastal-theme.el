;;; doom-coastal-theme.el --- A dark coastal theme -*- lexical-binding: t; no-byte-compile: t; -*-

(require 'doom-themes)

(defgroup doom-coastal-theme nil
  "Options for the `doom-coastal' theme."
  :group 'doom-themes)

(defcustom doom-coastal-brighter-modeline nil
  "If non-nil, more vivid colors will be used to style the mode-line."
  :group 'doom-coastal-theme
  :type 'boolean)

(defcustom doom-coastal-brighter-comments nil
  "If non-nil, comments will be highlighted in more vivid colors."
  :group 'doom-coastal-theme
  :type 'boolean)

(def-doom-theme doom-coastal
  "A dark coastal theme"

  ;; name        default   256         16
  ((bg         '("#131513" "unspecified-bg" "unspecified-bg"))
   (bg-alt     '("#242924" "unspecified-bg" "unspecified-bg"))
   (base0      '("#131513" "unspecified-bg" "unspecified-bg"))
   (base1      '("#242924" "unspecified-bg" "unspecified-bg"))
   (base2      '("#5e6e5e" "#000000"   "brightblack"  ))
   (base3      '("#687d68" "#000000"   "brightblack"  ))
   (base4      '("#809980" "#000000"   "brightblack"  ))
   (base5      '("#8ca68c" "#000000"   "brightblack"  ))
   (base6      '("#cfe8cf" "#6b6b6b"   "brightblack"  ))
   (base7      '("#f4fbf4" "#979797"   "brightblack"  ))
   (base8      '("#f4fbf4" "#dfdfdf"   "white"        ))
   (fg         '("#8ca68c" "#bfbfbf"   "brightwhite"  ))
   (fg-alt     '("#cfe8cf" "#2d2d2d"   "white"        ))

   (grey       base4)
   (red        '("#e6193c" "#e6193c"   "red"          ))
   (orange     '("#87711d" "#87711d"   "brightred"    ))
   (green      '("#29a329" "#29a329"   "green"        ))
   (teal       '("#1999b3" "#1999b3"   "brightgreen"  ))
   (yellow     '("#98981b" "#98981b"   "yellow"       ))
   (blue       '("#3d62f5" "#3d62f5"   "brightblue"   ))
   (dark-blue  '("#1999b3" "#1999b3"   "blue"         ))
   (magenta    '("#ad2bee" "#ad2bee"   "brightmagenta"))
   (violet     '("#ad2bee" "#ad2bee"   "magenta"      ))
   (cyan       '("#1999b3" "#1999b3"   "brightcyan"   ))
   (dark-cyan  '("#087e96" "#087e96"   "cyan"         ))

   (bg-special     '("#242924" "unspecified-bg" "unspecified-bg"))
   (fg-special     '("#f4fbf4" "#f4fbf4" "brightwhite"))
   (fg-alt-special '("#cfe8cf" "#cfe8cf" "white"))

   (base0-special  '("#0d110d" "unspecified-bg" "unspecified-bg"))
   (base8-special  '("#ffffff" "#ffffff" "brightwhite"))

   (highlight      green)
   (vertical-bar   (doom-darken base1 0.1))
   (selection      dark-blue)
   (builtin        cyan)
   (comments       (if doom-coastal-brighter-comments dark-cyan base5))
   (doc-comments   (doom-lighten (if doom-coastal-brighter-comments dark-cyan base5) 0.25))
   (constants      teal)
   (functions      cyan)
   (keywords       green)
   (methods        teal)
   (operators      cyan)
   (type           yellow)
   (strings        green)
   (variables      (doom-lighten green 0.4))
   (numbers        orange)
   (region         `("#2a4d33" "#2a4d33" "green"))
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   (hidden     `(,(car bg) "black" "black"))
   (-modeline-bright doom-coastal-brighter-modeline)
   (-modeline-pad
    (when doom-coastal-brighter-modeline 4))

   (modeline-fg     fg)
   (modeline-fg-alt base5)

   (modeline-bg
    (if -modeline-bright
        (doom-darken blue 0.475)
      `(,(doom-darken (car bg-alt) 0.15) ,@(cdr base0))))
   (modeline-bg-alt
    (if -modeline-bright
        (doom-darken blue 0.45)
      `(,(doom-darken (car bg-alt) 0.1) ,@(cdr base0))))
   (modeline-bg-inactive   `(,(doom-darken (car bg-alt) 0.1) ,@(cdr bg-alt)))
   (modeline-bg-inactive-alt `(,(car bg-alt) ,@(cdr base1))))

  (((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground fg)
   ((font-lock-comment-face &override)
    :background (if doom-coastal-brighter-comments (doom-lighten bg 0.05)))
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground (if -modeline-bright base8 highlight))

   (css-proprietary-property :foreground orange)
   (css-property             :foreground green)
   (css-selector             :foreground blue)
   (doom-modeline-bar :background (if -modeline-bright modeline-bg highlight))
   (doom-modeline-buffer-file :inherit 'mode-line-buffer-id :weight 'bold)
   (doom-modeline-buffer-path :inherit 'mode-line-emphasis :weight 'bold)
   (doom-modeline-buffer-project-root :foreground green :weight 'bold)
   (elscreen-tab-other-screen-face :background "#353a42" :foreground "#1e2022")
   (ivy-current-match :background dark-blue :distant-foreground base0 :weight 'normal)
   (font-latex-math-face :foreground green)
   (markdown-markup-face :foreground base5)
   (markdown-header-face :inherit 'bold :foreground red)
   (markdown-code-face :background (doom-lighten base3 0.05))
   (rjsx-tag :foreground red)
   (rjsx-attr :foreground orange)
   (solaire-mode-line-face
    :inherit 'mode-line
    :background modeline-bg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-alt)))
   (solaire-mode-line-inactive-face
    :inherit 'mode-line-inactive
    :background modeline-bg-inactive-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive-alt)))
   ;;;; doom-dashboard
   (doom-dashboard-banner :inherit 'default :foreground green)
   (doom-dashboard-footer :inherit 'default)
   (doom-dashboard-footer-icon :inherit 'default)
   (doom-dashboard-loaded :inherit 'default)
   (doom-dashboard-menu-desc :inherit 'default)
   (doom-dashboard-menu-title :inherit 'default :foreground green :weight 'bold)))

;;; doom-coastal-theme.el ends here