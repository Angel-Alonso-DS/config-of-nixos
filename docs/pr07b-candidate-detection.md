# PR 07B: consulta manual de candidatos

Desde laptop o desktop, con Python 3 y acceso HTTPS a GitHub:

```sh
python3 scripts/check_nixos_candidate.py
```

La herramienta consulta la rama pública `main` del repositorio
`Angel-Alonso-DS/config-of-nixos`, obtiene los check-runs del SHA exacto y
comprueba de nuevo que `main` no haya cambiado durante la consulta. Busca
`flake-check`, `build-laptop` y `build-desktop` de GitHub Actions (app 15368).
No requiere credenciales, Git, Nix ni privilegios, y no guarda estado local.

Estados y códigos de salida:

- `0`: candidato validado por CI; los tres checks terminaron correctamente.
- `1`: candidato pendiente; el detalle distingue `sin evidencia`, `en espera`
  y `en ejecución` para cada check que todavía no ha terminado correctamente.
- `2`: CI fallida; al menos un check terminó con fallo, cancelación o timeout.
- `3`: estado desconocido; error de red, API, formato, origen, SHA o resultado
  no reconocido. No se considera validado.

Se usa `filter=latest` y se recorren las páginas. Si hay varios checks del mismo
nombre, todos los encontrados deben ser exitosos: uno pendiente o fallido impide
validar el candidato. Esto es deliberadamente conservador y puede requerir
revisión manual de reejecuciones. Si GitHub devuelve una lista incompleta,
cambiante o de más de 1000 checks se informa estado desconocido. GitHub limita
esta API a las 1000 check suites más recientes para un mismo SHA. Puede haber
límites de consultas anónimas o errores temporales; no se almacenan ni se usan
credenciales. La información refleja el momento de la consulta y puede cambiar
después; hay que volver a consultar antes de cualquier decisión humana.

La herramienta no verifica el sistema instalado, la protección de ramas ni una
aprobación de despliegue. Identifica checks por nombre y app, pero no demuestra
qué archivo de workflow los produjo. CI exitosa no demuestra arranque ni salud
del hardware.
No ejecuta `nixos-rebuild`, no cambia ramas ni activa sistemas. El código de
salida no autoriza por sí solo ninguna activación.

Pruebas sin red ni dependencias adicionales:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

GitHub Actions ejecuta `test_check_nixos_candidate.py` en el job existente
`flake-check`, además de evaluar el flake. Si falla cualquiera de los dos pasos,
el check no pasa.
