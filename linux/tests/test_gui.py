"""Exercise real GTK controls with a deterministic backend under Xvfb."""
import sys
import tempfile
import time
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mxvpn_gui import Window, Gtk, GLib
from mxvpn_core import Profile, ConfigError

ID='11111111-1111-1111-1111-111111111111'
class Backend:
    def __init__(self): self.profiles=[]; self.active=set(); self.imported=[]; self.fail=False
    def list_profiles(self): return self.profiles[:]
    def active_ids(self): return self.active.copy()
    def import_profile(self,path):
        if self.fail: raise ConfigError('Invalid full-tunnel configuration.')
        self.imported.append(path);self.profiles=[Profile(ID,'Houston')];return ID
    def connect(self,identifier): self.active.add(identifier)
    def disconnect(self,identifier): self.active.discard(identifier)

def wait(predicate, seconds=5):
    until=time.monotonic()+seconds
    while time.monotonic()<until:
        while GLib.MainContext.default().pending(): GLib.MainContext.default().iteration(False)
        if predicate(): return
        time.sleep(0.01)
    raise AssertionError('GTK flow did not finish')

class GuiTests(unittest.TestCase):
    def test_import_cancel_connect_disconnect_and_error(self):
        backend=Backend(); window=Window(backend);window.show_all()
        wait(lambda:not window.busy)
        self.assertFalse(window.connect_button.get_sensitive())
        window.import_button.emit('clicked')
        self.assertTrue(window.file_chooser.get_visible())
        window.file_chooser.response(Gtk.ResponseType.CANCEL)
        self.assertEqual(backend.imported,[])
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'houston.conf';path.write_text('fixture')
            window.import_button.emit('clicked')
            window.file_chooser.set_filename(str(path))
            wait(lambda:window.file_chooser.get_filename()==str(path))
            window.file_chooser.response(Gtk.ResponseType.ACCEPT)
            wait(lambda:not window.busy and len(backend.imported)==1)
        self.assertTrue(window.connect_button.get_sensitive())
        window.connect_button.emit('clicked')
        wait(lambda:not window.busy and 'active' in window.status.get_text().lower())
        self.assertEqual(backend.active,{ID})
        self.assertTrue(window.disconnect_button.get_sensitive())
        window.disconnect_button.emit('clicked')
        wait(lambda:not window.busy and not backend.active)
        self.assertIn('Disconnected',window.status.get_text())
        backend.fail=True
        window.import_file('/invalid.conf')
        wait(lambda:not window.busy and window.last_error is not None)
        self.assertIsNotNone(window.error_dialog)
        window.error_dialog.response(Gtk.ResponseType.CLOSE)
        self.assertEqual(len(backend.imported),1)
        window.destroy()

if __name__=='__main__': unittest.main()
