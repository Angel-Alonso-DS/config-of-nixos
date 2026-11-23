import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import urllib.error

spec = importlib.util.spec_from_file_location(
    "candidate", Path(__file__).resolve().parents[1] / "scripts/check_nixos_candidate.py"
)
candidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)

SHA = "a" * 40


def run(name, status="completed", conclusion="success", sha=SHA, app_id=15368):
    return {"name": name, "status": status, "conclusion": conclusion,
            "head_sha": sha, "app": {"id": app_id, "slug": "github-actions"}}


def branch(sha=SHA):
    return {"name": "main", "commit": {"sha": sha}}


def checks(runs):
    return {"total_count": len(runs), "check_runs": runs}


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.runs = [run(name) for name in candidate.CHECKS]

    def invoke(self, replies):
        output = io.StringIO()
        with patch.object(candidate, "get_json", side_effect=replies), contextlib.redirect_stdout(output):
            code = candidate.main()
        return code, output.getvalue()

    def test_success(self):
        code, output = self.invoke([branch(), checks(self.runs), branch()])
        self.assertEqual(code, 0)
        self.assertIn("Candidato validado por CI", output)
        self.assertIn(SHA, output)
        self.assertIn("no indica instalación ni aprobación", output)

    def test_missing_and_running_are_pending(self):
        self.runs[0] = run(candidate.CHECKS[0], "in_progress", None)
        code, output = self.invoke([branch(), checks(self.runs[:2]), branch()])
        self.assertEqual(code, 1)
        self.assertIn("Candidato pendiente", output)
        self.assertIn("flake-check: en ejecución", output)
        self.assertIn("build-desktop: sin evidencia", output)

    def test_queued_is_distinct_from_running_and_missing(self):
        runs = [run(candidate.CHECKS[0], "queued", None),
                run(candidate.CHECKS[1], "in_progress", None)]
        code, output = self.invoke([branch(), checks(runs), branch()])
        self.assertEqual(code, 1)
        self.assertIn("flake-check: en espera", output)
        self.assertIn("build-laptop: en ejecución", output)
        self.assertIn("build-desktop: sin evidencia", output)

    def test_failure_takes_precedence_over_pending(self):
        self.runs[0] = run(candidate.CHECKS[0], conclusion="failure")
        code, output = self.invoke([branch(), checks(self.runs[:1]), branch()])
        self.assertEqual(code, 2)
        self.assertIn("CI fallida", output)

    def test_duplicate_failure_cannot_be_hidden_by_success(self):
        self.runs.append(run(candidate.CHECKS[0], conclusion="failure"))
        self.assertEqual(candidate.classify(SHA, self.runs)[0], "CI fallida")

    def test_untrusted_wrong_sha_and_unknown_conclusion_fail_closed(self):
        for invalid in (run(candidate.CHECKS[0], app_id=1),
                        run(candidate.CHECKS[0], sha="b" * 40),
                        run(candidate.CHECKS[0], conclusion="neutral"),
                        run(candidate.CHECKS[0], status=[]),
                        run(candidate.CHECKS[0], conclusion={})):
            with self.subTest(invalid=invalid):
                code, output = self.invoke([branch(), checks([invalid] + self.runs[1:])])
                self.assertEqual(code, 3)
                self.assertIn("desconocido", output)

    def test_branch_changes_during_check(self):
        code, output = self.invoke([branch(), checks(self.runs), branch("b" * 40)])
        self.assertEqual(code, 3)
        self.assertIn("main cambió", output)

    def test_malformed_and_incomplete_responses(self):
        for response in ({"total_count": 2, "check_runs": []}, {"check_runs": []}, []):
            with self.subTest(response=response):
                code, output = self.invoke([branch(), response])
                self.assertEqual(code, 3)
                self.assertIn("desconocido", output)

    def test_pagination(self):
        other = [run(f"other-{i}") for i in range(100)]
        first = {"total_count": 103, "check_runs": other}
        second = {"total_count": 103, "check_runs": self.runs}
        code, _ = self.invoke([branch(), first, second, branch()])
        self.assertEqual(code, 0)

    def test_network_failure(self):
        with patch.object(candidate.urllib.request, "urlopen", side_effect=urllib.error.URLError("offline")), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(candidate.main(), 3)
        self.assertIn("desconocido", output.getvalue())

    def test_only_get_no_credentials_and_no_local_write_or_activation(self):
        responses = [branch(), checks(self.runs), branch()]
        import json
        def fetch(request, timeout):
            self.assertEqual(request.get_method(), "GET")
            self.assertTrue(request.full_url.startswith(candidate.API + "/"))
            self.assertNotIn("Authorization", request.headers)
            self.assertEqual(timeout, 20)
            return io.BytesIO(json.dumps(responses.pop(0)).encode())
        with patch.object(candidate.urllib.request, "urlopen", side_effect=fetch), \
             patch("builtins.open", side_effect=AssertionError("escritura o acceso a archivo")), \
             patch.object(subprocess, "Popen", side_effect=AssertionError("proceso externo")), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(candidate.main(), 0)
        self.assertFalse(responses)


if __name__ == "__main__":
    unittest.main()
