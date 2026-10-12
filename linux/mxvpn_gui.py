"""Small Linux Mint desktop client. NetworkManager owns networking and secrets."""
import threading

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

from mxvpn_core import ConfigError, NetworkManager, VpnError


class Window(Gtk.Window):
    def __init__(self, backend=None):
        super().__init__(title="Mx VPN")
        self.backend = backend or NetworkManager()
        self.busy = False
        self.closed = False
        self.updating = False
        self.active = set()
        self.file_chooser = None
        self.error_dialog = None
        self.last_error = None
        self.set_default_size(440, 300)
        self.set_border_width(24)
        self.connect("destroy", self.on_destroy)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        self.add(box)
        title = Gtk.Label(label="Mx VPN", xalign=0)
        title.get_style_context().add_class("title")
        box.pack_start(title, False, False, 0)
        box.pack_start(Gtk.Label(label="Your WireGuard connection", xalign=0), False, False, 0)
        self.profiles = Gtk.ComboBoxText()
        self.profiles.set_tooltip_text("Select an imported VPN profile")
        self.profiles.connect("changed", self.selection_changed)
        box.pack_start(self.profiles, False, False, 0)
        self.status = Gtk.Label(label="Loading profiles…", xalign=0)
        self.status.set_line_wrap(True)
        box.pack_start(self.status, False, False, 0)

        buttons = Gtk.Box(spacing=8)
        self.import_button = Gtk.Button(label="Import config")
        self.connect_button = Gtk.Button(label="Connect")
        self.disconnect_button = Gtk.Button(label="Disconnect")
        self.import_button.connect("clicked", self.choose_file)
        self.connect_button.connect("clicked", lambda _: self.activate())
        self.disconnect_button.connect("clicked", lambda _: self.deactivate())
        for button in (self.import_button, self.connect_button, self.disconnect_button):
            buttons.pack_start(button, True, True, 0)
        box.pack_start(buttons, False, False, 0)
        note = Gtk.Label(label="Import a private .conf from your VPN provider.\nNo VPN account or configuration is included.", xalign=0)
        note.set_line_wrap(True)
        note.get_style_context().add_class("dim-label")
        box.pack_start(note, False, False, 0)
        self.refresh()
        self.timer = GLib.timeout_add_seconds(3, self.periodic_refresh)

    def on_destroy(self, _):
        self.closed = True
        if hasattr(self, "timer"):
            GLib.source_remove(self.timer)
        if Gtk.main_level():
            Gtk.main_quit()

    def controls(self):
        selected = self.profiles.get_active_id()
        self.import_button.set_sensitive(not self.busy)
        self.profiles.set_sensitive(not self.busy)
        self.connect_button.set_sensitive(not self.busy and bool(selected) and selected not in self.active)
        self.disconnect_button.set_sensitive(not self.busy and bool(selected) and selected in self.active)

    def selection_changed(self, _):
        if not self.updating:
            self.show_status()

    def show_status(self):
        selected = self.profiles.get_active_id()
        if not selected:
            self.status.set_text("Import a configuration to get started.")
        else:
            self.status.set_text("VPN tunnel active" if selected in self.active else "Disconnected")
        self.controls()

    def show_error(self, message):
        self.last_error = message
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True, message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.CLOSE, text="Could not complete action",
        )
        dialog.format_secondary_text(message)
        dialog.connect("response", lambda d, _: d.destroy())
        self.error_dialog = dialog
        dialog.show_all()

    def job(self, operation, success, label=None):
        if self.busy or self.closed:
            return
        self.busy = True
        self.controls()
        if label:
            self.status.set_text(label)

        def worker():
            try:
                result, error = operation(), None
            except (ConfigError, VpnError) as exc:
                result, error = None, str(exc)
            except Exception:
                result, error = None, "Operation could not finish. Restart Mx VPN and check NetworkManager."
            GLib.idle_add(finish, result, error)

        def finish(result, error):
            if self.closed:
                return False
            self.busy = False
            if error:
                self.show_status()
                if error != self.last_error:
                    self.show_error(error)
                else:
                    self.status.set_text(error)
            else:
                success(result)
            self.controls()
            return False

        threading.Thread(target=worker, daemon=True).start()

    def refresh(self, preferred=None):
        def operation():
            return self.backend.list_profiles(), self.backend.active_ids()

        def success(result):
            profiles, self.active = result
            selected = preferred or self.profiles.get_active_id()
            self.updating = True
            self.profiles.remove_all()
            for profile in profiles:
                self.profiles.append(profile.uuid, profile.name)
            if not selected or not self.profiles.set_active_id(selected):
                if profiles:
                    self.profiles.set_active(0)
            self.updating = False
            self.show_status()

        self.job(operation, success)

    def periodic_refresh(self):
        if self.closed:
            return False
        if not self.busy and not (self.error_dialog and self.error_dialog.get_visible()):
            self.refresh()
        return True

    def choose_file(self, _):
        dialog = Gtk.FileChooserDialog(
            title="Import WireGuard configuration", parent=self,
            action=Gtk.FileChooserAction.OPEN,
        )
        dialog.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Import", Gtk.ResponseType.ACCEPT)
        file_filter = Gtk.FileFilter()
        file_filter.set_name("WireGuard configurations (*.conf)")
        file_filter.add_pattern("*.conf")
        dialog.add_filter(file_filter)

        def response(chooser, response_id):
            filename = chooser.get_filename() if response_id == Gtk.ResponseType.ACCEPT else None
            chooser.destroy()
            if filename:
                self.import_file(filename)

        dialog.connect("response", response)
        self.file_chooser = dialog
        dialog.show_all()

    def import_file(self, path):
        self.job(lambda: self.backend.import_profile(path), lambda identifier: self.refresh(identifier), "Importing configuration…")

    def activate(self):
        selected = self.profiles.get_active_id()
        if selected:
            self.job(lambda: self.backend.connect(selected), lambda _: self.refresh(selected), "Connecting…")

    def deactivate(self):
        selected = self.profiles.get_active_id()
        if selected:
            self.job(lambda: self.backend.disconnect(selected), lambda _: self.refresh(selected), "Disconnecting…")


def main():
    window = Window()
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
