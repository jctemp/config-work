{pkgs, ...}: let
  buildShellScript = name:
    pkgs.stdenv.mkDerivation {
      inherit name;
      src = ./.;
      installPhase = ''
        mkdir -p $out/bin
        cp logging.sh $out/bin
        cp argument_parser.sh $out/bin
        cp $name.sh $out/bin/$name
      '';
    };
in
  pkgs.symlinkJoin {
    name = "scripts";
    paths = [
      (buildShellScript "install-remote")
      (buildShellScript "install-local")
      (buildShellScript "upgrade")
    ];
  }
