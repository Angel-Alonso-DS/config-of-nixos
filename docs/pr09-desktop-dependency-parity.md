# PR 09: recuperación de dependencias del desktop

La recuperación de las dependencias originales y la regeneración de `flake.lock` se realizaron desde la terminal física. Según los resultados comunicados de esa ejecución, `system.build.toplevel` coincide exactamente con las generaciones instaladas de ambos hosts. La rama parte de `a2488fe0a01010928073e5ebe767797864e8993d`.

## Causa de la discrepancia

Según [PR 01](pr01-multi-host-flake.md), al crear el flake multi-host no se disponía del lock original del desktop y su Home Manager apuntaba a una rama móvil. Se utilizó provisionalmente la revisión de Home Manager de la laptop, sin afirmar equivalencia; el lock raíz resolvió nix-snapd y BedrockOnLinux en ese momento. Estas revisiones diferían de las recuperadas posteriormente del equipo físico. Antes de corregirlas, el desktop reorganizado evaluaba a `/nix/store/njh35cvs1ngip9n18j9y4zsr846wg74z-nixos-system-nixos-desktop-26.05.20260807.ee48b14`, distinto de la generación 117 instalada.

## Dependencias recuperadas

| Input | Revisión anterior | Revisión recuperada | narHash recuperado |
| --- | --- | --- | --- |
| home-manager-desktop | `24f8f8e786f87d6a818e1746cb2389bf922afdab` | `d4fd24667c8cbef124bb70a20380cab75ec8474d` | `sha256-Rgs2xKnGLFWQscxUaXX07oyZeuMDOHEbqDOsgliLFGM=` |
| nix-snapd | `e5558c8b77e4437d3035186bba62c128ed09dbfc` | `f7694a0e26d890e285137e1b726b1b44038805c4` | `sha256-OKuNVXmHuZ0zi8T0aGWrBJizIfvdTqV1RiV0IN8GPZs=` |
| BedrockOnLinux | `8ed2e52b03e47b5bed531e3b418102c282efcefd` | `276ae7bd6172c588b7311cb70faf3145a0af3fd2` | `sha256-F8tN9HVfhO2cQS0v+mQpLwth8xXYFtXzBbcvlV2kcq0=` |
| Nixpkgs indirecto de Bedrock | `02c087f3fe673c9e317f206a627cb6b910336dbe` | `2fcb964de67fcf60b43471c55d5d99e61a9ccb5a` | `sha256-RzPPiWeUtuvymnpuEWsdtzli5w4kjZs49FqEs3/1u+I=` |

La revisión principal de Nixpkgs del desktop permanece en `ee48b147c18c7de1e6ec97dc74792be42724bed1`, con `sha256-ZuvZfVW2tB5tXYEcpcfhVXB3N4OhdZLOqOviy4OD4b4=`. Home Manager y nix-snapd siguen `nixpkgs-desktop`; Bedrock conserva su propio Nixpkgs indirecto. Las dependencias de la laptop permanecen sin cambios. La regeneración también cambió dos nodos transitivos de nix-snapd:

- `flake-parts`: de `ea2630b7470978622c7689a1ff75d2b389175399` a `864599284fc7c0ba6357ed89ed5e2cd5040f0c04`.
- `nixpkgs-lib`, dependencia de `flake-parts`: de `7851ba61fd862b277cb6a9cef37394bc18bb94e4` a `a73b9c743612e4244d865a2fdee11865283c04e6`.

## Evaluaciones y validaciones

Las siguientes rutas de `system.build.toplevel` fueron comunicadas como resultado de la evaluación en la terminal física y coinciden exactamente con las generaciones instaladas respectivas:

| Host | Generación instalada | Resultado de la evaluación |
| --- | --- | --- |
| `nixos-alons` | 163 | `/nix/store/4jddkiap7hdnfbbnx2gh9qlviv0sgfw4-nixos-system-nixos-alons-hyprland-26.05.20261019.f3a73bc` |
| `nixos-desktop` | 117 | `/nix/store/8hd2szsa56n55aa8dgyrbx3rxcmn8pqc-nixos-system-nixos-desktop-26.05.20260807.ee48b14` |

La inspección de texto de `flake.nix` y `flake.lock` en el sandbox confirmó las revisiones, hashes y relaciones de inputs indicadas, así como la conservación de los inputs de la laptop y del Nixpkgs principal del desktop. `git diff --check` pasó. La regeneración del lock y las evaluaciones se efectuaron fuera del sandbox; aquí no se volvieron a ejecutar comandos de Nix.

En el intento anterior dentro del sandbox, Nix no pudo acceder a su caché habitual ni al socket del daemon; un intento de evaluación local de solo lectura tampoco pudo abrir la base de datos del almacén. Esos intentos no produjeron resultados de evaluación.

No quedan discrepancias de `system.build.toplevel` pendientes según las rutas comunicadas. Queda pendiente la revisión humana de los cambios, incluidos los nodos transitivos del lock. No se activaron nuevas generaciones ni se modificó `/etc/nixos` durante este trabajo; las evaluaciones comunicadas no implican una activación.
