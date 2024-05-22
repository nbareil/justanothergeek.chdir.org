# nixos-21.11 on 2022-01-14 - https://status.nixos.org/
with (import (fetchTarball https://github.com/nixos/nixpkgs/archive/386234e2a61e1e8acf94dfa3a3d3ca19a6776efb.tar.gz) {});


let
  customPython = pkgs.python38.buildEnv.override {
  };
in
pkgs.mkShell {
  buildInputs = [
        pkgs.pre-commit
        pkgs.hugo
        pkgs.codespell
        pkgs.pre-commit
  ];
}
