import os
import pathlib
import subprocess
import tempfile
import unittest


SOURCE = pathlib.Path(__file__).resolve().parents[1] / "laptop/frontend-lan-dispatcher.sh"


class FrontendLanDispatcherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = pathlib.Path(self.temp.name)
        self.calls = self.base / "calls.txt"
        self.helper = self.base / "frontend-lan"
        self.helper.write_text('#!/bin/sh\nprintf "%s\\n" "$1" >> "$FRONTEND_LAN_TEST_LOG"\nexit "${FRONTEND_LAN_TEST_RC:-0}"\n')
        self.helper.chmod(0o755)
        self.dispatcher = self.base / "dispatcher.sh"
        self.dispatcher.write_text(SOURCE.read_text().replace("@frontendLan@", str(self.helper)))
        self.env = dict(os.environ, FRONTEND_LAN_TEST_LOG=str(self.calls))

    def invoke(self, *args, rc="0"):
        return subprocess.run(["/bin/sh", str(self.dispatcher), *args],
                              env=dict(self.env, FRONTEND_LAN_TEST_RC=rc),
                              capture_output=True, text=True)

    def get_calls(self):
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def test_every_relevant_event_cleans_rules(self):
        events = ("pre-up", "up", "pre-down", "down", "dhcp4-change", "reapply")
        for event in events:
            with self.subTest(event=event):
                self.assertEqual(self.invoke("wlo1", event).returncode, 0)
        self.assertEqual(self.get_calls(), ["off"] * len(events))

    def test_ignores_unrelated_interfaces_and_events(self):
        for args in [("eth0", "down"), ("wlan0", "up"), ("wlo1", "dns-change"),
                     ("wlo1", "connectivity-change"), ("wlo1", "vpn-down"), (),
                     ("wlo1",), ("none", "hostname")]:
            with self.subTest(args=args):
                self.assertEqual(self.invoke(*args).returncode, 0)
        self.assertEqual(self.get_calls(), [])

    def test_propagates_cleanup_failure_without_opening_port(self):
        self.assertEqual(self.invoke("wlo1", "down", rc="17").returncode, 17)
        self.assertEqual(self.get_calls(), ["off"])


if __name__ == "__main__":
    unittest.main()
