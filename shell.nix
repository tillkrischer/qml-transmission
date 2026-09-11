{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    qt6.qtdeclarative
    qt6.qttools
  ];
}
