{
  description = "NixOS multi-host configurations for nixos-alons and nixos-desktop";

  inputs = {
    nixpkgs-laptop.url = "github:NixOS/nixpkgs/f3a73bcf5d1c5b75a66cf35a48957e30d41d647a";
    home-manager-laptop = {
      url = "github:nix-community/home-manager/24f8f8e786f87d6a818e1746cb2389bf922afdab";
      inputs.nixpkgs.follows = "nixpkgs-laptop";
    };

    nixpkgs-desktop.url = "github:NixOS/nixpkgs/ee48b147c18c7de1e6ec97dc74792be42724bed1";
    home-manager-desktop = {
      url = "github:nix-community/home-manager/24f8f8e786f87d6a818e1746cb2389bf922afdab";
      inputs.nixpkgs.follows = "nixpkgs-desktop";
    };

    nix-snapd = {
      url = "github:nix-community/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs-desktop";
    };

    bedrock-on-linux.url = "github:Wyze3306/BedrockOnLinux";

    split-monitor-workspaces.url = "github:zjeffer/split-monitor-workspaces/release/0.55.x";
  };

  outputs = { self, nixpkgs-laptop, home-manager-laptop, nixpkgs-desktop
    , home-manager-desktop, nix-snapd, bedrock-on-linux
    , split-monitor-workspaces, ... }@inputs: {
      nixosConfigurations."nixos-alons" = nixpkgs-laptop.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./laptop/configuration.nix

          home-manager-laptop.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "backup";

            home-manager.users."alonso" = import ./laptop/home.nix;
          }
        ];
      };

      nixosConfigurations."nixos-desktop" = nixpkgs-desktop.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = [
          ./desktop/configuration.nix

          {
            environment.systemPackages = [
              bedrock-on-linux.packages.x86_64-linux.default
            ];
          }

          home-manager-desktop.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "backup";

            home-manager.users."alonso" = import ./desktop/home.nix;
          }

          nix-snapd.nixosModules.default
          {
            services.snap.enable = true;
          }
        ];
      };
    };
}
