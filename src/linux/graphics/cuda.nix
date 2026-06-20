args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "cuda";

  group = "graphics";
  input = "linux";

  unfree = [
    "cuda_cudart"
    "cuda_nvcc"
    "cuda_cccl"
    "libcublas"
  ];
}
