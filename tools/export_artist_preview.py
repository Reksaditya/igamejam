"""Export the Windows artist build from a disposable Godot project."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
PROFILE = "Deadline Artist Preview"
MENU = "res://scenes/preview/artist_preview.tscn"
DESKTOP = "res://scenes/interaction/desktop/desktop.tscn"
WORKSHOP = "res://scenes/interaction/workshop/transmission_workshop.tscn"
PROJECT_VIEWER = "res://scenes/interaction/desktop/project/project_app.tscn"
EXIT_DURING_EDITOR_SHUTDOWN = {3221225477, -1073741819}


def copy_project(stage):
    for directory in ("assets", "scenes/preview", "scenes/interaction/workshop",
                      "scripts/preview", "scripts/interaction/workshop"):
        shutil.copytree(PROJECT / directory, stage / directory)
    shutil.copytree(PROJECT / "scenes/interaction/desktop", stage / "scenes/interaction/desktop",
                    ignore=shutil.ignore_patterns("lms", "study", "word_explorer_home.tscn"))
    shutil.copytree(PROJECT / "scripts/interaction/desktop", stage / "scripts/interaction/desktop",
                    ignore=shutil.ignore_patterns("lms", "study"))
    for filename in (
        "scripts/autoload/game_clock.gd", "scripts/autoload/game_clock.tscn",
        "scripts/autoload/player_stats.gd", "scripts/autoload/playthrough_save.gd",
        "scripts/autoload/scene_transition.gd", "scripts/autoload/scene_transition.tscn",
    ):
        destination = stage / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / filename, destination)
        if (PROJECT / (filename + ".uid")).is_file():
            shutil.copy2(PROJECT / (filename + ".uid"), stage / (filename + ".uid"))


def set_scene_options(stage, path, script_id, settings):
    scene = stage / path.removeprefix("res://")
    source = scene.read_text(encoding="utf-8")
    anchor = f'script = ExtResource("{script_id}")\n'
    if source.count(anchor) != 1:
        raise ValueError(f"Expected one root script property in {path}")
    scene.write_text(source.replace(anchor, anchor + settings, 1), encoding="utf-8")


def configure_browser(stage):
    browser = stage / "scenes/interaction/desktop/word_explorer.tscn"
    source = browser.read_text(encoding="utf-8")
    layout = source[source.index('[node name="Layout"'):]
    browser.write_text('''[gd_scene format=3 uid="uid://dpdtl5dkg6qe1"]

[ext_resource type="Script" path="res://scripts/interaction/desktop/word_explorer.gd" id="1_app"]
[ext_resource type="PackedScene" path="res://scenes/preview/browser_home.tscn" id="2_page"]
[ext_resource type="Script" path="res://scripts/interaction/desktop/browser_route.gd" id="3_route"]
[ext_resource type="Script" path="res://scripts/interaction/desktop/browser_tab.gd" id="5_tab"]

[sub_resource type="Resource" id="Route_preview"]
script = ExtResource("3_route")
address = "preview.local"
page = ExtResource("2_page")

[sub_resource type="Resource" id="Tab_preview"]
script = ExtResource("5_tab")
title = "Home"
address = "preview.local"

[node name="WordExplorer" type="MarginContainer"]
script = ExtResource("1_app")
home_address = "preview.local"
default_tabs = Array[ExtResource("5_tab")]([SubResource("Tab_preview")])
local_routes = Array[ExtResource("3_route")]([SubResource("Route_preview")])

''' + layout, encoding="utf-8")
    (stage / "scenes/preview/browser_home.tscn").write_text('''[gd_scene format=3]

[node name="BrowserHome" type="Label"]
theme_type_variation = &"BrowserHeading"
text = "Word Explorer"
''', encoding="utf-8")


def keep_preview_dependencies(stage):
    pending = [stage / "project.godot", *(stage / path.removeprefix("res://") for path in (MENU, DESKTOP, WORKSHOP))]
    keep = set()
    while pending:
        path = pending.pop()
        if path in keep:
            continue
        keep.add(path)
        for suffix in (".uid", ".import"):
            sidecar = path.with_name(path.name + suffix)
            if sidecar.is_file():
                keep.add(sidecar)
        if path.suffix not in (".gd", ".tscn", ".tres", ".gdshader", ".godot"):
            continue
        for reference in re.findall(r'"\*?res://([^"\r\n]+)"', path.read_text(encoding="utf-8-sig")):
            dependency = (stage / reference).resolve()
            if dependency.is_relative_to(stage) and dependency.is_file():
                pending.append(dependency)
    for path in stage.rglob("*"):
        if path.is_file() and path not in keep:
            path.unlink()


def prepare(stage, template):
    copy_project(stage)
    configure_browser(stage)
    desktop = stage / DESKTOP.removeprefix("res://")
    source = desktop.read_text(encoding="utf-8")
    source = re.sub(r'^\[ext_resource [^\n]*path="res://scenes/interaction/desktop/login_screen\.tscn"[^\n]*\]\n', "", source, flags=re.MULTILINE)
    source = re.sub(r"^login_scene = [^\n]*\n", "", source, flags=re.MULTILINE)
    desktop.write_text(source, encoding="utf-8")
    set_scene_options(stage, DESKTOP, "1_desktop",
                      f'return_scene = "{MENU}"\nreturn_label = "Preview menu"\n')
    set_scene_options(stage, WORKSHOP, "1_workshop",
                      f'return_scene = "{MENU}"\nreturn_spawn = &""\nreturn_label = "Preview menu"\ndemo_blueprint = true\n')
    set_scene_options(stage, PROJECT_VIEWER, "1_app", "demo_blueprints = true\n")
    (stage / "project.godot").write_text(f'''config_version=5

[application]
config/name="{PROFILE}"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/use_custom_user_dir=true
config/custom_user_dir_name="{PROFILE}"
config/icon="res://assets/textures/icon.svg"
run/main_scene="{MENU}"

[autoload]
GameClock="*res://scripts/autoload/game_clock.tscn"
PlayerStats="*res://scripts/autoload/player_stats.gd"
ProjectBlueprints="*res://scripts/interaction/desktop/project/blueprint_progress.gd"
SceneTransition="*res://scripts/autoload/scene_transition.tscn"

[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''', encoding="utf-8")
    keep_preview_dependencies(stage)
    template_path = template.as_posix() if template else ""
    (stage / "export_presets.cfg").write_text(f'''[preset.0]
name="Artist Preview"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""

[preset.0.options]
custom_template/release={json.dumps(template_path)}
debug/export_console_wrapper=0
binary_format/embed_pck=true
binary_format/architecture="x86_64"
application/modify_resources=false
''', encoding="utf-8")


def windows_template(stage, archive):
    if not archive:
        return None
    template = stage.parent / "windows_release_x86_64.exe"
    with zipfile.ZipFile(archive) as bundle:
        version = bundle.read("templates/version.txt").decode().strip()
        if version != "4.7.2.stable":
            raise ValueError(f"Expected Godot 4.7.2 stable, got {version}")
        with bundle.open("templates/windows_release_x86_64.exe") as source, template.open("wb") as output:
            shutil.copyfileobj(source, output)
    return template


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--templates", type=Path, help="Official 4.7.2 TPZ if templates are not installed")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.is_relative_to(PROJECT) or output.suffix.lower() != ".exe":
        parser.error("Use an .exe output path outside the repository")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="deadline-artist-export-") as temporary:
        stage = Path(temporary) / "project"
        stage.mkdir()
        prepare(stage, windows_template(stage, args.templates))
        command = [str(args.godot.resolve()), "--headless", "--path", str(stage)]
        imported = subprocess.run([*command, "--import"], stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, errors="replace")
        print(imported.stdout, end="")
        if imported.returncode and imported.returncode not in EXIT_DURING_EDITOR_SHUTDOWN:
            imported.check_returncode()
        if re.search(r"(?m)^(?:SCRIPT )?ERROR:", imported.stdout):
            raise RuntimeError("Godot reported an error while importing the preview")
        candidate = Path(temporary) / output.name
        subprocess.run([*command, "--export-release", "Artist Preview", str(candidate)], check=True)
        if not candidate.is_file():
            raise FileNotFoundError(candidate)
        shutil.copy2(candidate, output)
    print(output)


if __name__ == "__main__":
    main()
