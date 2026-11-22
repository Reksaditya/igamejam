import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--templates", required=True, type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    template_version = ".".join(version.split(".")[:4])
    cache = repo / ".godot" / "windows-export"
    templates = cache / "Godot" / "export_templates" / template_version
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.templates) as archive:
        supplied_version = archive.read("templates/version.txt").decode().strip()
        if supplied_version != template_version:
            raise SystemExit(f"Template {supplied_version} tidak cocok dengan engine {template_version}")
        for name in ("windows_release_x86_64.exe", "windows_debug_x86_64.exe", "version.txt"):
            with archive.open("templates/" + name) as source, (templates / name).open("wb") as target:
                shutil.copyfileobj(source, target)
    output = repo / ".godot" / "builds" / "Deadline-Windows"
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"):
        env[key] = str(cache)
    staging = cache / ("project-" + str(time.time_ns()))
    shutil.copytree(repo, staging, ignore=shutil.ignore_patterns(".git", ".godot", ".agents", ".codex", "tests", "tools", "docs"))
    imported = repo / ".godot" / "imported"
    if imported.is_dir():
        shutil.copytree(imported, staging / ".godot" / "imported")
    project_file = staging / "project.godot"
    project_file.write_text(re.sub(r'enabled=PackedStringArray\([^\n]*\)', 'enabled=PackedStringArray()', project_file.read_text(encoding="utf-8")), encoding="utf-8")
    import_path = cache / f"import-{time.time_ns()}.log"
    import_result = subprocess.run([args.godot, "--headless", "--path", str(staging), "--import", "--log-file", str(import_path)], cwd=repo, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    import_log = import_path.read_text(encoding="utf-8") if import_path.is_file() else import_result.stdout + import_result.stderr
    if import_result.returncode or "SCRIPT ERROR:" in import_log or "\nERROR:" in import_log:
        print(import_log[-6000:])
        raise SystemExit(import_result.returncode or 1)
    log_path = cache / f"export-{time.time_ns()}.log"
    command = [args.godot, "--headless", "--path", str(staging), "--export-pack", "Windows Desktop", str(output / "Deadline.pck")]
    with log_path.open("w", encoding="utf-8") as log_file:
        result = subprocess.run(command, cwd=repo, env=env, stdout=log_file, stderr=subprocess.STDOUT, timeout=240)
    log = log_path.read_text(encoding="utf-8")
    print(f"Log ekspor: {log_path}", flush=True)
    if result.returncode in (3221225477, -1073741819) and "[ DONE ]" in log and "savepack" in log and "ERROR:" not in log:
        print("Godot mengalami crash setelah penulisan paket; mengulang ekspor menggunakan cache yang telah terbentuk.", flush=True)
        log_path = cache / f"export-retry-{time.time_ns()}.log"
        with log_path.open("w", encoding="utf-8") as log_file:
            result = subprocess.run(command, cwd=repo, env=env, stdout=log_file, stderr=subprocess.STDOUT, timeout=240)
        log = log_path.read_text(encoding="utf-8")
        print(f"Log ekspor ulang: {log_path}", flush=True)
    if result.returncode or "SCRIPT ERROR:" in log or "\nERROR:" in log or "Export failed" in log:
        print(f"Kode keluar Godot: {result.returncode}")
        print(log[-6000:])
        raise SystemExit(result.returncode or 1)
    shutil.copyfile(templates / "windows_release_x86_64.exe", output / "Deadline.exe")
    for name in ("Deadline.exe", "Deadline.pck"):
        if not (output / name).is_file():
            raise SystemExit(f"Hasil ekspor tidak ditemukan: {name}")
    for temporary in output.glob("Deadline.pck*.tmp"):
        temporary.unlink()
    shutil.copyfile(repo / "docs" / "windows-build-readme.txt", output / "BACA-SAYA.txt")
    licenses = output / "licenses"
    licenses.mkdir(exist_ok=True)
    shutil.copyfile(repo / "docs" / "licenses" / "Godot.txt", licenses / "Godot.txt")
    for addon in (repo / "addons").iterdir():
        if addon.is_dir():
            for name in ("LICENSE", "LICENSE.txt"):
                source = addon / name
                if source.is_file():
                    shutil.copyfile(source, licenses / (addon.name + ".txt"))
    archive_path = shutil.make_archive(str(output), "zip", output)
    print(f"Build: {output / 'Deadline.exe'}", flush=True)
    print(f"ZIP: {archive_path}", flush=True)


if __name__ == "__main__":
    main()
