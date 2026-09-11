{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    cmake
    ninja
    pkg-config
    qt6.qtdeclarative
    qt6.qttools
    qt6Packages.qtkeychain
  ];
}
