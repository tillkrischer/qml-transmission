{ lib, stdenv, cmake, ninja, qt6, qt6Packages, makeDesktopItem }:

stdenv.mkDerivation {
  pname = "qml-transmission";
  version = "0.2.0";

  src = lib.cleanSourceWith {
    src = lib.cleanSource ./.;
    filter = path: type:
      let name = baseNameOf path;
      in !(lib.hasPrefix "build" name || name == "result" || name == ".direnv");
  };

  nativeBuildInputs = [ cmake ninja qt6.wrapQtAppsHook ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
    qt6Packages.qtkeychain
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    QT_QPA_PLATFORM=offscreen ctest --output-on-failure
    export XDG_CACHE_HOME="$TMPDIR/cache"
    makeQtWrapper ${qt6.qtdeclarative}/bin/qmltestrunner "$TMPDIR/qmltestrunner"
    QT_QPA_PLATFORM=offscreen "$TMPDIR/qmltestrunner" -input ../tests
    runHook postCheck
  '';

  postInstall = ''
    mkdir -p "$out/share/applications"
    cp ${makeDesktopItem {
      name = "qml-transmission";
      desktopName = "QML Transmission";
      comment = "Manage a remote Transmission server";
      exec = "qml-transmission";
      icon = "transmission";
      categories = [ "Network" "FileTransfer" ];
      terminal = false;
    }}/share/applications/* "$out/share/applications/"
  '';

  meta = {
    description = "Qt Quick desktop client for a remote Transmission daemon";
    mainProgram = "qml-transmission";
    platforms = lib.platforms.linux;
  };
}
