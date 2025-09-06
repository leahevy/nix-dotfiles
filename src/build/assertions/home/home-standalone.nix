args@{
  lib,
  funcs,
  helpers,
  defs,
  user,
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
