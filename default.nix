# nixos-unstable on 2025-02-16 - https://status.nixos.org/
with (import (fetchTarball https://github.com/nixos/nixpkgs/archive/8bb37161a0488b89830168b81c48aed11569cb93.tar.gz) {});


let
in
pkgs.mkShell {
  buildInputs = [
        pkgs.pre-commit
        pkgs.hugo
        pkgs.codespell
        pkgs.pre-commit
  ];
}
