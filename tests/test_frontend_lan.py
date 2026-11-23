import contextlib
import io
import json
import pathlib
import sys
import unittest
from unittest import mock


# Load the command without its CLI entry point, so tests never touch the firewall.
source = pathlib.Path(__file__).resolve().parents[1] / "laptop/frontend-lan.py"
namespace = {"__name__": "frontend_lan"}
exec(compile(source.read_text().split("\ntry:\n    main()", 1)[0], str(source), "exec"), namespace)


class FrontendLanTests(unittest.TestCase):
    def test_subnet_requires_one_valid_active_network(self):
        link = json.dumps([{"flags": ["UP"], "operstate": "UP"}])
        address = json.dumps([{"addr_info": [
            {"family": "inet", "scope": "global", "local": "192.168.10.4", "prefixlen": 24}
        ]}])
        with mock.patch.dict(namespace, {"run": mock.Mock(side_effect=[link, address])}):
            self.assertEqual(namespace["subnet"](), "192.168.10.0/24")
        with mock.patch.dict(namespace, {"run": mock.Mock(return_value='[{"flags": [], "operstate": "DOWN"}]')}):
            with self.assertRaises(ValueError):
                namespace["subnet"]()
        addresses = json.loads(address)
        addresses[0]["addr_info"].append({"family": "inet", "scope": "global", "local": "10.0.0.2", "prefixlen": 24})
        with mock.patch.dict(namespace, {"run": mock.Mock(side_effect=[link, json.dumps(addresses)])}):
            with self.assertRaises(ValueError):
                namespace["subnet"]()

    def test_rules_only_recognizes_own_exact_rule(self):
        own = '-A nixos-fw -s 192.168.10.0/24 -i wlo1 -p tcp -m tcp --dport 5173 -m comment --comment frontend-lan-5173 -j ACCEPT'
        other = own.replace('frontend-lan-5173', 'minecraft-lan-25565')
        with mock.patch.dict(namespace, {"run": mock.Mock(return_value=own + '\n' + other)}):
            self.assertEqual(len(namespace["rules"]()), 1)

    def test_on_off_and_status(self):
        entries = []
        def run(*args):
            if '-S' in args:
                return '\n'.join(entries)
            if '-I' in args:
                entries.append('-A nixos-fw -s 192.168.10.0/24 -i wlo1 -p tcp -m tcp --dport 5173 -m comment --comment frontend-lan-5173 -j ACCEPT')
            elif '-D' in args:
                entries.clear()
            return ''
        with mock.patch.dict(namespace, {"run": run, "subnet": lambda: '192.168.10.0/24'}), \
             mock.patch.object(namespace['os'], 'geteuid', return_value=0), \
             mock.patch('builtins.open', mock.mock_open()), \
             mock.patch.object(namespace['fcntl'], 'flock'), contextlib.redirect_stdout(io.StringIO()) as output:
            for action in ('on', 'on', 'status', 'off', 'status'):
                with mock.patch.object(sys, 'argv', ['frontend-lan', action]):
                    namespace['main']()
            self.assertEqual(entries, [])
            self.assertIn('Activa: TCP 5173 desde 192.168.10.0/24 por wlo1', output.getvalue())
            self.assertIn('No hay reglas frontend-lan activas', output.getvalue())

    def test_on_refuses_old_network_and_non_root(self):
        rule = ['-A', 'nixos-fw', '-s', '10.0.0.0/24']
        with mock.patch.dict(namespace, {"rules": lambda: [rule], "subnet": lambda: '192.168.10.0/24'}), \
             mock.patch.object(namespace['os'], 'geteuid', return_value=0), \
             mock.patch('builtins.open', mock.mock_open()), mock.patch.object(namespace['fcntl'], 'flock'), \
             mock.patch.object(sys, 'argv', ['frontend-lan', 'on']):
            with self.assertRaisesRegex(ValueError, 'off primero'):
                namespace['main']()
        with mock.patch.object(namespace['os'], 'geteuid', return_value=1000), \
             mock.patch.object(sys, 'argv', ['frontend-lan', 'status']):
            with self.assertRaisesRegex(ValueError, 'root'):
                namespace['main']()


if __name__ == '__main__':
    unittest.main()
