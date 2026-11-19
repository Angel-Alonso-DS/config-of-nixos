# PR 07: CI de validación NixOS

El workflow `Nix validation` se ejecuta en pull requests dirigidos a `dev` o
`main` y en pushes a esas ramas. `dev` es la rama de integración y `main` la
estable. Cada job usa un runner GitHub `ubuntu-24.04` x86_64 independiente.

Los nombres previstos de los checks son `flake-check`, `build-laptop` y
`build-desktop`. Antes de configurarlos como obligatorios, comprobar sus nombres
exactos y resultados en una ejecución real de GitHub Actions. Los builds validan
las derivaciones `nixos-alons` y `nixos-desktop`, sin activar el sistema. No
demuestran que el hardware arranque o que los servicios funcionen en los hosts.

La evaluación y los builds usan `--no-update-lock-file`: fallan si es necesario
actualizar `flake.lock`. Los jobs muestran la versión de Nix, duración de cada
comando y espacio en disco; los logs de Nix conservan los errores de descarga,
dependencias y construcción. Los límites iniciales son 30 minutos para la
evaluación y 120 por build; ajustar tras observar ejecuciones reales. Si se
cancela el job por tiempo, el paso final de diagnóstico puede no ejecutarse.

## Procedencia y límites

- [`actions/checkout` v4.2.2](https://github.com/actions/checkout/releases/tag/v4.2.2):
  `11bd71901bbe5b1630ceea73d27597364c9af683`.
- [`cachix/install-nix-action` v31.11.3](https://github.com/cachix/install-nix-action/releases/tag/v31.11.3):
  `75c75c31ebece974e48ebc36b4ad125bd97bd97b`. Su instalador fija
  [Nix 2.35.4](https://github.com/cachix/install-nix-action/blob/75c75c31ebece974e48ebc36b4ad125bd97bd97b/install-nix.sh);
  la opción `--no-update-lock-file` está documentada en el
  [manual de Nix](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-check).

El instalador necesita privilegios dentro del runner efímero para instalar Nix;
se desactivan KVM y la configuración del usuario como trusted user. La acción
puede usar el `GITHUB_TOKEN` automático de solo lectura para descargar entradas;
no se proporcionan secretos adicionales y checkout no conserva credenciales.
Las referencias fijan el código de las acciones, pero el instalador descarga Nix
de su origen durante la ejecución y las entradas del flake también requieren
descargas. No hay caché propia, SSH, acceso a los hosts ni despliegue.
