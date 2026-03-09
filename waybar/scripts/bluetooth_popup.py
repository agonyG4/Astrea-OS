#!/usr/bin/env python3
import gi
import subprocess
import os
import sys
import threading
import re

# ── Toggle: se já estiver rodando, fecha e sai ────────────────────────────────
try:
    script_name = os.path.basename(__file__)
    output = subprocess.check_output(["pgrep", "-f", script_name]).decode().split()
    current_pid = str(os.getpid())
    others = [p for p in output if p != current_pid]
    if others:
        for pid in others:
            subprocess.run(["kill", pid])
        sys.exit(0)
except Exception:
    pass

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

# ── Helpers bluetoothctl ──────────────────────────────────────────────────────

def bt_run(*args, timeout=5):
    try:
        return subprocess.check_output(
            ["bluetoothctl"] + list(args),
            stderr=subprocess.DEVNULL,
            timeout=timeout
        ).decode()
    except Exception:
        return ""

def bt_is_powered():
    return "Powered: yes" in bt_run("show")

def bt_set_power(on: bool):
    bt_run("power", "on" if on else "off", timeout=5)

def _is_mac_like(s):
    return bool(re.fullmatch(r"[0-9A-Fa-f]{2}[:\-]([0-9A-Fa-f]{2}[:\-]){4}[0-9A-Fa-f]{2}", s.strip()))

def _get_device_info(mac):
    raw = bt_run("info", mac)
    name = None
    paired = bonded = trusted = connected = False
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("Alias:") and not name:
            alias_val = line.split(":", 1)[1].strip()
            if not _is_mac_like(alias_val):
                name = alias_val
        elif line == "Paired: yes":
            paired = True
        elif line == "Bonded: yes":
            bonded = True
        elif line == "Trusted: yes":
            trusted = True
        elif line == "Connected: yes":
            connected = True
    return {
        "name": name,
        "paired": paired,
        "bonded": bonded,
        "trusted": trusted,
        "connected": connected,
    }

def bt_get_all_devices():
    """Return (paired_list, nearby_list) — both as (mac, name, connected, paired) tuples."""
    out = bt_run("devices")
    paired = []
    nearby = []
    seen = set()
    for line in out.splitlines():
        m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.*)", line)
        if not m:
            continue
        mac = m.group(1)
        if mac in seen:
            continue
        seen.add(mac)
        info = _get_device_info(mac)
        display_name = info["name"]
        if not display_name or _is_mac_like(display_name):
            continue  # Skip devices with no real name (garbage cache entries)
        if info["paired"] or info["bonded"]:
            paired.append((mac, display_name, info["connected"], True))
        else:
            nearby.append((mac, display_name, False, False))
    return paired, nearby

def bt_connect(mac):
    """Connect and trust. Returns (success, message)."""
    # Trust first so it auto-connects in future
    bt_run("trust", mac, timeout=5)
    out = bt_run("connect", mac, timeout=20)
    if "Connection successful" in out or "Connected: yes" in out or "org.bluez.Error" not in out:
        return True, "Conectado"
    return False, "Falha ao conectar"

def bt_disconnect(mac):
    bt_run("disconnect", mac, timeout=10)

def bt_pair(mac):
    """Pair, trust, connect."""
    bt_run("pair", mac, timeout=15)
    bt_run("trust", mac, timeout=5)
    bt_run("connect", mac, timeout=15)

# ── Popup ─────────────────────────────────────────────────────────────────────

class BluetoothPopup(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_title("Bluetooth")
        self._scanning = False
        self._scan_proc = None          # subprocess for scan on
        self._refresh_timer_id = None
        self._powered = bt_is_powered()

        # ── Layer Shell ──
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 10)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 55)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.connect("destroy", self._on_destroy)
        self.connect("focus-out-event", self._on_focus_out)

        self.apply_css()
        self._build_ui()
        self.show_all()

        # Initial device load
        self._refresh_devices()

        # If powered, start scan immediately
        if self._powered:
            GLib.idle_add(self._start_scan)

    # ── CSS ───────────────────────────────────────────────────────────────────

    def apply_css(self):
        screen = Gdk.Screen.get_default()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        provider = Gtk.CssProvider()
        css = """
        window { background-color: transparent; }

        #bt-panel {
            background: rgba(22, 22, 26, 0.96);
            border: 1px solid rgba(255,255,255,0.10);
            border-radius: 20px;
            padding: 20px 20px 16px 20px;
            min-width: 290px;
            box-shadow: 0 12px 48px rgba(0,0,0,0.65);
        }

        /* Header */
        #bt-icon { font-size: 22px; color: #007aff; }
        #bt-title {
            font-size: 15px; font-weight: 700;
            color: rgba(255,255,255,0.95);
        }
        #bt-subtitle {
            font-size: 11px; color: rgba(255,255,255,0.38);
            margin-top: 1px;
        }

        /* Switch */
        switch {
            background: rgba(255,255,255,0.14);
            border-radius: 100px;
            min-width: 44px; min-height: 24px;
            border: none; outline: none;
            transition: background 180ms ease;
        }
        switch:checked { background: #007aff; }
        switch slider {
            background: white; border-radius: 100px;
            min-width: 20px; min-height: 20px; margin: 2px;
            box-shadow: 0 1px 4px rgba(0,0,0,0.45);
        }

        /* Scan bar */
        #scan-bar {
            margin-top: 6px;
            margin-bottom: 4px;
        }
        #scan-label {
            font-size: 11px; color: rgba(255,255,255,0.40);
        }

        /* Separator */
        separator {
            background: rgba(255,255,255,0.08);
            min-height: 1px;
            margin-top: 12px;
            margin-bottom: 10px;
        }

        /* Section label */
        #section-title {
            font-size: 10px; font-weight: 600;
            color: rgba(255,255,255,0.28);
            letter-spacing: 1px;
            margin-bottom: 4px;
            margin-top: 8px;
        }

        /* Device row */
        #device-row {
            border-radius: 10px;
            padding: 8px 10px;
            margin-bottom: 3px;
        }
        #device-row:hover { background: rgba(255,255,255,0.06); }
        #device-name {
            font-size: 13px; color: rgba(255,255,255,0.88);
            font-weight: 500;
        }
        #device-status { font-size: 11px; color: rgba(255,255,255,0.35); }
        #device-icon { font-size: 16px; color: rgba(255,255,255,0.22); }
        #device-icon.connected { color: #007aff; }

        /* Buttons */
        #connect-btn {
            background: rgba(0,122,255,0.18);
            color: #007aff;
            border: none; border-radius: 8px;
            padding: 4px 10px;
            font-size: 11px; font-weight: 600;
            transition: background 120ms;
        }
        #connect-btn:hover { background: rgba(0,122,255,0.30); }
        #connect-btn:disabled { opacity: 0.45; }

        #disconnect-btn {
            background: rgba(255,255,255,0.07);
            color: rgba(255,255,255,0.45);
            border: none; border-radius: 8px;
            padding: 4px 10px;
            font-size: 11px; font-weight: 600;
            transition: background 120ms;
        }
        #disconnect-btn:hover { background: rgba(255,59,48,0.20); color: #ff3b30; }
        #disconnect-btn:disabled { opacity: 0.45; }

        #pair-btn {
            background: rgba(52,199,89,0.15);
            color: #34c759;
            border: none; border-radius: 8px;
            padding: 4px 10px;
            font-size: 11px; font-weight: 600;
            transition: background 120ms;
        }
        #pair-btn:hover { background: rgba(52,199,89,0.28); }

        /* Empty / status */
        #status-label {
            font-size: 12px; color: rgba(255,255,255,0.28);
            margin: 10px 0 6px 0;
        }

        /* Refresh btn */
        #refresh-btn {
            background: transparent;
            color: rgba(255,255,255,0.30);
            border: none; border-radius: 6px;
            padding: 0 4px;
            font-size: 15px; font-weight: 700;
            transition: color 120ms;
        }
        #refresh-btn:hover { color: #007aff; }
        """
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    # ── UI ────────────────────────────────────────────────────────────────────

    def _build_ui(self):
        self.panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.panel.set_name("bt-panel")
        self.add(self.panel)

        # Header row: icon + title + switch
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        self._icon_lbl = Gtk.Label(label="󰂯")
        self._icon_lbl.set_name("bt-icon")
        title_row.pack_start(self._icon_lbl, False, False, 0)

        title = Gtk.Label(label="Bluetooth")
        title.set_name("bt-title")
        title_row.pack_start(title, False, False, 0)
        left.pack_start(title_row, False, False, 0)

        self._subtitle = Gtk.Label(label="")
        self._subtitle.set_name("bt-subtitle")
        self._subtitle.set_xalign(0)
        left.pack_start(self._subtitle, False, False, 0)
        header.pack_start(left, True, True, 0)

        self._power_switch = Gtk.Switch()
        self._power_switch.set_valign(Gtk.Align.CENTER)
        self._power_switch.set_active(self._powered)
        self._power_switch.connect("state-set", self._on_power_toggled)
        header.pack_end(self._power_switch, False, False, 0)
        self.panel.pack_start(header, False, False, 0)

        # Scan bar (spinner + label)
        self._scan_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self._scan_bar.set_name("scan-bar")
        self._scan_spinner = Gtk.Spinner()
        self._scan_bar.pack_start(self._scan_spinner, False, False, 0)
        self._scan_label = Gtk.Label(label="Procurando dispositivos…")
        self._scan_label.set_name("scan-label")
        self._scan_label.set_xalign(0)
        self._scan_bar.pack_start(self._scan_label, True, True, 0)
        self.panel.pack_start(self._scan_bar, False, False, 0)
        self._scan_bar.set_visible(False)

        # Separator
        self.panel.pack_start(Gtk.Separator(), False, False, 0)

        # Devices section header
        dev_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        sec = Gtk.Label(label="DISPOSITIVOS")
        sec.set_name("section-title")
        sec.set_xalign(0)
        dev_header.pack_start(sec, True, True, 0)

        refresh_btn = Gtk.Button(label="↻")
        refresh_btn.set_name("refresh-btn")
        refresh_btn.connect("clicked", lambda *_: self._refresh_devices())
        dev_header.pack_end(refresh_btn, False, False, 0)
        self.panel.pack_start(dev_header, False, False, 0)

        # Device list (scrollable)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(300)
        scroll.set_propagate_natural_height(True)
        self._device_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        scroll.add(self._device_list)
        self.panel.pack_start(scroll, False, False, 0)

        self._update_header_state(self._powered)

    # ── Power ─────────────────────────────────────────────────────────────────

    def _on_power_toggled(self, switch, state):
        self._powered = state
        self._power_switch.set_sensitive(False)

        def _do():
            bt_set_power(state)
            GLib.idle_add(self._power_switch.set_sensitive, True)
            GLib.idle_add(self._update_header_state, state)
            GLib.idle_add(self._refresh_devices)
            if state:
                GLib.idle_add(self._start_scan)
            else:
                GLib.idle_add(self._stop_scan)

        threading.Thread(target=_do, daemon=True).start()

    def _update_header_state(self, powered):
        if powered:
            self._subtitle.set_text("Ligado")
            self._icon_lbl.set_text("󰂯")
        else:
            self._subtitle.set_text("Desligado")
            self._icon_lbl.set_text("󰂲")

    # ── Scan ──────────────────────────────────────────────────────────────────

    def _start_scan(self):
        if self._scanning:
            return
        self._scanning = True
        self._scan_bar.set_visible(True)
        self._scan_spinner.start()

        # Start scan in background (long-running)
        self._scan_proc = subprocess.Popen(
            ["bluetoothctl", "scan", "on"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        # Refresh devices every 4 seconds while scanning
        self._refresh_timer_id = GLib.timeout_add(4000, self._scan_tick)

    def _scan_tick(self):
        """Called every 4s while scan is active to refresh device list."""
        if not self._scanning:
            return False
        self._refresh_devices()
        return True  # keep repeating

    def _stop_scan(self):
        if not self._scanning:
            return
        self._scanning = False
        self._scan_spinner.stop()
        self._scan_bar.set_visible(False)

        if self._refresh_timer_id:
            GLib.source_remove(self._refresh_timer_id)
            self._refresh_timer_id = None

        if self._scan_proc:
            try:
                self._scan_proc.terminate()
            except Exception:
                pass
            self._scan_proc = None

        # Issue scan off to bluetoothd
        threading.Thread(target=lambda: bt_run("scan", "off", timeout=3), daemon=True).start()

    # ── Devices ───────────────────────────────────────────────────────────────

    def _refresh_devices(self, *_):
        if not self._powered:
            self._set_status("Ligue o Bluetooth para ver dispositivos")
            return

        def _fetch():
            paired, nearby = bt_get_all_devices()
            GLib.idle_add(self._populate, paired, nearby)

        threading.Thread(target=_fetch, daemon=True).start()

    def _clear_list(self):
        for child in self._device_list.get_children():
            self._device_list.remove(child)

    def _set_status(self, msg):
        self._clear_list()
        lbl = Gtk.Label(label=msg)
        lbl.set_name("status-label")
        lbl.set_xalign(0)
        self._device_list.pack_start(lbl, False, False, 0)
        self._device_list.show_all()

    def _add_section(self, text):
        lbl = Gtk.Label(label=text)
        lbl.set_name("section-title")
        lbl.set_xalign(0)
        self._device_list.pack_start(lbl, False, False, 0)

    def _populate(self, paired, nearby):
        self._clear_list()

        if not paired and not nearby:
            msg = "Procurando…" if self._scanning else "Nenhum dispositivo encontrado"
            self._set_status(msg)
            return

        if paired:
            self._add_section("PAREADOS")
            for mac, name, connected, _ in paired:
                self._device_list.pack_start(
                    self._make_row(mac, name, connected, is_paired=True),
                    False, False, 0)

        if nearby:
            self._add_section("DESCOBERTOS")
            for mac, name, connected, _ in nearby:
                self._device_list.pack_start(
                    self._make_row(mac, name, connected, is_paired=False),
                    False, False, 0)

        self._device_list.show_all()

    def _make_row(self, mac, name, connected, is_paired):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.set_name("device-row")

        # Icon
        icon = Gtk.Label(label="󰂱" if connected else "󰂯")
        icon.set_name("device-icon")
        if connected:
            icon.get_style_context().add_class("connected")
        row.pack_start(icon, False, False, 0)

        # Name + status
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        name_lbl = Gtk.Label(label=name)
        name_lbl.set_name("device-name")
        name_lbl.set_xalign(0)
        name_lbl.set_ellipsize(3)
        vbox.pack_start(name_lbl, False, False, 0)

        status_text = "Conectado" if connected else ("Pareado" if is_paired else "Disponível")
        self._status_lbl = Gtk.Label(label=status_text)
        self._status_lbl.set_name("device-status")
        self._status_lbl.set_xalign(0)
        vbox.pack_start(self._status_lbl, False, False, 0)
        row.pack_start(vbox, True, True, 0)

        status_lbl = self._status_lbl  # capture local ref

        # Button
        if connected:
            btn = Gtk.Button(label="Desconectar")
            btn.set_name("disconnect-btn")
            btn.connect("clicked", self._on_disconnect_click, mac, status_lbl, icon)
        elif is_paired:
            btn = Gtk.Button(label="Conectar")
            btn.set_name("connect-btn")
            btn.connect("clicked", self._on_connect_click, mac, status_lbl, icon)
        else:
            btn = Gtk.Button(label="Parear")
            btn.set_name("pair-btn")
            btn.connect("clicked", self._on_pair_click, mac, status_lbl, icon)
        row.pack_end(btn, False, False, 0)

        return row

    # ── Actions ───────────────────────────────────────────────────────────────

    def _on_connect_click(self, btn, mac, status_lbl, icon_lbl):
        btn.set_sensitive(False)
        btn.set_label("…")
        status_lbl.set_text("Conectando…")

        def _do():
            success, msg = bt_connect(mac)
            # Wait a moment for bluetoothd to settle
            import time; time.sleep(1)
            GLib.idle_add(self._refresh_devices)

        threading.Thread(target=_do, daemon=True).start()

    def _on_disconnect_click(self, btn, mac, status_lbl, icon_lbl):
        btn.set_sensitive(False)
        btn.set_label("…")
        status_lbl.set_text("Desconectando…")

        def _do():
            bt_disconnect(mac)
            import time; time.sleep(1)
            GLib.idle_add(self._refresh_devices)

        threading.Thread(target=_do, daemon=True).start()

    def _on_pair_click(self, btn, mac, status_lbl, icon_lbl):
        btn.set_sensitive(False)
        btn.set_label("…")
        status_lbl.set_text("Pareando…")

        def _do():
            bt_pair(mac)
            import time; time.sleep(2)
            GLib.idle_add(self._refresh_devices)

        threading.Thread(target=_do, daemon=True).start()

    # ── Cleanup ───────────────────────────────────────────────────────────────

    def _on_focus_out(self, widget, event):
        self._cleanup_and_quit()

    def _on_destroy(self, widget):
        self._cleanup_and_quit()

    def _cleanup_and_quit(self, *_):
        self._stop_scan()
        try:
            Gtk.main_quit()
        except Exception:
            pass
        return True


if __name__ == "__main__":
    popup = BluetoothPopup()
    Gtk.main()
