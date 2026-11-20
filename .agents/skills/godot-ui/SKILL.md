---
name: godot-ui
description: Build or debug Godot 4.7 HUDs, menus, pause screens, dialogs, themes, responsive game layouts, and keyboard or controller navigation.
---

# Godot 4.7 game UI

## Layout and presentation

- Use a `Control` root for screens and a `CanvasLayer` for HUDs that stay fixed while the world camera moves. Use anchors and offsets for viewport placement. Inside a `Container`, use size flags, minimum sizes, and theme separation because the container recalculates its children's layout.
- Check the project's base viewport size and stretch settings before choosing dimensions. With the current `canvas_items` and `expand` settings, test at the intended aspect ratio and at narrower and wider sizes. Check small windows and long labels where they can occur.
- Reuse the project's `Theme` resources for typography, spacing, and control states. Keep objective, status, and action labels legible over the actual game background. Set `offset_transform_enabled` before animating a container-managed control with Godot 4.7's offset transform properties. Keep `offset_transform_visual_only` enabled for purely visual motion and check pointer targeting if it should follow the control.

## Input and screen state

- Use built-in controls and their signals for ordinary interactions. For custom pointer interaction, use `_gui_input()` and call `accept_event()` when handled. Set decorative overlays to `MOUSE_FILTER_IGNORE` when they should let pointer input through.
- Give each screen a sensible initial focus, visible focus styling, and a focus order that works with the supported keyboard and controller actions. Set explicit neighbors where automatic navigation is ambiguous. Set focus after showing a dialog and restore it to the invoking control on close if it still exists.
- For a menu that pauses the tree, set the menu branch to `PROCESS_MODE_WHEN_PAUSED` or `PROCESS_MODE_ALWAYS` according to when it needs input. Ensure closing or leaving the screen restores the intended pause state and that gameplay does not also react to menu input.
- Run the affected scene and exercise open, navigate, confirm, cancel, and reopen with the supported devices. Check focus after hiding controls and verify that passive HUD elements allow interaction with the world.

See [Control](https://docs.godotengine.org/en/4.7/classes/class_control.html), [GUI navigation](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_navigation.html), and the [4.7 release notes](https://godotengine.org/releases/4.7/).
