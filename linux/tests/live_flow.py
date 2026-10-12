"""Actual imported-profile activation and GTK flow against isolated WireGuard peer."""
import os
import subprocess
import sys
import time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from mxvpn_core import NetworkManager
from mxvpn_gui import Window, Gtk, GLib

nm=NetworkManager();profile=None
config=os.environ['MX_TEST_CONFIG']
window=Window(nm);window.show_all()
def wait(predicate,seconds=40):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  while GLib.MainContext.default().pending():GLib.MainContext.default().iteration(False)
  if window.last_error:raise AssertionError(window.last_error)
  if predicate():return
  time.sleep(.02)
 raise AssertionError('GTK/network operation did not finish')
try:
 wait(lambda:not window.busy)
 assert not window.connect_button.get_sensitive()
 window.import_button.emit('clicked')
 window.file_chooser.set_filename(config)
 wait(lambda:window.file_chooser.get_filename()==config)
 window.file_chooser.response(Gtk.ResponseType.ACCEPT)
 wait(lambda:not window.busy and window.profiles.get_active_id() is not None)
 profile=window.profiles.get_active_id()
 permissions=nm._run(['--get-values','connection.permissions','connection','show','uuid',profile])
 print('NetworkManager permission display:',permissions)
 import pwd
 username=pwd.getpwuid(os.getuid()).pw_name
 assert 'user:'+username in permissions.replace('\\:',':')
 stored=[]
 for folder in ['/etc/NetworkManager/system-connections','/run/NetworkManager/system-connections','/etc/netplan']:
  for file in Path(folder).glob('*'):
   if file.is_file() and profile in file.read_text(errors='replace'):
    stored.append(file)
 assert stored, 'Persistent NetworkManager profile missing'
 for file in stored:
  assert file.stat().st_uid==0 and file.stat().st_mode & 0o077==0
 print('Protected profile storage:',[str(file.parent) for file in stored])
 assert nm._run(['--get-values','connection.autoconnect','connection','show','uuid',profile])=='no'
 assert nm._run(['--get-values','ipv4.dns','connection','show','uuid',profile])=='10.111.0.1'
 window.connect_button.emit('clicked')
 wait(lambda:not window.busy and profile in window.active)
 for address in ['10.111.0.1','fd11::1']:
  subprocess.run(['ping','-c','2','-W','3',address],check=True,stdout=subprocess.DEVNULL)
 print('GTK Import/Connect: peer responded through IPv4 and IPv6 WireGuard tunnel.')
 import gi
 gi.require_version('Gdk','3.0')
 from gi.repository import Gdk
 image=Gdk.pixbuf_get_from_window(window.get_window(),0,0,*window.get_size())
 image.savev(os.environ['MX_SCREENSHOT'],'png',[],[])
 os.chmod(os.environ['MX_SCREENSHOT'],0o644)
 window.disconnect_button.emit('clicked')
 wait(lambda:not window.busy and profile not in window.active)
 assert window.status.get_text()=='Disconnected'
 window.connect_button.emit('clicked')
 wait(lambda:not window.busy and profile in window.active)
 subprocess.run(['ping','-c','1','-W','3','10.111.0.1'],check=True,stdout=subprocess.DEVNULL)
 window.disconnect_button.emit('clicked')
 wait(lambda:not window.busy and profile not in window.active)
 print('GTK Disconnect/Reconnect/Disconnect passed.')
finally:
 if profile:
  nm.disconnect(profile)
  nm._run(['connection','delete','uuid',profile])
 window.destroy()
