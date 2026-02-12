{ lib }:
{
  overlays = {
    inetutils = final: prev: {
      inetutils = prev.inetutils.overrideAttrs (oldAttrs: {
        env = (oldAttrs.env or { }) // {
          NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=format-security";
        };
      });
    };
  };
}
