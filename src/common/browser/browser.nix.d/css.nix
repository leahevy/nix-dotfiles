{
  lib,
  css,
  colors,
  options,
}:
{
  result =
    css
    + lib.optionalString options.forceBlackCSSOverwrite ''
      :root {
        color-scheme: dark !important;

        --background: ${colors.main.backgrounds.primary.html} !important;
        --background-color: ${colors.main.backgrounds.primary.html} !important;
        --bg: ${colors.main.backgrounds.primary.html} !important;
        --bg-color: ${colors.main.backgrounds.primary.html} !important;
        --page-bg: ${colors.main.backgrounds.primary.html} !important;
        --body-bg: ${colors.main.backgrounds.primary.html} !important;
        --app-bg: ${colors.main.backgrounds.primary.html} !important;

        --surface: ${colors.main.backgrounds.primary.html} !important;
        --surface-color: ${colors.main.backgrounds.primary.html} !important;
        --card-bg: ${colors.main.backgrounds.primary.html} !important;
        --panel-bg: ${colors.main.backgrounds.primary.html} !important;
        --container-bg: ${colors.main.backgrounds.primary.html} !important;

        --border: ${colors.main.foregrounds.subtle.html} !important;
        --border-color: ${colors.main.foregrounds.subtle.html} !important;
        --input-border: ${colors.main.foregrounds.subtle.html} !important;

        --card: ${colors.main.backgrounds.primary.html} !important;
        --popover: ${colors.main.backgrounds.primary.html} !important;
        --muted: ${colors.main.backgrounds.primary.html} !important;

        --foreground: ${colors.main.foregrounds.strong.html} !important;
        --card-foreground: ${colors.main.foregrounds.strong.html} !important;
        --popover-foreground: ${colors.main.foregrounds.strong.html} !important;
        --muted-foreground: ${colors.main.foregrounds.secondary.html} !important;

        --ds-surface: ${colors.main.backgrounds.primary.html} !important;
        --ds-surface-raised: ${colors.main.backgrounds.primary.html} !important;
        --ds-surface-overlay: ${colors.main.backgrounds.primary.html} !important;
        --ds-surface-sunken: ${colors.main.backgrounds.primary.html} !important;

        --ds-background-neutral: ${colors.main.backgrounds.primary.html} !important;
        --ds-background-neutral-subtle: ${colors.main.backgrounds.primary.html} !important;
        --ds-background-input: ${colors.main.backgrounds.primary.html} !important;
        --ds-background-selected: ${colors.main.backgrounds.primary.html} !important;

        --ds-border: ${colors.main.foregrounds.subtle.html} !important;
        --ds-border-input: ${colors.main.foregrounds.subtle.html} !important;
        --ds-text: ${colors.main.foregrounds.strong.html} !important;
        --ds-text-subtle: ${colors.main.foregrounds.secondary.html} !important;

        --gl-background-color-default: ${colors.main.backgrounds.primary.html} !important;
        --gl-background-color-subtle: ${colors.main.backgrounds.primary.html} !important;
        --gl-background-color-strong: ${colors.main.backgrounds.primary.html} !important;
        --gl-background-color-overlap: ${colors.main.backgrounds.primary.html} !important;
        --gl-background-color-section: ${colors.main.backgrounds.primary.html} !important;
        --gl-background-color-disabled: ${colors.main.backgrounds.primary.html} !important;

        --gl-color-neutral-0: ${colors.main.backgrounds.primary.html} !important;
        --gl-color-neutral-10: ${colors.main.backgrounds.primary.html} !important;
        --gl-color-neutral-50: ${colors.main.backgrounds.primary.html} !important;
        --gl-color-neutral-100: ${colors.main.backgrounds.primary.html} !important;

        --gl-text-color-default: ${colors.main.foregrounds.strong.html} !important;
        --gl-text-color-subtle: ${colors.main.foregrounds.secondary.html} !important;
        --gl-text-color-strong: ${colors.main.foregrounds.strong.html} !important;

        --gl-border-color-default: ${colors.main.foregrounds.subtle.html} !important;
        --gl-border-color-subtle: ${colors.main.foregrounds.subtle.html} !important;
      }

      html,
      body,
      #root,
      #app,
      #__next,
      #__nuxt,
      [role="main"],
      main,
      dialog {
        background-color: ${colors.main.backgrounds.primary.html} !important;
      }

      .app,
      .page,
      .site,
      .layout,
      .shell,
      .wrapper,
      .container,
      .panel,
      .card,
      .box,
      .Box,
      .tile,
      .modal,
      .popover,
      .dropdown,
      .menu,
      .drawer,
      .sidebar {
        background-color: ${colors.main.backgrounds.primary.html} !important;
      }

      [class~="bg-white"],
      [class~="bg-gray-50"],
      [class~="bg-gray-100"],
      [class~="bg-neutral-50"],
      [class~="bg-neutral-100"],
      [class~="bg-slate-50"],
      [class~="bg-slate-100"],
      [class~="bg-zinc-50"],
      [class~="bg-zinc-100"],
      [class~="bg-stone-50"],
      [class~="bg-stone-100"],
      [class*="bg-[#" i],
      [class*="bg-[" i],
      [class*="panel" i],
      [class*="cardui" i],
      [class*="surface" i],
      [class*="background" i],
      [class*="shell" i],
      [class*="wrapper" i],
      [class*="layout" i] {
        background-color: ${colors.main.backgrounds.primary.html} !important;
      }

      [class~="base"],
      [class*="-base" i],
      [class^="base-" i],
      [class*=" base-" i] {
        color: ${colors.main.foregrounds.primary.html} !important;
        background-color: ${colors.main.backgrounds.primary.html} !important;
      }

      .border,
      .border-border,
      [class~="border"] {
        border-color: ${colors.main.foregrounds.subtle.html} !important;
      }

      .text-primary,
      .text-foreground {
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .text-muted-foreground {
        color: ${colors.main.foregrounds.secondary.html} !important;
      }

      form[role="search"],
      [role="search"],
      form:has(input[type="search"]),
      form:has(input[name="q"]),
      div:has(> input[type="search"]),
      div:has(> input[name="q"]),
      label:has(input[type="search"]),
      label:has(input[name="q"]) {
        background-color: ${colors.main.backgrounds.primary.html} !important;
      }

      input:not(:hover):not(:focus):not(:active):not(:disabled),
      textarea:not(:hover):not(:focus):not(:active):not(:disabled),
      select:not(:hover):not(:focus):not(:active):not(:disabled),
      [contenteditable="true"]:not(:hover):not(:focus):not(:active),
      [role="textbox"]:not(:hover):not(:focus):not(:active),
      [role="combobox"]:not(:hover):not(:focus):not(:active),
      [role="searchbox"]:not(:hover):not(:focus):not(:active),
      [type="search"]:not(:hover):not(:focus):not(:active) {
        background-color: ${colors.main.backgrounds.primary.html} !important;
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      input::placeholder,
      textarea::placeholder {
        color: ${colors.main.foregrounds.subtle.html} !important;
        opacity: 1 !important;
      }

      .gl-new-dropdown-panel,
      .gl-new-dropdown-inner,
      .gl-new-dropdown-contents,
      .gl-new-dropdown-container,
      .gl-new-dropdown-item,
      .gl-new-dropdown-item-content,
      .gl-button-group,
      .home-panel,
      .home-panel-title-row,
      .home-panel-buttons,
      .gl-bg-default,
      .gl-bg-subtle,
      .gl-bg-strong,
      .gl-bg-disabled,
      .gl-bg-overlap,
      .gl-bg-section,
      .gl-bg-neutral-0,
      .gl-bg-neutral-10,
      .gl-bg-neutral-50,
      .gl-bg-neutral-100,
      [class*="gl-bg-" i],
      [class*="gl-new-dropdown" i],
      [class*="gl-card" i],
      [class*="gl-panel" i],
      [class*="gl-container" i],
      [class^="gl-"][class*="bg-" i],
      [class*=" gl-"][class*="bg-" i],
      [class^="gl-"][class*="container" i],
      [class*=" gl-"][class*="container" i],
      [class^="gl-"][class*="wrapper" i],
      [class*=" gl-"][class*="wrapper" i],
      [class^="gl-"][class*="surface" i],
      [class*=" gl-"][class*="surface" i],
      [class^="gl-"][class*="panel" i],
      [class*=" gl-"][class*="panel" i],
      [class^="gl-"][class*="card" i],
      [class*=" gl-"][class*="card" i],
      [class^="gl-"][class*="dropdown" i],
      [class*=" gl-"][class*="dropdown" i],
      [class^="gl-"][class*="drawer" i],
      [class*=" gl-"][class*="drawer" i],
      [class^="gl-"][class*="popover" i],
      [class*=" gl-"][class*="popover" i] {
        background-color: ${colors.main.backgrounds.primary.html} !important;
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .gl-text-subtle,
      .gl-text-secondary,
      .gl-new-dropdown-item-text-wrapper {
        color: ${colors.main.foregrounds.secondary.html} !important;
      }

      .gl-border-t-dropdown-divider,
      .gl-border,
      .gl-border-t,
      .gl-border-b,
      .gl-border-l,
      .gl-border-r,
      [class*="gl-border" i] {
        border-color: ${colors.main.foregrounds.subtle.html} !important;
      }

      .gl-button,
      .btn-default,
      .btn-default-tertiary {
        background-color: ${colors.main.backgrounds.primary.html} !important;
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .super-topbar,
      .js-super-topbar,
      header.super-topbar,
      header.js-super-topbar,
      .page-with-super-sidebar > .super-topbar,
      .page-with-super-sidebar > .js-super-topbar {
        background-color: ${colors.main.backgrounds.primary.html} !important;
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .super-topbar *,
      .js-super-topbar * {
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .super-topbar .gl-button,
      .super-topbar .btn,
      .super-topbar .btn-default,
      .super-topbar .gl-new-dropdown,
      .super-topbar .gl-new-dropdown-toggle,
      .super-topbar .gl-new-dropdown-panel,
      .super-topbar .gl-new-dropdown-inner,
      .super-topbar .gl-new-dropdown-contents,
      .super-topbar input,
      .super-topbar [role="search"],
      .super-topbar [role="combobox"],
      .super-topbar [role="textbox"],
      .js-super-topbar .gl-button,
      .js-super-topbar .btn,
      .js-super-topbar .btn-default,
      .js-super-topbar .gl-new-dropdown,
      .js-super-topbar .gl-new-dropdown-toggle,
      .js-super-topbar .gl-new-dropdown-panel,
      .js-super-topbar .gl-new-dropdown-inner,
      .js-super-topbar .gl-new-dropdown-contents,
      .js-super-topbar input,
      .js-super-topbar [role="search"],
      .js-super-topbar [role="combobox"],
      .js-super-topbar [role="textbox"] {
        background-color: ${colors.main.backgrounds.primary.html} !important;
        color: ${colors.main.foregrounds.strong.html} !important;
      }

      .super-topbar,
      .super-topbar *,
      .js-super-topbar,
      .js-super-topbar * {
        border-color: ${colors.main.foregrounds.subtle.html} !important;
      }

      img,
      picture,
      source,
      video,
      canvas,
      svg,
      [class*="image" i],
      [class*="img" i],
      [id*="image" i],
      [id*="img" i],
      [style*="background-image"] {
        background-color: transparent !important;
        filter: none !important;
        opacity: 1 !important;
        visibility: visible !important;
      }
    ''
    + lib.optionalString (options.forceSquareCSSMode == "normal") ''
      input,
      textarea,
      select,
      button,
      [type="button"],
      [type="submit"],
      [type="reset"],
      [type="search"],
      [type="file"]::file-selector-button,
      [role="button"],
      .btn,
      .button,
      .Button,
      .label,
      .Label,
      .badge,
      .Badge,
      .pill,
      .Pill,
      .topic-tag,
      .pagination a,
      .pagination span,
      .subnav-item,
      .tabnav-tab {
        border-radius: 0 !important;
      }
    ''
    + lib.optionalString (options.forceSquareCSSMode == "strict") ''
      *,
      *::before,
      *::after {
        border-radius: 0 !important;
      }
    '';
}
