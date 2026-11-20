---
name: godot-gameplay
description: Build or debug Godot 4.7 gameplay such as player controls, 2D or 3D movement, collisions, interactions, scoring, game loops, and save data.
---

# Godot 4.7 gameplay

Start with the scene the player actually runs. Trace its input actions, scene instances, and gameplay state before choosing where a mechanic belongs. Use the project's existing script language and scene conventions. Check unfamiliar APIs in the [Godot 4.7 class reference](https://docs.godotengine.org/en/4.7/classes/index.html).

## Input and physics

- Use named `InputMap` actions. Poll movement in `_physics_process()` and handle discrete actions with events when a press needs to be consumed. Use `_unhandled_input()` for actions that gameplay should receive only after the UI has had a chance to handle them. Gate polled input separately when a menu owns input.
- Identify whether the mechanic moves a body, reacts to a trigger, or queries the world. For a `CharacterBody2D` or `CharacterBody3D`, set `velocity` in units per second and call `move_and_slide()` during the physics tick. Apply `delta` to acceleration and timers. `move_and_slide()` already handles conversion from velocity to motion.
- For missed collisions, check the collision shape, enabled state, and layer/mask pairing on both nodes. For triggers, check `monitoring` and whether the other object calls for a body or area signal. Defer changes to collision shapes if a physics callback runs while the engine is flushing queries.

## State and playtesting

- Put rules and state on the node or session that owns them. Have HUDs observe state via signals and read the current value when they connect. Reserve autoloads for services or state that genuinely need to outlive scene changes.
- When adding saves or settings, use `user://`. Use `ConfigFile` for settings and give evolving save formats a version plus defaults for older data. Exercise a fresh session and a reload.
- Run the normal entry scene. For changes to game flow, check that the player can start, complete or fail the loop, and retry without carrying stale state or making duplicate signal connections.

See [input events](https://docs.godotengine.org/en/4.7/tutorials/inputs/inputevent.html) and [saving games](https://docs.godotengine.org/en/4.7/tutorials/io/saving_games.html).
