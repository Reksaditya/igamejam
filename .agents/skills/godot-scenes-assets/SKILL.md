---
name: godot-scenes-assets
description: Create and maintain Godot 4.7 scenes and resources, wire nodes and signals, fix broken scene references, or diagnose asset import problems.
---

# Godot 4.7 scenes and assets

- Inspect the owning `.tscn` and its callers before changing a scene hierarchy. Renames can affect script node lookups, exported NodePaths, scene connections, animation tracks, and inherited scene overrides. Use the editor for moves when available, or check each reference type when editing on disk.
- Instance reusable `PackedScene` resources for objects with their own behavior. Use `.tres` resources for reusable editable configuration. Loaded resources can be shared across instances. For per-instance mutation, explicitly choose local-to-scene resources or duplicate the data that needs to be private.
- Preserve scene and resource UIDs when moving existing files, including `.gd.uid` sidecars where present. Keep asset sources and their import-setting sidecars in version control where the project tracks them. Godot regenerates imported caches under `.godot/`.
- Use `ResourceLoader` or `load()` for imported assets by their `res://` path so the same code works in the editor and export. Check path capitalization even when developing on Windows.
- After changing a source asset or scene reference, let the editor scan and import, then open or instantiate the affected scene and verify the expected texture, audio, animation, or collision data. Check references from the scenes that consume it.

See the [import process](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html) and [Resource](https://docs.godotengine.org/en/4.7/classes/class_resource.html).
