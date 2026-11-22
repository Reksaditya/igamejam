extends SceneTree

const MENU := "res://scenes/ui/main_menu.tscn"
const DORM := "res://scenes/movement/dorm_room210.tscn"
const HALLWAY := "res://scenes/movement/dorm_floor2.tscn"


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--seed-stale" in args:
		await _seed_stale_user_data()
		quit()
		return

	var saves := root.get_node("GameSave")
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	var settings := root.get_node("GameSettings")

	if "--verify-reset" in args:
		assert(not saves.has_save(), "Stale save should be reset on schema upgrade")
		assert(not FileAccess.file_exists("user://tutorials.cfg"), "Stale tutorials should be wiped")
		assert(not settings.has_seen_tutorial("desktop_intro"))
		assert(not settings.has_seen_tutorial("blueprint_workshop_intro"))
		assert(clock.get_semester() == 1 and clock.get_day_in_semester() == 1)
		assert(clock.get_absolute_minutes() == 360 and clock.get_formatted_time() == "06:00")
		assert(is_equal_approx(stats.get_energy(), 100.0))
		assert(is_equal_approx(stats.get_sanity(), 40.0))
		assert(is_equal_approx(stats.get_gpa(), 0.0))
		assert(FileAccess.file_exists("user://settings.cfg"), "User settings must be preserved")
		assert(is_equal_approx(settings.master_volume, 0.42))
		assert(settings.resolution_index == 1)
		print("PASS: stale schema auto-reset preserves settings and restores Sem 1 Day 1 06:00 defaults")

	# 1. Main Menu layout, logo, icons, fade-in, semi-float, and hover/focus color shift
	change_scene_to_file(MENU)
	await scene_changed
	await process_frame
	var menu := current_scene
	assert(paused, "Main menu runs paused")
	var logo := menu.get_node("%Logo") as TextureRect
	assert(logo != null and logo.texture != null and logo.texture.resource_path.ends_with("deadline_logo.png"))

	var expected_buttons := {
		"%NewGame": ["NEW GAME", "icon_sanity_pixel.png"],
		"%Load": ["LOAD GAME", "icon_notepad.png"],
		"%Settings": ["OPTION", "icon_project.png"],
		"%Quit": ["EXIT", "icon_browser.png"],
	}
	for node_path: String in expected_buttons:
		var btn := menu.get_node(node_path) as Button
		var spec: Array = expected_buttons[node_path]
		assert(btn.text == spec[0], "Unexpected button text: %s" % btn.text)
		assert(btn.icon != null and btn.icon.resource_path.ends_with(spec[1]), "Unexpected icon on %s" % node_path)
		assert(btn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		assert(btn.offset_transform_enabled and btn.offset_transform_visual_only)

	var main_panel := menu.get_node("%MainPanel") as Control
	var title_box := menu.get_node("%TitleBox") as Control
	var new_game_btn := menu.get_node("%NewGame") as Button
	var quit_btn := menu.get_node("%Quit") as Button

	# Wait for pause-safe start fade-in + float motion
	await create_timer(0.65, true).timeout
	assert(main_panel.modulate.a > 0.98, "Entrance fade-in should complete while paused")
	assert(new_game_btn.modulate.a > 0.98)

	var float_a: float = title_box.offset_transform_position.y
	await create_timer(0.25, true).timeout
	var float_b: float = title_box.offset_transform_position.y
	assert(not is_equal_approx(float_a, float_b), "Title box should gently float while paused")

	# Ensure no synthetic headless cursor hover interferes with focus settle assertions
	for btn: Button in [new_game_btn, quit_btn]:
		btn.mouse_exited.emit()

	# Focus Exit -> red luminous tint & +8px nudge
	quit_btn.grab_focus()
	await create_timer(0.18, true).timeout
	assert(quit_btn.offset_transform_position.x > 6.5, "Focused button should nudge right")
	var quit_style := quit_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(quit_style.bg_color == Color("#ffecec"), "Exit button should shift to luminous red tint on focus")

	# Focus New Game -> blue luminous tint & +8px nudge; Exit settles back
	new_game_btn.grab_focus()
	await create_timer(0.18, true).timeout
	assert(new_game_btn.offset_transform_position.x > 6.5)
	var blue_style := new_game_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(blue_style.bg_color == Color("#e6f5ff"), "Blue button should shift to luminous blue tint on focus")
	assert(quit_btn.offset_transform_position.x < 1.5, "Unfocused button should settle back")
	var quit_idle := quit_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(quit_idle.bg_color == Color("#ffffff"), "Unfocused Exit button should return to white fill")

	# 2. New Game -> starts Day 1 06:00 inside bedroom with clock PAUSED
	assert(saves.start_new_game("Test Student") == OK)
	await scene_changed
	await physics_frame
	assert(current_scene.scene_file_path == DORM)
	assert(clock.get_semester() == 1 and clock.get_day_in_semester() == 1)
	assert(clock.get_absolute_minutes() == 360 and clock.get_formatted_time() == "06:00")
	assert(clock.is_room_paused(), "Clock must pause inside dorm_room210.tscn")

	clock.seconds_per_minute = 0.05
	await create_timer(0.25).timeout
	assert(clock.get_absolute_minutes() == 360, "Passive clock must NOT advance inside bedroom")

	# Explicit time jump (e.g. sleeping on bed) still works immediately and keeps timer paused
	clock.advance_minutes(60)
	assert(clock.get_absolute_minutes() == 420 and clock.get_formatted_time() == "07:00")
	await create_timer(0.20).timeout
	assert(clock.get_absolute_minutes() == 420, "Clock remains paused in bedroom after explicit jump")

	# 3. Leaving bedroom to corridor resumes clock immediately
	change_scene_to_file(HALLWAY)
	await scene_changed
	await physics_frame
	assert(not clock.is_room_paused(), "Clock must resume outside bedroom")
	var hallway_before: int = clock.get_absolute_minutes()
	await create_timer(0.20).timeout
	assert(clock.get_absolute_minutes() > hallway_before, "Clock should tick normally in hallway")

	# 4. Entering Desktop from bedroom resumes clock immediately
	change_scene_to_file(DORM)
	await scene_changed
	await physics_frame
	assert(clock.is_room_paused(), "Re-entering bedroom pauses clock again")
	assert(saves.open_desktop_from(current_scene, &"ComputerSpawn"))
	await scene_changed
	var transition := root.get_node("SceneTransition")
	if transition.is_active():
		await transition.transition_finished
	current_scene.get_node("StartupSound").stop()
	await physics_frame
	assert(not clock.is_room_paused(), "Clock must resume on Desktop PC")
	var desktop_before: int = clock.get_absolute_minutes()
	await create_timer(0.20).timeout
	assert(clock.get_absolute_minutes() > desktop_before, "Clock should tick normally on Desktop PC")

	print("PASS: main menu redesign/animations, schema reset, bedroom clock pause & outside resume")
	quit()


func _seed_stale_user_data() -> void:
	var settings := root.get_node("GameSettings")
	var saves := root.get_node("GameSave")
	var clock := root.get_node("GameClock")
	var notes := root.get_node("ClassroomProgress")
	assert(settings.save_settings(0.42, 1) == OK)
	assert(settings.mark_tutorial_seen("desktop_intro") == OK)
	assert(settings.mark_tutorial_seen("blueprint_workshop_intro") == OK)
	assert(saves.start_new_game("Stale Player") == OK)
	await scene_changed
	await physics_frame
	clock.restore_save_state({"minutes": 5625, "remainder": 0})
	assert(notes.begin_material(0) == OK)
	assert(notes.finish_material(0, true) == OK)
	assert(saves.save_now() == OK)
	# Remove schema marker to simulate a teammate with pre-v4 stale saves
	if FileAccess.file_exists(saves.SCHEMA_PATH):
		DirAccess.remove_absolute(saves.SCHEMA_PATH)
	print("SEEDED: stale pre-schema user data")
