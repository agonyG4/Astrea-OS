#!/usr/bin/env python3
"""
Volume Popup for Waybar — estilo macOS
  • Painel principal: ícone mute | slider | % | botão mixer
  • Mixer: expande o painel (accordion), recolhe ao clicar de novo
  • Toggle: clicar de novo fecha a janela
  • Fecha ao perder o foco
  • Scroll no slider: ±10% (master) / ±5% (apps)
"""
import gi, subprocess, os, sys, threading, queue, re
from dataclasses import dataclass

# ── Kill instâncias anteriores ────────────────────────────────────────────────

def _kill_siblings():
    script = os.path.basename(__file__)
    try:
        pids = subprocess.check_output(
            ["pgrep", "-f", script], stderr=subprocess.DEVNULL
        ).decode().split()
        cur = str(os.getpid())
        for p in pids:
            if p != cur:
                subprocess.run(["kill", p], check=False)
        if len(pids) > 1:
            sys.exit(0)
    except subprocess.CalledProcessError:
        pass

_kill_siblings()

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

# ── Constantes ────────────────────────────────────────────────────────────────

VOLUME_ICONS = ("󰝟", "󰕿", "󰖀", "󰕾")   # muted, low, mid, high
MIXER_ICON_OPEN   = "󰅃"
MIXER_ICON_CLOSED = "󰍜"
APP_NAME_MAX_LEN  = 13

APP_ICONS = {
    "firefox": "󰈹", "chrome": "󰊯", "chromium": "󰊯",
    "spotify": "󰓇", "discord": "󰙯", "telegram": "󰔁",
    "mpv": "󰎁", "vlc": "󰕼", "rhythmbox": "󰎇",
    "steam": "󰓓", "obs": "󰐙", "zoom": "󰤽",
    "slack": "󰒱", "teams": "󰊻", "thunderbird": "󰇮",
}

HIDDEN_APPS: frozenset[str] = frozenset({"sdl application", "mpv"})

# ── Audio helpers ─────────────────────────────────────────────────────────────

def _run(cmd, *, capture=True):
    try:
        if capture:
            return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode()
        subprocess.Popen(cmd, stderr=subprocess.DEVNULL)
    except Exception:
        pass
    return ""

def _wpctl(*args): return _run(["wpctl", *args])
def _pactl(*args):  return _run(["pactl",  *args])


class _VolumeWorker:
    """Fila de tamanho 1 para enviar comandos de volume sem bloquear a UI."""
    def __init__(self):
        self._q   = queue.Queue(maxsize=1)
        self._thr = threading.Thread(target=self._loop, daemon=True)
        self._thr.start()

    def send(self, cmd):
        try:
            self._q.get_nowait()          # descarta comando pendente
        except queue.Empty:
            pass
        self._q.put(cmd)

    def _loop(self):
        while True:
            cmd = self._q.get()
            try:
                subprocess.run(cmd, stderr=subprocess.DEVNULL)
            except Exception:
                pass

_vol_worker = _VolumeWorker()


def get_volume_state():
    out = _wpctl("get-volume", "@DEFAULT_AUDIO_SINK@")
    parts = out.split()
    if len(parts) < 2:
        return 50, False
    return int(float(parts[1]) * 100), "[MUTED]" in out

def set_volume(val: int):
    _vol_worker.send(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                      f"{max(0, min(100, val))}%"])

def toggle_mute():
    _wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", "toggle")

def volume_icon(vol: int, muted: bool) -> str:
    if muted or vol == 0: return VOLUME_ICONS[0]
    if vol < 34:          return VOLUME_ICONS[1]
    if vol < 67:          return VOLUME_ICONS[2]
    return VOLUME_ICONS[3]

def app_icon(name: str) -> str:
    n = name.lower()
    return next((icon for key, icon in APP_ICONS.items() if key in n), "󰓃")

def truncate(text: str, max_len: int = APP_NAME_MAX_LEN) -> str:
    return text if len(text) <= max_len else text[: max_len - 1] + "…"


@dataclass
class SinkInput:
    index:  str
    name:   str
    vol:    int
    muted:  bool


def get_sink_inputs() -> list:
    out = _pactl("list", "sink-inputs")
    inputs = []
    current = None

    for line in out.splitlines():
        line = line.strip()
        if m := re.match(r"^Sink Input #(\d+)", line):
            if current:
                inputs.append(SinkInput(**current))
            current = {"index": m.group(1), "name": "?", "vol": 100, "muted": False}
            continue
        if current is None:
            continue
        if line.startswith("Mute:"):
            current["muted"] = "yes" in line.lower()
        elif line.startswith("Volume:"):
            if m2 := re.search(r"(\d+)%", line):
                current["vol"] = int(m2.group(1))
        elif line.startswith("application.name"):
            if m3 := re.search(r'= "(.+)"', line):
                current["name"] = m3.group(1)
        elif line.startswith("media.name") and current.get("name") in ("?", ""):
            if m3 := re.search(r'= "(.+)"', line):
                current["name"] = m3.group(1)

    if current:
        inputs.append(SinkInput(**current))

    return [i for i in inputs if i.name.lower() not in HIDDEN_APPS]

def set_sink_input_volume(index, val):
    _vol_worker.send(["pactl", "set-sink-input-volume", index,
                      f"{max(0, min(150, val))}%"])

def toggle_sink_input_mute(index):
    _run(["pactl", "set-sink-input-mute", index, "toggle"], capture=False)

# ── CSS ───────────────────────────────────────────────────────────────────────

CSS = """
window {
    background-color: transparent;
    margin: 0; padding: 0;
}

#shell {
    background: rgba(28, 28, 38, 0.88);
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.10);
}

#top-row { padding: 8px 14px; }

#mixer-sep-top {
    background: rgba(255,255,255,0.08);
    min-height: 1px;
    margin: 0 14px;
}

#mixer-area { padding: 8px 14px 12px 14px; }

/* ── Mute master ── */
#mute-btn {
    background: rgba(255,255,255,0.10);
    border: none; border-radius: 50%;
    padding: 0; min-width: 28px; min-height: 28px;
    color: rgba(255,255,255,0.65); font-size: 15px; margin-right: 6px;
}
#mute-btn:hover { background: rgba(255,255,255,0.18); color: white; }
#mute-btn.muted { background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.25); }

/* ── Slider master ── */
scale { min-width: 200px; margin: 0 6px; }
scale contents trough {
    background: rgba(255,255,255,0.18);
    border-radius: 999px; min-height: 5px; min-width: 4px;
}
scale contents trough:hover { background: rgba(255,255,255,0.26); }
scale contents highlight {
    background: white; border-radius: 999px; min-width: 4px;
}
scale.muted contents trough    { background: rgba(255,255,255,0.10); }
scale.muted contents highlight { background: rgba(255,255,255,0.18); min-width: 0; }
scale contents slider {
    background: white; border-radius: 50%;
    min-width: 17px; min-height: 17px; margin: -6px 0;
}
scale contents slider:hover { min-width: 21px; min-height: 21px; }

/* ── % master ── */
#vol-pct {
    font-size: 12px; font-weight: 600;
    color: rgba(255,255,255,0.45); min-width: 32px;
}
#vol-pct.muted { color: rgba(255,255,255,0.20); }

/* ── Botão mixer ── */
#mixer-btn {
    background: rgba(255,255,255,0.10); border: none;
    border-radius: 50%; min-width: 28px; min-height: 28px;
    padding: 0; color: rgba(255,255,255,0.55);
    font-size: 13px; margin-left: 6px;
}
#mixer-btn:hover  { background: rgba(255,255,255,0.18); color: white; }
#mixer-btn.active { background: rgba(255,255,255,0.15); color: white; }

/* ── Título seção mixer ── */
#mixer-title {
    font-size: 10px; font-weight: 700;
    letter-spacing: 1px; color: rgba(255,255,255,0.28);
    margin-bottom: 6px;
}

#mixer-empty {
    font-size: 12px; color: rgba(255,255,255,0.30); padding: 6px 0;
}

/* ── App row ── */
#app-row { padding: 3px 0; }

#app-icon       { font-size: 14px; color: rgba(255,255,255,0.50); min-width: 20px; }
#app-icon.muted { color: rgba(255,255,255,0.18); }

#app-name       { font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.55); min-width: 80px; }
#app-name.muted { color: rgba(255,255,255,0.22); }

#app-pct       { font-size: 10px; color: rgba(255,255,255,0.30); min-width: 32px; }
#app-pct.muted { color: rgba(255,255,255,0.15); }

#app-scale { min-width: 120px; margin: 0 4px; }
#app-scale contents trough {
    background: rgba(255,255,255,0.12); border-radius: 999px; min-height: 3px;
}
#app-scale contents trough:hover { background: rgba(255,255,255,0.20); }
#app-scale contents highlight {
    background: rgba(255,255,255,0.70); border-radius: 999px;
}
#app-scale.muted contents highlight { background: rgba(255,255,255,0.12); }
#app-scale contents slider {
    background: white; border-radius: 50%;
    min-width: 11px; min-height: 11px; margin: -4px 0;
}
#app-scale contents slider:hover { min-width: 14px; min-height: 14px; }

#app-mute-btn {
    background: transparent; border: none; border-radius: 50%;
    padding: 0; min-width: 20px; min-height: 20px;
    color: rgba(255,255,255,0.30); font-size: 12px; margin-left: 2px;
}
#app-mute-btn:hover { color: white; background: rgba(255,255,255,0.10); }
#app-mute-btn.muted { color: rgba(255,255,255,0.15); }

#app-sep { background: rgba(255,255,255,0.06); min-height: 1px; margin: 2px 0; }
"""

# ── Helpers de UI ─────────────────────────────────────────────────────────────

def _make_icon_button(icon: str, name: str) -> tuple[Gtk.Button, Gtk.Label]:
    lbl = Gtk.Label(label=icon)
    btn = Gtk.Button()
    btn.set_name(name)
    btn.set_relief(Gtk.ReliefStyle.NONE)
    btn.add(lbl)
    return btn, lbl

def _sc(widget: Gtk.Widget) -> Gtk.StyleContext:
    return widget.get_style_context()

def _toggle_class(widget: Gtk.Widget, css_class: str, active: bool):
    (_sc(widget).add_class if active else _sc(widget).remove_class)(css_class)

def _scroll_delta(event: Gdk.EventScroll) -> int | None:
    """Retorna delta ±1 para scroll events. None se irrelevante."""
    if event.direction == Gdk.ScrollDirection.UP:     return  1
    if event.direction == Gdk.ScrollDirection.DOWN:   return -1
    if event.direction == Gdk.ScrollDirection.SMOOTH:
        _, _dx, dy = event.get_scroll_deltas()
        return None if abs(dy) < 0.1 else (-1 if dy > 0 else 1)
    return None

# ── Popup ─────────────────────────────────────────────────────────────────────

class VolumePopup(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_title("Volume")
        self._updating   = False
        self._mixer_open = False

        self.set_decorated(False)
        self.set_app_paintable(True)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)

        # Layer Shell
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP,   5)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 16)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.connect("destroy",         lambda *_: Gtk.main_quit())
        self.connect("focus-out-event", self._on_focus_out)
        self.connect("focus-in-event",  self._on_focus_in)
        self.connect("draw",            self._on_draw)
        self._close_timer = None

        # RGBA visual (transparência real)
        screen = Gdk.Screen.get_default()
        if visual := screen.get_rgba_visual():
            self.set_visual(visual)

        # CSS global
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self._build_ui()
        self.show_all()
        self._mixer_area.hide()
        self._sep_top.hide()
        self._load_state()

        # Remove sombra nativa após realize
        self.connect("realize", lambda w: GLib.idle_add(self._strip_shadow))

    # ── Foco / timer de fechamento ────────────────────────────────────────────

    def _on_focus_out(self, *_):
        if self._close_timer is None:
            self._close_timer = GLib.timeout_add(1000, self._close_if_unfocused)

    def _on_focus_in(self, *_):
        if self._close_timer is not None:
            GLib.source_remove(self._close_timer)
            self._close_timer = None

    def _close_if_unfocused(self):
        self._close_timer = None
        Gtk.main_quit()
        return False  # não repete

    # ── Janela ────────────────────────────────────────────────────────────────

    def _strip_shadow(self):
        if gdk_win := self.get_window():
            gdk_win.set_shadow_width(0, 0, 0, 0)
        return False

    def _on_draw(self, _widget, cr):
        cr.save()
        cr.set_operator(3)  # OPERATOR_CLEAR
        cr.paint()
        cr.restore()
        return False

    # ── Construção da UI ──────────────────────────────────────────────────────

    def _build_ui(self):
        shell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        shell.set_name("shell")
        self.add(shell)
        self._shell = shell

        # Linha principal
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        top.set_name("top-row")
        shell.pack_start(top, False, False, 0)

        self._mute_btn, self._mute_icon = _make_icon_button("󰕾", "mute-btn")
        self._mute_btn.connect("clicked", self._on_mute_click)
        top.pack_start(self._mute_btn, False, False, 0)

        self._slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self._slider.set_draw_value(False)
        self._slider.set_increments(1, 10)
        self._slider.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK)
        self._slider.connect("value-changed", self._on_slider_change)
        self._slider.connect("scroll-event",  self._on_master_scroll)
        top.pack_start(self._slider, True, True, 0)

        self._pct_label = Gtk.Label(label="50%")
        self._pct_label.set_name("vol-pct")
        self._pct_label.set_xalign(1)
        top.pack_start(self._pct_label, False, False, 6)

        self._mixer_btn, self._mixer_icon = _make_icon_button(MIXER_ICON_CLOSED, "mixer-btn")
        self._mixer_btn.connect("clicked", self._on_mixer_click)
        top.pack_start(self._mixer_btn, False, False, 0)

        # Separador
        self._sep_top = Gtk.Box()
        self._sep_top.set_name("mixer-sep-top")
        shell.pack_start(self._sep_top, False, False, 0)

        # Área mixer (accordion)
        self._mixer_area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self._mixer_area.set_name("mixer-area")
        shell.pack_start(self._mixer_area, False, False, 0)

        title = Gtk.Label(label="MIXER")
        title.set_name("mixer-title")
        title.set_xalign(0)
        self._mixer_area.pack_start(title, False, False, 0)

        self._apps_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self._mixer_area.pack_start(self._apps_box, False, False, 0)

    # ── Volume master ─────────────────────────────────────────────────────────

    def _load_state(self):
        vol, muted = get_volume_state()
        self._updating = True
        self._slider.set_value(vol)
        self._updating = False
        self._apply_master_ui(vol, muted)

    def _apply_master_ui(self, vol: int, muted: bool):
        vm = muted or vol == 0
        self._mute_icon.set_text(volume_icon(vol, muted))
        self._pct_label.set_text(f"{vol}%")
        for w in (self._mute_btn, self._pct_label, self._slider):
            _toggle_class(w, "muted", vm)

    def _on_slider_change(self, slider: Gtk.Scale):
        if self._updating:
            return
        val = int(slider.get_value())
        _, muted = get_volume_state()
        self._apply_master_ui(val, muted)
        set_volume(val)

    def _on_mute_click(self, *_):
        toggle_mute()
        vol, muted = get_volume_state()
        self._updating = True
        self._slider.set_value(vol)
        self._updating = False
        self._apply_master_ui(vol, muted)

    def _on_master_scroll(self, _widget, event: Gdk.EventScroll):
        if (d := _scroll_delta(event)) is None:
            return True
        nv = max(0, min(100, int(self._slider.get_value()) + d * 10))
        self._updating = True
        self._slider.set_value(nv)
        self._updating = False
        _, muted = get_volume_state()
        self._apply_master_ui(nv, muted)
        set_volume(nv)
        return True

    # ── Mixer accordion ───────────────────────────────────────────────────────

    def _on_mixer_click(self, *_):
        self._mixer_open = not self._mixer_open
        if self._mixer_open:
            self._populate_mixer()
            self._sep_top.show()
            self._mixer_area.show_all()
            self._mixer_icon.set_text(MIXER_ICON_OPEN)
            _sc(self._mixer_btn).add_class("active")
        else:
            self._mixer_area.hide()
            self._sep_top.hide()
            self._mixer_icon.set_text(MIXER_ICON_CLOSED)
            _sc(self._mixer_btn).remove_class("active")

    def _populate_mixer(self):
        for child in self._apps_box.get_children():
            self._apps_box.remove(child)

        inputs = get_sink_inputs()
        if not inputs:
            lbl = Gtk.Label(label="Nenhum app reproduzindo áudio")
            lbl.set_name("mixer-empty")
            self._apps_box.pack_start(lbl, False, False, 0)
            return

        for i, inp in enumerate(inputs):
            if i > 0:
                sep = Gtk.Box()
                sep.set_name("app-sep")
                self._apps_box.pack_start(sep, False, False, 0)
            self._apps_box.pack_start(self._make_app_row(inp), False, False, 0)

    def _make_app_row(self, inp: SinkInput) -> Gtk.Box:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        row.set_name("app-row")

        # Ícone do app
        icon_lbl = Gtk.Label(label=app_icon(inp.name))
        icon_lbl.set_name("app-icon")
        _toggle_class(icon_lbl, "muted", inp.muted)
        row.pack_start(icon_lbl, False, False, 0)

        # Nome
        name_lbl = Gtk.Label(label=truncate(inp.name))
        name_lbl.set_name("app-name")
        name_lbl.set_xalign(0)
        _toggle_class(name_lbl, "muted", inp.muted)
        row.pack_start(name_lbl, False, False, 0)

        # % do app
        pct_lbl = Gtk.Label(label=f"{inp.vol}%")
        pct_lbl.set_name("app-pct")
        pct_lbl.set_xalign(1)
        _toggle_class(pct_lbl, "muted", inp.muted)

        # Slider do app
        slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
        slider.set_name("app-scale")
        slider.set_draw_value(False)
        slider.set_increments(1, 5)
        slider.set_value(inp.vol)
        slider.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK)
        _toggle_class(slider, "muted", inp.muted)

        # Estado local do slider para evitar reentrância
        guard = [False]

        def on_vol_change(s: Gtk.Scale):
            if guard[0]: return
            v = int(s.get_value())
            pct_lbl.set_text(f"{v}%")
            set_sink_input_volume(inp.index, v)

        def on_app_scroll(_w, ev: Gdk.EventScroll):
            if (d := _scroll_delta(ev)) is None:
                return True
            nv = max(0, min(150, int(slider.get_value()) + d * 5))
            guard[0] = True
            slider.set_value(nv)
            guard[0] = False
            pct_lbl.set_text(f"{nv}%")
            set_sink_input_volume(inp.index, nv)
            return True

        slider.connect("value-changed", on_vol_change)
        slider.connect("scroll-event",  on_app_scroll)

        row.pack_start(slider,  True,  True,  0)
        row.pack_start(pct_lbl, False, False, 0)

        # Botão mute por app
        mute_btn, mute_icon = _make_icon_button(
            "󰝟" if inp.muted else "󰕾", "app-mute-btn"
        )
        _toggle_class(mute_btn, "muted", inp.muted)

        def on_app_mute(_b):
            toggle_sink_input_mute(inp.index)
            # Re-lê o estado real do sink input
            for si in get_sink_inputs():
                if si.index == inp.index:
                    m = si.muted
                    mute_icon.set_text("󰝟" if m else "󰕾")
                    for w in (mute_btn, slider, icon_lbl, name_lbl, pct_lbl):
                        _toggle_class(w, "muted", m)
                    break

        mute_btn.connect("clicked", on_app_mute)
        row.pack_start(mute_btn, False, False, 0)

        return row


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    VolumePopup()
    Gtk.main()