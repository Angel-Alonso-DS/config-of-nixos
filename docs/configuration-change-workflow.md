# Flujo de trabajo para cambios en la configuración NixOS

## Objetivo y alcance

Esta guía define cómo agregar, quitar o modificar aplicaciones, servicios, módulos, scripts, comandos y configuraciones en el repositorio `Angel-Alonso-DS/config-of-nixos`.

El repositorio es la fuente declarativa de los dos equipos:

- `nixos-alons`: laptop Lenovo LOQ, con GRUB UEFI.
- `nixos-desktop`: escritorio, con GRUB UEFI.

El checkout de trabajo se encuentra en `/home/alonso/nixos`. No editar `/etc/nixos`, los archivos generados en `~/.config` por Home Manager ni las rutas de `/nix/store` para realizar cambios permanentes. Home Manager está integrado como módulo de NixOS en `flake.nix`, por lo que los cambios de usuario también se aplican mediante el despliegue autorizado del host.

**Regla general:** rama de trabajo desde `dev` → pruebas locales → PR a `dev` → revisión y CI → PR de `dev` a `main` → CI del commit exacto de `main` → despliegue supervisado → verificación. No existe despliegue automático desde GitHub.

La guía de [despliegue supervisado](git-deployment-workflow.md) define las comprobaciones y autorizaciones obligatorias para aplicar un candidato. Esta guía complementa dicho procedimiento; no lo sustituye.

## 1. Elegir el alcance y la ubicación

| Tipo de cambio | Ubicación habitual | Consideraciones |
| --- | --- | --- |
| Paquete o configuración de usuario | `desktop/home.nix`, `laptop/home.nix`, `modules/home/` | Preferir Home Manager para preferencias y herramientas exclusivas del usuario. |
| Paquete, servicio, hardware o ajuste de sistema | `desktop/common.nix`, `laptop/common.nix`, `*/configuration.nix`, `modules/system/` | Revisar permisos, servicios, reinicios y dependencias. |
| Herramienta de desarrollo compartida | `modules/system/development/base.nix` | Comprobar que el paquete existe en la revisión fijada de `nixpkgs` de cada host. |
| Conjunto de aplicaciones por uso | `profiles/` | Revisar qué hosts importan el perfil. |
| Waybar o Hyprland exclusivo de un host | `desktop/modules/home/`, `laptop/modules/home/` | Conservar diferencias de sensores, GPU, salidas, batería y dispositivos. |
| Recurso o script común de Waybar | `modules/home/waybar/scripts/` u otro módulo compartido apropiado | Asegurar importación, despliegue, intérprete y dependencias en ambos hosts. |
| Comando personalizado | Módulo Nix que instale un ejecutable o archivo gestionado por Home Manager | Definir privilegios, `PATH`, intérprete, dependencias y pruebas. |
| Dependencia del Flake | `flake.nix` y, cuando corresponda, `flake.lock` | Revisar la actualización del lock por separado; no cambiarlo sin necesidad. |

Antes de editar, localizar todas las declaraciones e importaciones relacionadas: `rg -n 'nombre-o-ruta' desktop laptop modules profiles flake.nix`. Una aplicación puede estar declarada simultáneamente en `environment.systemPackages` y `home.packages`; no asumir que quitar una referencia elimina el paquete. Los paquetes del host y los del usuario se gestionan mediante mecanismos diferentes.

Para código compartido, extraer solo el comportamiento realmente común. Mantener en los módulos del host las diferencias de hardware y de interfaz. Evitar introducir una refactorización general como dependencia innecesaria de un cambio pequeño.

## 2. Clasificar el riesgo y definir las pruebas

| Alcance | Ejemplos | Validación adicional |
| --- | --- | --- |
| Usuario o apariencia | Estilos de Waybar, temas, lanzadores | Verificar sesión gráfica, acciones, archivos materializados y apariencia real. |
| Aplicación o comando | Agregar navegador, retirar paquete, añadir utilidad | Verificar presencia o ausencia, ejecución, dependencias, rutas y permisos. |
| Compartido o con scripts | Reutilizar módulos, convertir scripts de Lua a Bash | Construir ambos hosts; probar sintaxis, salidas, errores y llamadas desde el consumidor. |
| Crítico | Kernel, NVIDIA, red, firewall, bootloader, almacenamiento | Disponer de recuperación y respaldo; planificar reinicio y pruebas físicas específicas. |

Una evaluación o compilación correcta no demuestra que los menús funcionen, que una interfaz se vea bien o que un servicio real tenga conectividad. Definir una comprobación observable para el cambio antes de implementarlo.

**Ejemplo ilustrativo, no una tarea autorizada:** unificar estilos de Waybar, migrar sus scripts de Lua a Bash y agregar otro navegador son tres cambios separables. La unificación requiere identificar las opciones comunes y las exclusivas de cada host; la migración de intérprete requiere verificar dependencias, `on-click` y comportamiento; la instalación de un navegador requiere decidir su alcance y ubicación. Esta guía no implementa ninguno de esos cambios.

## 3. Crear una rama desde `dev`

Ejecutar los siguientes comandos en uno de los equipos, desde el checkout habitual:

```bash
cd /home/alonso/nixos
git status --short --branch
# Detenerse si existen cambios locales que todavía no se han preservado.
git fetch origin
git switch dev
git merge --ff-only origin/dev
git switch -c feature/descripcion-del-cambio
```

Usar una rama por cambio coherente (`feature/*`, `fix/*`, `refactor/*` o `docs/*`). Si `--ff-only` falla, investigar la divergencia; no forzar la rama ni descartar trabajo local. Para varios cambios independientes, utilizar varios PRs.

## 4. Editar y validar sin activar

Modificar únicamente los archivos fuente necesarios. Los archivos gestionados por Home Manager son normalmente enlaces al Nix store y deben cambiarse desde el repositorio. Al crear o mover un script, actualizar sus referencias y comprobar que el ejecutable, los permisos y las herramientas que invoca existen en el entorno adecuado. No confiar en herramientas presentes únicamente en el `PATH` interactivo.

Inspeccionar las modificaciones:

```bash
git status --short
git diff --check
git diff
```

Si hay archivos nuevos, añadirlos a Git antes de evaluar el Flake; los archivos sin seguimiento pueden quedar excluidos de la fuente del Flake:

```bash
git add ruta/del/archivo-nuevo
git diff --cached --check
```

Validación mínima de Nix:

```bash
nix flake check --no-build --no-update-lock-file
```

Construir el host afectado **sin activar** la configuración:

```bash
# Desktop
nix build --no-link --no-update-lock-file \
  .#nixosConfigurations.nixos-desktop.config.system.build.toplevel

# Laptop
nix build --no-link --no-update-lock-file \
  .#nixosConfigurations.nixos-alons.config.system.build.toplevel
```

Si cambia un módulo compartido, construir ambos hosts. En los demás casos, validar al menos el afectado; CI construirá los dos. Si se agrega Bash, Python u otro lenguaje, ejecutar también comprobaciones específicas cuando correspondan (`bash -n`, tests del proyecto, pruebas funcionales o herramientas de análisis disponibles). Un chequeo de sintaxis no sustituye una prueba funcional.

Revisar `flake.lock` con `git diff -- flake.lock` y `git diff --cached -- flake.lock`. No ejecutar `nix flake update` como efecto secundario de una tarea ordinaria; una actualización de dependencias requiere revisión explícita.

## 5. Commit y PR hacia `dev`

Tras revisar las rutas que se incluirán:

```bash
git add ruta1 ruta2
git diff --cached --check
git diff --cached
git commit -m "feat: describir el cambio"
git push -u origin feature/descripcion-del-cambio
```

Crear un PR de la rama de trabajo hacia `dev`. Documentar objetivo, alcance, archivos afectados, comandos de validación, resultados, riesgos y recuperación. No mezclar modificaciones no relacionadas.

Esperar los jobs de GitHub Actions `flake-check`, `build-laptop` y `build-desktop`, revisar el diff y fusionar únicamente con la autorización humana prevista. Los checks de GitHub prueban evaluación y construcción, **no** el funcionamiento físico.

## 6. Promoción de `dev` a `main`

Una vez integrado y revisado el cambio en `dev`, abrir un PR de `dev` hacia `main`. Verificar su CI y fusionar solo tras la revisión autorizada. Después comprobar los checks del **SHA exacto de `main`** que se pretende instalar; el éxito de un PR anterior no basta para autorizar otro commit.

La herramienta de consulta manual existente ayuda a comprobar el candidato de `main`:

```bash
python3 scripts/check_nixos_candidate.py
```

El resultado no realiza despliegues ni representa por sí mismo una autorización. Véanse la [documentación del detector](pr07b-candidate-detection.md) y la [CI](pr07-validation-ci.md).

## 7. Actualización y despliegue por host

El despliegue desde Git se realiza **solo sobre el commit de `main` autorizado**, con un árbol limpio y comprobación del SHA y su CI. Trabajar en un equipo a la vez. Seguir el checklist íntegro de [despliegue supervisado](git-deployment-workflow.md#antes-de-autorizar-una-activación).

```bash
cd /home/alonso/nixos
git status --short --branch
git fetch origin
git rev-parse origin/main
# Comparar el SHA remoto con el candidato autorizado y su CI.
git switch main
git merge --ff-only origin/main
git rev-parse HEAD
git status --short --branch
```

Comprobar el host y construir localmente el candidato de `main` antes de activar. Según el impacto, elegir **una** operación autorizada:

| Operación | Uso y límite |
| --- | --- |
| `nix build --no-link` | Solo construcción, sin activación. |
| `nixos-rebuild dry-activate` | Previsualización parcial de activación; no garantiza el resultado. |
| `nixos-rebuild test` | Activación temporal en la sesión actual; puede afectar servicios y datos. No fija la nueva generación como arranque predeterminado. |
| `nixos-rebuild switch` | Activa de inmediato y establece el candidato para futuros arranques. |
| `nixos-rebuild boot` | Instala como configuración de arranque futuro, sin activar servicios inmediatamente. |

Para la operación aprobada, usar el atributo real del host y la ruta absoluta del checkout; por ejemplo, **solo después de su autorización**:

```bash
sudo nixos-rebuild switch --flake /home/alonso/nixos#nixos-desktop
```

En `nixos-alons`, sustituir el atributo por `nixos-alons`. No usar `--install-bootloader` en reconstrucciones ordinarias. Las operaciones `test`, `boot`, `switch` y cualquier reinicio requieren autorización específica, incluso si el cambio parece visual.

## 8. Verificación y recuperación

Tras activar, comprobar el comportamiento real del cambio: presencia o ausencia de aplicaciones, comandos, sesiones, módulos de Waybar, eventos, servicios y dispositivos afectados. Registrar qué se verificó en cada host. Para cambios con reinicio, identificar la generación arrancada, la activa y la seleccionada para el siguiente arranque:

```bash
hostnamectl --static
readlink -f /run/booted-system
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
systemctl --failed
systemctl --user --failed
```

Si falla una configuración nueva, detener las activaciones adicionales. Conservar generaciones anteriores, USB de recuperación y respaldos. Usar el menú de GRUB y el procedimiento de [recuperación y rollback](pr08-recovery-rollback.md) después de confirmar que sus instrucciones corresponden al bootloader actual. No ejecutar limpieza de generaciones o garbage collection para resolver un problema de despliegue sin un plan separado.

## Checklist para cerrar un cambio

- [ ] Cambio delimitado y archivos adecuados para usuario, sistema y host.
- [ ] No hay modificaciones accidentales de `flake.lock` ni archivos ajenos.
- [ ] Scripts y comportamiento específico probados; builds afectados correctos.
- [ ] PR hacia `dev` revisado y con CI satisfactoria.
- [ ] PR de `dev` hacia `main` revisado; CI del SHA exacto de `main` verificada.
- [ ] Activación autorizada por host, con recuperación disponible.
- [ ] Comportamiento real verificado; incidencias y resultados documentados.

**Nota:** cambios experimentales que se quieran activar directamente desde una rama de desarrollo requieren definir y aprobar otro procedimiento. Esta guía conserva la política actual: no activar candidaturas ordinarias desde `feature/*` o `dev`.
