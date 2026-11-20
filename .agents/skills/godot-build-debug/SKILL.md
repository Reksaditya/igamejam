---
name: godot-build-debug
description: Debug Godot 4.7 startup, script, import, and export failures, run headless checks, profile runtime problems, or prepare a game-jam build.
---

# Godot 4.7 build and debug

Use the editor binary for the installed Godot 4.7 patch release. Point `--path` at the directory containing `project.godot`. On Windows use the console executable when available so output and exit codes reach the shell.

## Run the smallest relevant check

- Reproduce startup errors through the project's main scene, and scene-specific errors by opening or running the affected scene. Start with the first parse, dependency, or load error before chasing later failures.
- For a fresh checkout or a changed asset, run `godot --headless --path <project-dir> --import`. Review the output as well as the exit code for script, import, or resource errors.
- For a short startup check, run `godot --headless --path <project-dir> --quit-after 120`. Add `--scene res://path/to/scene.tscn` when checking a specific scene, including projects without a main scene. Use a normal graphical run for UI, rendering, audio, and interactive playtesting.
- Reproduce performance problems in the same scene and renderer before and after a change. Use the debugger and monitors to distinguish script, physics, render, and asset-loading costs. Compare the same gameplay conditions before reporting an improvement.

## Export a jam build

- Check for an existing export preset, the matching export templates, and a main scene before exporting. Keep renderer or platform settings tied to the requested target.
- Run `godot --headless --path <project-dir> --export-release "<preset name>" "<absolute output file>"`. Create the output directory first and use a new output path when preserving an existing build.
- Launch the exported build on the target platform. For a web export, serve it over HTTP and test it in a browser. Play through the changed flow and check that required files load and settings save if the game uses them.

See the [command line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) and [exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html).
