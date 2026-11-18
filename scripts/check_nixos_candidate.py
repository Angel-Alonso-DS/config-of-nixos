#!/usr/bin/env python3
"""Inspect the CI status of the current public main branch, without changing it."""

import http.client
import json
import re
import sys
import urllib.error
import urllib.request

REPOSITORY = "Angel-Alonso-DS/config-of-nixos"
API = f"https://api.github.com/repos/{REPOSITORY}"
WEB = f"https://github.com/{REPOSITORY}"
CHECKS = ("flake-check", "build-laptop", "build-desktop")
SHA_PATTERN = re.compile(r"[0-9a-f]{40}\Z")
PENDING = {"queued", "in_progress", "waiting", "requested", "pending"}
FAILURES = {"failure", "timed_out", "cancelled", "action_required", "startup_failure", "stale"}


class VerificationError(Exception):
    """The API response cannot establish the candidate's CI status."""


def get_json(url):
    request = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "nixos-candidate-check",
        "X-GitHub-Api-Version": "2022-11-28",
    }, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except (OSError, ValueError, UnicodeError, http.client.HTTPException) as exc:
        raise VerificationError(f"No se pudo consultar o interpretar GitHub: {exc}") from exc


def main_sha():
    data = get_json(f"{API}/branches/main")
    try:
        sha = data["commit"]["sha"]
        if data["name"] != "main" or not isinstance(sha, str) or not SHA_PATTERN.fullmatch(sha):
            raise ValueError("rama o SHA inválido")
    except (KeyError, TypeError, ValueError) as exc:
        raise VerificationError("Respuesta de rama inválida") from exc
    return sha


def check_runs(sha):
    runs = []
    expected = None
    for page in range(1, 12):
        data = get_json(f"{API}/commits/{sha}/check-runs?filter=latest&per_page=100&page={page}")
        if not isinstance(data, dict) or type(data.get("total_count")) is not int or not isinstance(data.get("check_runs"), list):
            raise VerificationError("Respuesta de checks inválida")
        total = data["total_count"]
        if total < 0 or total > 1000 or (expected is not None and total != expected):
            raise VerificationError("Lista de checks demasiado grande o cambiante")
        expected = total
        batch = data["check_runs"]
        if len(batch) > 100 or len(runs) + len(batch) > total or (not batch and len(runs) < total):
            raise VerificationError("Lista de checks incompleta")
        runs.extend(batch)
        if len(runs) == total:
            return runs
    raise VerificationError("Paginación de checks incompleta")


def classify(sha, runs):
    matches = {name: [] for name in CHECKS}
    for run in runs:
        if not isinstance(run, dict) or not isinstance(run.get("name"), str):
            raise VerificationError("Check inválido")
        name = run["name"]
        if name not in matches:
            continue
        app = run.get("app")
        if not isinstance(app, dict) or app.get("id") != 15368 or app.get("slug") != "github-actions":
            raise VerificationError(f"Origen no verificable para {name}")
        if run.get("head_sha") != sha:
            raise VerificationError(f"SHA inconsistente para {name}")
        status, conclusion = run.get("status"), run.get("conclusion")
        if not isinstance(status, str) or (conclusion is not None and not isinstance(conclusion, str)):
            raise VerificationError(f"Estado o conclusión inválida para {name}")
        if status in PENDING and conclusion is None:
            state = "en ejecución" if status == "in_progress" else "en espera"
        elif status == "completed" and conclusion == "success":
            state = "correcto"
        elif status == "completed" and conclusion in FAILURES:
            state = "fallido"
        else:
            raise VerificationError(f"Estado o conclusión desconocida para {name}")
        matches[name].append(state)
    states = {name: ("sin evidencia" if not values else
                     "fallido" if "fallido" in values else
                     "en ejecución" if "en ejecución" in values else
                     "en espera" if "en espera" in values else "correcto")
              for name, values in matches.items()}
    if "fallido" in states.values():
        return "CI fallida", states, 2
    if any(state != "correcto" for state in states.values()):
        return "Candidato pendiente", states, 1
    return "Candidato validado por CI", states, 0


def main():
    sha = None
    print(f"Repositorio: {WEB}\nRama: main")
    try:
        sha = main_sha()
        runs = check_runs(sha)
        state, checks, exit_code = classify(sha, runs)
        if main_sha() != sha:
            raise VerificationError("main cambió durante la consulta; volver a intentarlo")
        print(f"SHA: {sha}\nEstado de CI: {state}")
        for name, status in checks.items():
            print(f"  {name}: {status}")
    except VerificationError as exc:
        print(f"SHA: {sha or 'desconocido'}\nEstado de CI: desconocido\nMotivo: {exc}")
        exit_code = 3
    if sha:
        print(f"Commit: {WEB}/commit/{sha}\nCheck-runs: {API}/commits/{sha}/check-runs")
    print(f"Rama: {WEB}/tree/main\nAcciones: {WEB}/actions")
    print("La validación de CI no indica instalación ni aprobación para activación.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
