import argparse
import os
from pathlib import Path
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    args = parser.parse_args()
    if not args.godot:
        parser.error("Berikan lokasi executable Godot melalui --godot")
    repo = Path(__file__).resolve().parents[1]
    output = repo / ".godot" / "production-validation" / str(time.time_ns())
    output.mkdir(parents=True)
    tests = ["career", "academic_flow", "dorm_study", "dorm_room", "workshop_flow", "world_life", "game_save", "main_menu", "player_profile", "resolution", "mc_idle", "blueprint", "side_scroller"]
    reloads = {"academic_flow", "dorm_study", "game_save", "main_menu", "blueprint"}
    failures = []
    for name in tests:
        env = dict(os.environ)
        directory = output / name
        directory.mkdir()
        for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"):
            env[key] = str(directory)
        for reload in ([False, True] if name in reloads else [False]):
            label = name + ("_reload" if reload else "")
            command = [args.godot, "--headless", "--path", str(repo), "--script", f"res://tests/{name}_smoke.gd", "--quit-after", "3600"]
            if reload:
                command += ["--", "--reload"]
            try:
                result = subprocess.run(command, cwd=repo, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=50)
                log = result.stdout + result.stderr
                passed = result.returncode == 0 and "PASS:" in log and "SCRIPT ERROR:" not in log and "\nERROR:" not in log
            except subprocess.TimeoutExpired:
                log = "FAIL: timeout setelah 50 detik"
                passed = False
            (output / f"{label}.log").write_text(log, encoding="utf-8")
            print(("PASS " if passed else "FAIL ") + label, flush=True)
            if not passed:
                failures.append(label)
                print(log[-2500:], flush=True)
    print(f"Log: {output}", flush=True)
    print(f"Gagal: {len(failures)}", flush=True)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
