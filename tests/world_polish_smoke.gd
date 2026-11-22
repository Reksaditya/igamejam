extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var clock := root.get_node("GameClock")
	var career := root.get_node("CareerProgress")
	var transition := root.get_node("SceneTransition")
	transition.fade_seconds = 0.05
	transition.slide_seconds = 0.05

	assert(saves.start_new_game("Nadia") == OK)
	await scene_changed
	await _frames(4)

	# 1. Neutral grey-black open-world HUD + ultra-simple clock + background-free schedule
	var profile := current_scene.get_node("PlayerProfile")
	assert(profile._hud_clock_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var clock_style := profile._hud_clock_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(clock_style != null and absf(clock_style.bg_color.r - clock_style.bg_color.b) < 0.04, "Clock strip must use neutral grey-black, not dark blue")
	assert(profile._hud_quest_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "Class schedule must be background-free (StyleBoxEmpty)")
	assert(profile._hud_quest_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(profile._hud_quest_title.get_theme_constant("outline_size") >= 3, "Background-free schedule text must have dark outline")

	var stats_hud: PanelContainer = profile._hud_stats
	var pill_style := stats_hud._pills[0].get_theme_stylebox("panel") as StyleBoxFlat
	assert(pill_style != null and absf(pill_style.bg_color.r - pill_style.bg_color.b) < 0.04, "Stats HUD pills must be neutral grey-black")

	# 2. Consistent player scale + room-by-room wayfinding pointer routing
	clock.restore_save_state({"minutes": 7 * 60 + 30, "remainder": 0})
	await _frames(3)
	assert(is_equal_approx(current_scene.get_node("Player/Visual").scale.y, 1.5), "Dorm room 210 scale must be 1.5")
	assert(profile._wayfinding_label.visible and "Keluar kamar" in profile._wayfinding_label.text)

	var route_checks: Array[Array] = [
		["res://scenes/movement/dorm_floor2.tscn", 2.1, "Turun Lt. 1"],
		["res://scenes/movement/dorm_floor1.tscn", 2.1, "Keluar asrama"],
		["res://scenes/movement/dorm_exterior.tscn", 1.5, "Ke Kampus"],
		["res://scenes/movement/top_down_movement.tscn", 1.5, "Gedung Kelas"],
		["res://scenes/movement/campus_lab_room.tscn", 2.0, "Keluar lab"],
		["res://scenes/movement/lecturer_room.tscn", 2.0, "Keluar ruang dosen"],
		["res://scenes/movement/classroom_corridor_floor1.tscn", 3.0, "Pintu Kelas"],
	]
	for item: Array in route_checks:
		var path: String = item[0]
		var expected_scale: float = item[1]
		var expected_label: String = item[2]
		change_scene_to_file(path)
		await scene_changed
		await _frames(3)
		var visual := current_scene.get_node("Player/Visual") as Node2D
		assert(is_equal_approx(absf(visual.scale.y), expected_scale), "Unexpected player scale in %s: got %s expected %s" % [path, str(visual.scale.y), str(expected_scale)])
		var hud := current_scene.get_node("PlayerProfile")
		assert(hud._wayfinding_label.visible, "Wayfinding pointer must be visible in %s at 07:30" % path)
		assert(expected_label in hud._wayfinding_label.text, "Expected '%s' in %s pointer, got '%s'" % [expected_label, path, hud._wayfinding_label.text])

	# Verify placeholder NPCs are kept in top_down_movement (Raka) & dorm_floor1
	change_scene_to_file("res://scenes/movement/dorm_floor1.tscn")
	await scene_changed
	await _frames(3)
	var wf_dorm := current_scene.get_node("WorldFeatures")
	assert(wf_dorm.get_child_count() >= 3, "Placeholder NPCs in dorm_floor1 must be kept")

	# Verify wayfinding hides inside classroom and when class is missed
	change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
	await scene_changed
	await _frames(3)
	assert(not current_scene.get_node("PlayerProfile")._wayfinding_label.visible, "Wayfinding pointer must hide inside classroom")

	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	await _frames(3)
	clock.restore_save_state({"minutes": 9 * 60 + 5, "remainder": 0})
	await _frames(3)
	assert(not current_scene.get_node("PlayerProfile")._wayfinding_label.visible, "Wayfinding pointer must hide when class is missed")

	# 3. Curfew: Dorm exit door locked at >= 22:00 (unlocked at 07:00)
	change_scene_to_file("res://scenes/movement/dorm_floor1.tscn")
	await scene_changed
	await _frames(3)
	var dorm_exit := current_scene.get_node("Door")
	var player := current_scene.get_node("Player") as CharacterBody2D
	player.position = Vector2(dorm_exit.position.x, 592.0)
	await _frames(4)
	clock.restore_save_state({"minutes": 22 * 60 + 5, "remainder": 0})
	await _frames(3)
	assert(dorm_exit._is_dorm_curfew_locked(), "Dorm exit door must lock during curfew >= 22:00")
	assert(not dorm_exit._request_open(), "Locked dorm exit door must reject opening during curfew")
	assert("Asrama terkunci" in dorm_exit.get_node("Prompt/Button").text)
	assert(current_scene.get_node("WorldFeatures")._is_inside_dorm())

	clock.restore_save_state({"minutes": 1440 + 7 * 60, "remainder": 0})
	await _frames(3)
	assert(not dorm_exit._is_dorm_curfew_locked(), "Dorm exit door must unlock in the morning (07:00)")

	# 4. Curfew outside dorm >= 22:00: NO guard chase, clean notice + fade back to dorm_room210, no loop
	career.acknowledge_story("intro")
	set_meta(&"suppress_world_events", false)
	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	await _frames(3)
	clock.restore_save_state({"minutes": 1440 + 22 * 60 + 10, "remainder": 0})
	var wf_out := current_scene.get_node("WorldFeatures")
	wf_out._process(1.0)
	assert(wf_out._curfew_triggered, "Curfew return must trigger outside dorm at >= 22:00")
	await scene_changed
	while transition.is_active():
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/movement/dorm_room210.tscn", "Curfew must return player cleanly to dorm_room210.tscn")
	assert(transition.last_style == transition.TransitionStyle.FADE, "Curfew return must use FADE transition")
	var wf_in := current_scene.get_node("WorldFeatures")
	assert(wf_in._is_inside_dorm() and not wf_in._curfew_due and not wf_in._curfew_triggered, "Curfew must NOT re-trigger inside dorm")

	print("PASS: neutral grey-black HUD, simple clock, background-free schedule + wayfinding pointer, normalized scale, simplified curfew without guard chase, and placeholder NPCs preserved")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame
