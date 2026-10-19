# Solo, repackaged from the Linux release that soloterm.com publishes.
#
# The AppImage's own binaries are relinked against nixpkgs' WebKitGTK and GTK
# instead of running the Ubuntu libraries it bundles. Solo runs natively, with
# no FHS sandbox, so setuid tools such as sudo keep working in its terminals,
# and the mcp and solo CLI helpers run from any shell.
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  wrapGAppsHook3,
  cairo,
  fontconfig,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  libayatana-appindicator,
  librsvg,
  libsoup_3,
  openssl,
  wayland,
  webkitgtk_4_1,
  xdg-utils,
}:

let
  # Written by update.sh from soloterm.com's update manifest.
  source = lib.importJSON ./source.json;

  extracted = appimageTools.extract {
    pname = "solo";
    inherit (source) version;
    src = fetchurl {
      inherit (source) url hash;
    };
  };
in
stdenv.mkDerivation {
  pname = "solo";
  inherit (source) version;
  src = extracted;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    fontconfig
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    librsvg
    libsoup_3
    openssl
    stdenv.cc.cc.lib
    wayland
    webkitgtk_4_1
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  # Only the app needs the GTK environment; mcp and the CLI stay plain binaries.
  dontWrapGApps = true;

  # Solo looks for the mcp helper next to its own executable and for its
  # resources in ../lib/Solo, the same layout as its Debian package.
  installPhase = ''
    runHook preInstall
    install -Dm755 usr/bin/Solo $out/bin/Solo
    install -Dm755 usr/bin/mcp $out/bin/mcp
    install -Dm755 usr/bin/solo-cli $out/bin/solo
    mkdir -p $out/lib $out/share
    cp -r usr/lib/Solo $out/lib/Solo
    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/Solo.desktop $out/share/applications/Solo.desktop
    runHook postInstall
  '';

  # The tray icon library is loaded at runtime, so autoPatchelf cannot see it.
  postFixup = ''
    wrapGApp $out/bin/Solo \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]} \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  passthru = {
    inherit source;
  };

  meta = {
    description = "Run and supervise dev processes and AI coding agents";
    homepage = "https://soloterm.com";
    changelog = "https://soloterm.com/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "Solo";
    platforms = [ "x86_64-linux" ];
  };
}
