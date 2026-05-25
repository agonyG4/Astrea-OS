#!/usr/bin/env python3
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("display_night_shift_schedule.sh")


class NightShiftScheduleTests(unittest.TestCase):
    def make_runtime(self):
        tmp = tempfile.TemporaryDirectory()
        base = Path(tmp.name)
        home = base / "home"
        root = base / "Astrea"
        services = root / "System" / "services"
        config = root / "System" / "config" / "display"
        bin_dir = base / "bin"
        services.mkdir(parents=True)
        config.mkdir(parents=True)
        bin_dir.mkdir()
        home.mkdir()

        (config / "monitor-settings.conf").write_text(
            "\n".join(
                [
                    "night_shift_schedule=1",
                    "night_shift_strength=35",
                    "night_shift_start=21:30",
                    "night_shift_end=08:00",
                ]
            )
            + "\n"
        )

        color_script = services / "display_night_shift_color.sh"
        color_script.write_text(
            "#!/bin/sh\n"
            "mkdir -p \"$(dirname \"$NIGHT_SHIFT_LOG\")\"\n"
            "printf '%s %s\\n' \"$1\" \"${2:-}\" >>\"$NIGHT_SHIFT_LOG\"\n"
        )
        color_script.chmod(color_script.stat().st_mode | stat.S_IXUSR)

        date_script = bin_dir / "date"
        date_script.write_text(
            "#!/bin/sh\n"
            "case \"$1\" in\n"
            "  +%H) printf '21\\n' ;;\n"
            "  +%M) printf '30\\n' ;;\n"
            "  *) exec /usr/bin/date \"$@\" ;;\n"
            "esac\n"
        )
        date_script.chmod(date_script.stat().st_mode | stat.S_IXUSR)

        systemctl_script = bin_dir / "systemctl"
        systemctl_script.write_text("#!/bin/sh\nexit 0\n")
        systemctl_script.chmod(systemctl_script.stat().st_mode | stat.S_IXUSR)

        return tmp, home, root, bin_dir

    def run_script(self, home, root, bin_dir, log_path, action="apply"):
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(home),
                "ASTREA_ROOT": str(root),
                "NIGHT_SHIFT_LOG": str(log_path),
                "PATH": f"{bin_dir}:{env['PATH']}",
            }
        )
        return subprocess.run(
            [str(SCRIPT), action],
            env=env,
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )

    def run_schedule(self, home, root, bin_dir, log_path):
        return self.run_script(home, root, bin_dir, log_path, "apply")

    def test_reapplies_active_schedule_when_cached_state_is_from_previous_boot(self):
        tmp, home, root, bin_dir = self.make_runtime()
        with tmp:
            state_dir = home / ".local" / "state" / "Astrea" / "display"
            state_dir.mkdir(parents=True)
            (state_dir / "night-shift-state").write_text("on:5160\n")
            log_path = home / "night-shift.log"

            result = self.run_schedule(home, root, bin_dir, log_path)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log_path.read_text(), "on 35\n")

    def test_installed_timer_uses_schedule_transitions_instead_of_polling(self):
        tmp, home, root, bin_dir = self.make_runtime()
        with tmp:
            log_path = home / "night-shift.log"

            result = self.run_script(home, root, bin_dir, log_path, "install")

            self.assertEqual(result.returncode, 0, result.stderr)
            timer_path = home / ".config" / "systemd" / "user" / "astrea-night-shift.timer"
            timer_text = timer_path.read_text()
            self.assertIn("OnBootSec=20s", timer_text)
            self.assertIn("OnCalendar=*-*-* 21:30:00", timer_text)
            self.assertIn("OnCalendar=*-*-* 08:00:00", timer_text)
            self.assertNotIn("OnUnitActiveSec=5min", timer_text)
            self.assertNotIn("OnCalendar=*:0/5", timer_text)


if __name__ == "__main__":
    unittest.main()
