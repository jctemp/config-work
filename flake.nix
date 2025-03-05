{
  description = "NixOS system configuration";

  nixConfig = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  inputs = {
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    flake-utils.url = "github:numtide/flake-utils";
    nix-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = inputs:
    {
      nixosConfigurations = let
        hostName = "PC3301019";
        system = "x86_64-linux";
      in {
        default = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit inputs;};
          modules = [
            inputs.nixos-facter-modules.nixosModules.facter
            inputs.impermanence.nixosModules.impermanence
            inputs.disko.nixosModules.disko

            "${inputs.self}/configuration.nix"
            "${inputs.self}/user.nix"
            "${inputs.self}/disks.nix"

            (
              {...}: {
                networking.hostName = hostName;
                system.stateVersion = "24.11";
              }
            )
          ];
        };
      };
    }
    // (inputs.flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import inputs.nixpkgs {inherit system;};
      in {
        formatter = pkgs.alejandra;
        devShells.default = pkgs.mkShellNoCC {
          name = "system config";
          packages = let
            scriptsPkgs = pkgs.callPackage ./scripts {};
          in [
            scriptsPkgs
            pkgs.nix
            pkgs.git
          ];
        };
      }
    ));
}
