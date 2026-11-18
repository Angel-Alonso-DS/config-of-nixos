# Decisiones congeladas — Arquitectura NixOS multi-host

**Alcance:** especificación de diseño aprobada, sin ejecución de cambios.

## Objetivo y límites

- Un Flake raíz con dos outputs: `nixosConfigurations.nixos-alons` y `nixosConfigurations.nixos-desktop`.
- Un `flake.lock` común, con dependencias específicas de host aisladas.
- La laptop es la fuente de referencia del stack de desarrollo. Las herramientas exclusivas del desktop permanecen allí hasta promoverse explícitamente a un perfil compartido.
- Una base global de herramientas, con versiones específicas de proyecto mediante `devShell`/`direnv`.
- Herramientas/CLI compartidas; habilitación de servicios (MariaDB, PostgreSQL, Ollama, Docker, virtualización) por host.
- Perfiles opcionales separados para gaming, office y multimedia, conservando aplicaciones actuales en el primer cambio.
- Home Manager unificado con temas compartidos y overlays por equipo. Hyprland y KDE Plasma disponibles en ambos equipos.
- Aislar configuraciones de hardware, GPU, firmware, bootloader, sensores, monitores, filesystem y UUIDs.
- GRUB será el bootloader en ambos; desktop migrará desde systemd-boot en una fase **independiente** posterior a validar multi-host.
- GRUB conservará NixOS, sus generaciones anteriores y otros sistemas operativos existentes cuando corresponda, sujeto a verificación física.
- Cada implementación utiliza rama independiente `feature/XX-*` y PR propio dirigido a `dev`. `main` solo recibe promociones explícitas verificadas.
- CI construye y valida ambos hosts si es viable; cada host valida nuevamente antes de activar.
- Después de aprobación humana, cada host consulta periódicamente revisiones autorizadas mediante un servicio local `systemd`.
- `boot` para cambios de sistema, riesgo elevado o incierto; `switch` solo para cambios expresamente clasificados de bajo riesgo. La clasificación debe basarse en efectos, no solo en nombre del archivo.
- **Nunca reiniciar automáticamente.** Notificar y dejar que el usuario elija cuándo reiniciar.
- Conservar generaciones, ejecutar health checks y ofrecer recuperación supervisada.
- Seguridad: aplicar estándares/buenas prácticas existentes y registrar riesgos, sin aprovechar esta migración para rediseñar políticas de red, autenticación o servicios. No introducir nuevas exposiciones inseguras.
- No alterar bases de datos ni otros datos persistentes durante la reorganización.

## Condiciones de trabajo

1. Crear cada rama nueva desde `dev` actualizado, no desde otra rama de implementación.
2. Construir/validar las dos configuraciones antes de solicitar aprobación.
3. Cambios funcionales de sistema y bootloader requieren fase y pruebas independientes.
4. Ningún merge, promoción a `main`, aplicación automática en hosts o reinicio sin autorización y criterios de aceptación.
5. Conservar un inventario de diferencias específicas por host para evitar perder funcionalidad al compartir archivos.

## Secuencia prevista

| PR | Rama | Objetivo |
| --- | --- | --- |
| 00 | `feature/00-baseline` | Inventario, decisiones, guías y baseline físico |
| 01 | `feature/01-multi-host-flake` | Flake raíz y lock común sin cambios funcionales |
| 02 | `feature/02-shared-modules` | Sistema y Home Manager compartidos |
| 03 | `feature/03-development-profiles` | Development y servicios por host |
| 04 | `feature/04-optional-profiles` | Gaming, office y multimedia |
| 05 | `feature/05-desktop-environment` | Hyprland/Waybar y hardware |
| 06 | `feature/06-grub-migration` | GRUB en desktop, operación supervisada |
| 07 | `feature/07-automated-deployment` | CI, validación y distribución |
| 08 | `feature/08-recovery` | Activación y recuperación supervisada |

Esta tabla define objetivos, no autoriza cambios ni pruebas de activación.
