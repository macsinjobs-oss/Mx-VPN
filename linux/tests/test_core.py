import base64
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mxvpn_core import ConfigError, VpnError, NetworkManager, read_config, validate_config, parse_profiles

KEY = base64.b64encode(bytes(range(1, 33))).decode()
PUBLIC = base64.b64encode(bytes(range(2, 34))).decode()
VALID = f'''[Interface]
PrivateKey = {KEY}
Address = 10.2.0.2/32
DNS = 10.2.0.1
[Peer]
PublicKey = {PUBLIC}
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
'''

class ConfigTests(unittest.TestCase):
    def test_accept_proton_full_tunnel(self):
        self.assertEqual(validate_config(VALID), VALID)

    def test_accept_dual_stack(self):
        config = VALID.replace('10.2.0.2/32', '10.2.0.2/32, fd00::2/128').replace('0.0.0.0/0', '0.0.0.0/0, ::/0')
        self.assertEqual(validate_config(config), config)

    def test_reject_security_hazards_without_key_in_error(self):
        bad = [
            VALID + '[Peer]\nPublicKey = ' + PUBLIC,
            VALID.replace('DNS = 10.2.0.1', 'DNS = 10.2.0.1\nPostUp = touch /tmp/executed'),
            VALID.replace('0.0.0.0/0', '10.0.0.0/8'),
            VALID.replace('10.2.0.2/32', '10.2.0.2/32, fd00::2/128'),
            VALID.replace('PrivateKey = '+KEY, 'PrivateKey = invalid'),
            VALID.replace('DNS = 10.2.0.1\n', ''),
            VALID.replace('Endpoint = 192.0.2.1:51820', 'Endpoint = http://evil.invalid/path'),
            VALID.replace('PrivateKey = '+KEY, 'PrivateKey = '+KEY+'\nPrivateKey = '+KEY),
            VALID + '\x00',
            'x' * 65537,
        ]
        for text in bad:
            with self.subTest(text_length=len(text)):
                with self.assertRaises(ConfigError) as err:
                    validate_config(text)
                self.assertNotIn(KEY, str(err.exception))
                self.assertNotIn(PUBLIC, str(err.exception))

    def test_reject_symlink_and_nonregular(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'real.conf'; p.write_text(VALID)
            link = Path(d)/'link.conf'; link.symlink_to(p)
            with self.assertRaises(ConfigError): read_config(link)
            with self.assertRaises(ConfigError): read_config(Path(d))
            self.assertEqual(read_config(p), VALID)

class BackendTests(unittest.TestCase):
    def test_only_mx_wireguard_profiles(self):
        text = '11111111-1111-1111-1111-111111111111:Mx VPN - Houston:wireguard\n22222222-2222-2222-2222-222222222222:Other VPN:wireguard\n33333333-3333-3333-3333-333333333333:Mx VPN - Wifi:802-11-wireless\n'
        self.assertEqual(len(parse_profiles(text)), 1)

    def test_escaped_colon_name(self):
        profile = parse_profiles('11111111-1111-1111-1111-111111111111:Mx VPN - Houston\\: Texas:wireguard\n')[0]
        self.assertEqual(profile.name, 'Houston: Texas')

    def test_cannot_activate_unowned_profile(self):
        nm = NetworkManager()
        with patch.object(nm, 'list_profiles', return_value=[]), patch.object(nm, '_run') as run:
            with self.assertRaises(VpnError): nm.connect('11111111-1111-1111-1111-111111111111')
            run.assert_not_called()

    def test_subprocess_error_never_echoes_configuration(self):
        import subprocess
        nm = NetworkManager()
        with patch('mxvpn_core.subprocess.run', return_value=subprocess.CompletedProcess([], 2, '', VALID)):
            with self.assertRaises(VpnError) as err: nm._run(['connection', 'show'])
            self.assertNotIn(KEY, str(err.exception))


class ImportIsolationTests(unittest.TestCase):
    def test_import_is_atomic_and_autoconnect_disabled(self):
        nm = NetworkManager()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'Houston.conf'; path.write_text(VALID)
            with patch.object(nm, '_add_connection') as add, patch.object(nm, '_run') as run:
                identifier = nm.import_profile(path)
                settings = add.call_args.args[0]
                self.assertEqual(settings['connection']['uuid'], identifier)
                self.assertFalse(settings['connection']['autoconnect'])
                self.assertTrue(settings['connection']['permissions'][0].startswith('user:'))
                self.assertEqual(settings['wireguard']['private-key'], KEY)
                self.assertEqual(settings['ipv4']['method'], 'manual')
                self.assertEqual(settings['ipv6']['method'], 'disabled')
                run.assert_not_called()

    def test_failed_atomic_import_does_not_mutate_existing_profiles(self):
        nm = NetworkManager()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'Houston.conf'; path.write_text(VALID)
            with patch.object(nm, '_add_connection', side_effect=VpnError('Permission denied')), patch.object(nm, '_run') as run:
                with self.assertRaises(VpnError): nm.import_profile(path)
                run.assert_not_called()

    def test_disconnect_does_not_touch_unrelated_connections(self):
        identifier = '11111111-1111-1111-1111-111111111111'
        other = '22222222-2222-2222-2222-222222222222'
        nm = NetworkManager()
        from mxvpn_core import Profile
        with patch.object(nm, 'list_profiles', return_value=[Profile(identifier,'Houston')]), patch.object(nm, 'active_ids', return_value={identifier,other}), patch.object(nm,'_run') as run:
            nm.disconnect(identifier)
            run.assert_called_once_with(['connection','down','uuid',identifier])

if __name__ == '__main__': unittest.main()
