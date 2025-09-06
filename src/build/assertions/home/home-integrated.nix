args@{
  lib,
  funcs,
  helpers,
  defs,
  user,
  host,
  ...
}:
{ config, ... }:

{
  assertions =
    [ ]
    ++ helpers.assertNotNull "user" user [
      "username"
      "fullname"
      "email"
      "home"
    ];
}
