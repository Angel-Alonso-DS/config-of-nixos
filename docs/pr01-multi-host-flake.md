# PR 01 — Consolidación del Flake multi-host

**Estado:** flake y lock raíz generados y validados sin activación. La revisión original de Home Manager del desktop no pudo recuperarse; se autorizó usar temporalmente la revisión conocida de laptop, sin afirmar equivalencia funcional.

## Revisiones recuperadas

| Host | Nixpkgs | Home Manager | Evidencia |
| --- | --- | --- | --- |
| `nixos-alons` | `f3a73bcf5d1c5b75a66cf35a48957e30d41d647a` | `24f8f8e786f87d6a818e1746cb2389bf922afdab` | `laptop/flake.lock` rastreado |
| `nixos-desktop` | `ee48b147c18c7de1e6ec97dc74792be42724bed1` | `24f8f8e786f87d6a818e1746cb2389bf922afdab` (selección temporal) | El baseline físico reportó `ee48b14`; la resolución verificable de ese prefijo confirma el commit completo de Nixpkgs. La revisión de Home Manager fue autorizada como sustitución temporal. |

## Dependencia no recuperable

No existe `desktop/flake.lock` rastreado, ignorado ni en el historial disponible. Las versiones históricas de `desktop/flake.nix` solo referencian la rama `release-26.05` de Home Manager y no fijan una revisión. La metadata local sin red tampoco estaba disponible por permisos de caché.

Por ello, resolver hoy `home-manager/release-26.05` elegiría una revisión actual de la rama y **no** demostraría equivalencia con la generación física del desktop. No se debe presentar ese resultado como recuperación de su dependencia original. Se autorizó en su lugar usar temporalmente `24f8f8e786f87d6a818e1746cb2389bf922afdab`, la revisión conocida de laptop; esta selección tampoco garantiza equivalencia funcional para desktop.

## Estrategia propuesta y bloqueo

El flake raíz usará pares separados `nixpkgs-laptop`/`home-manager-laptop` y `nixpkgs-desktop`/`home-manager-desktop`, con cada Home Manager siguiendo únicamente el Nixpkgs de su host. También conservará `nix-snapd`, `bedrock-on-linux` y `split-monitor-workspaces` como inputs exclusivos del desktop.

La estructura conserva sin cambios los imports actuales, los `specialArgs` y `home-manager.extraSpecialArgs`. Cada instancia de Home Manager sigue solo el Nixpkgs de su host: `home-manager-laptop` sigue `nixpkgs-laptop` y `home-manager-desktop` sigue `nixpkgs-desktop`. El mismo patrón se aplica a `nix-snapd` con `nixpkgs-desktop`.

## Lock raíz e inputs indirectos

El nuevo `flake.lock` raíz fija los inputs directos anteriores y hace reproducible por primera vez el conjunto de dependencias del desktop. Las siguientes revisiones indirectas se resolvieron al generar el lock; no existía lock previo de desktop con el cual demostrar equivalencia histórica:

- `nix-snapd`: `e5558c8b77e4437d3035186bba62c128ed09dbfc`, con `flake-parts` y `nixpkgs.lib` como dependencias indirectas. Su Nixpkgs sigue `nixpkgs-desktop`.
- `bedrock-on-linux`: `8ed2e52b03e47b5bed531e3b418102c282efcefd`, que conserva su Nixpkgs indirecto propio `02c087f3fe673c9e317f206a627cb6b910336dbe`.
- `split-monitor-workspaces`: `d6b45cdb9b30c388bc4ded4adad78a14e523d591`, con el grafo histórico de Hyprland y su Nixpkgs indirecto `a999c1cc0c9eb2095729d5aa03e0d8f7ed256780`.

Estos Nixpkgs indirectos pertenecen a los flakes exclusivos del desktop y se conservaron para no alterar su comportamiento declarado durante PR 01. La consolidación futura de dependencias se evaluará con pruebas y autorización separadas.

## Validación sin activación

- Evaluación independiente de `nixosConfigurations.nixos-alons` y `nixosConfigurations.nixos-desktop`: correcta.
- `nix flake check --no-build`: correcto para ambos outputs.
- Builds independientes con `nix build --no-link` para ambos toplevels: correctas; no se creó un enlace de resultado ni se activó una configuración.

Desde la raíz del repositorio, los comandos de evaluación y construcción son:

```bash
nix eval --show-trace .#nixosConfigurations.nixos-alons.config.system.build.toplevel.drvPath
nix eval --show-trace .#nixosConfigurations.nixos-desktop.config.system.build.toplevel.drvPath
nix flake check --no-build
nix build --no-link .#nixosConfigurations.nixos-alons.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.nixos-desktop.config.system.build.toplevel
```

Los dos últimos comandos construyen artefactos sin activarlos; no sustituyen `nixos-rebuild switch` ni `nixos-rebuild boot`, que están fuera de alcance de este PR.

La laptop conserva el Nixpkgs y Home Manager que ya estaban bloqueados. El desktop conserva el Nixpkgs observado en el baseline físico; su Home Manager temporal puede cambiar la evaluación respecto de su generación activa y es el principal riesgo pendiente. Los módulos de hardware, bootloader, servicios, Home Manager y entorno gráfico permanecen en sus rutas de host sin refactorización.

No se ha modificado ninguna configuración NixOS activa. La evaluación y build de ambos outputs se realizarán sin activarlos.
