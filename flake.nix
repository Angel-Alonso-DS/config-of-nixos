{
  description = "nixos-alons — estación de desarrollo (NixOS 26.05 + Hyprland)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: let
    # Definimos un overlay que parchea antigravity
    antigravity-patch = final: prev: {
      antigravity = prev.antigravity.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          # Guardamos el binario original
          mv $out/bin/antigravity $out/bin/.antigravity-original
          # Creamos un script que filtra el argumento y ejecuta el original
          cat > $out/bin/antigravity <<EOF
          #!/usr/bin/env bash
          exec $out/bin/.antigravity-original "\$(echo "\$@" | sed 's/--render-node-override=[^ ]*//g')"
          EOF
          chmod +x $out/bin/antigravity
        '';
      });
    };
  in {
    nixosConfigurations."nixos-alons" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ({ config, pkgs, ... }: {
          nixpkgs.overlays = [ antigravity-patch ];
        })
        ./configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.backupFileExtension = "backup";

          home-manager.users."alonso" = import ./home.nix;
        }
      ];
    };

    devShells.x86_64-linux.default =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          nodejs_22
          prisma
          prisma-engines
        ];

        shellHook = ''
          export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"
          export PRISMA_SCHEMA_ENGINE_BINARY="${pkgs.prisma-engines}/bin/schema-engine"
          export PRISMA_QUERY_ENGINE_BINARY="${pkgs.prisma-engines}/bin/query-engine"
          export PRISMA_QUERY_ENGINE_LIBRARY="${pkgs.prisma-engines}/lib/libquery_engine.node"
          export PRISMA_FMT_BINARY="${pkgs.prisma-engines}/bin/prisma-fmt"
        '';
      };
  };
}
