extends SceneTree

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	await _test_desktop_icons()
	await _test_transitions()
	await _test_persistent_tutorials()
	await _test_class_lockout_and_hud()
	print("PASS: desktop pixel-art icons, slide/fade transitions, persistent first-time tutorials, 1-hour late class lockout, missed sign, and HUD schedule quest line")
	quit()


func _test_desktop_icons() -> void:
	var expected_paths: Dictionary = {
		Launcher.IconKind.TEXT_DOCUMENT: "res://assets/textures/desktop/icons/icon_document.png",
		Launcher.IconKind.BROWSER: "res://assets/textures/desktop/icons/icon_browser.png",
		Launcher.IconKind.FOLDER: "res://assets/textures/desktop/icons/icon_file_manager.png",
		Launcher.IconKind.NOTEPAD: "res://assets/textures/desktop/icons/icon_notepad.png",
		Launcher.IconKind.IMAGE: "res://assets/textures/desktop/icons/icon_images.png",
		Launcher.IconKind.BLUEPRINT: "res://assets/textures/desktop/icons/icon_project.png",
	}
	for kind: int in expected_paths:
		var path: String = expected_paths[kind]
		assert(ResourceLoader.exists(path), "Missing custom icon texture: " + path)
		var tex := load(path) as Texture2D
		assert(tex != null, "Failed to load texture: " + path)
		var mapped := Launcher.LAUNCHER_ICONS.get(kind) as Texture2D
		assert(mapped != null and mapped.resource_path == path, "IconKind %d must map to %s, got %s" % [kind, path, str(mapped.resource_path if mapped != null else "null")])

	var btn := Launcher.new()
	btn.icon_kind = Launcher.IconKind.BROWSER
	btn.display_title = "Word Explorer"
	root.add_child(btn)
	await process_frame
	var icon_rect := btn.get_node("IconTexture") as TextureRect
	assert(icon_rect != null, "Launcher must render icon via IconTexture TextureRect")
	assert(icon_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Icon must use nearest-neighbor pixel filtering")
	assert(icon_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Icon must keep aspect ratio centered")
	assert(icon_rect.texture != null and icon_rect.texture.resource_path == expected_paths[Launcher.IconKind.BROWSER])
	btn.queue_free()
	await process_frame


func _test_transitions() -> void:
	var transition := root.get_node("SceneTransition")
	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	await process_frame
	var courtyard_door := current_scene.get_node("Door")
	assert(courtyard_door._resolved_transition_style() == transition.TransitionStyle.SLIDE_LEFT, "Open-world entrance door must use SLIDE_LEFT")

	transition.change_scene("res://scenes/movement/campus_lab_room.tscn", &"InteriorSpawn", transition.TransitionStyle.SLIDE_LEFT)
	await create_timer(0.12).timeout
	assert(transition.is_active() and paused, "SLIDE_LEFT transition must be active and pause world")
	await scene_changed
	while transition.is_active():
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/movement/campus_lab_room.tscn")
	assert(transition.last_style == transition.TransitionStyle.SLIDE_LEFT)
	assert(not transition.get_node("Screen").visible and is_equal_approx(transition.get_node("Screen").color.a, 0.0))

	var exit_door := current_scene.get_node("Door")
	assert(exit_door._resolved_transition_style() == transition.TransitionStyle.SLIDE_RIGHT, "Open-world exit door must use SLIDE_RIGHT")
	var workshop_bench := current_scene.get_node("WorkshopBench")
	assert(workshop_bench._resolved_transition_style() == transition.TransitionStyle.FADE, "Workshop bench door must preserve FADE transition")

	transition.change_scene("res://scenes/movement/dorm_room203.tscn", &"BedSpawn", transition.TransitionStyle.FADE)
	await scene_changed
	while transition.is_active():
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/movement/dorm_room203.tscn")
	assert(transition.last_style == transition.TransitionStyle.FADE)


func _test_persistent_tutorials() -> void:
	var settings := root.get_node("GameSettings")
	var blueprints := root.get_node("ProjectBlueprints")
	assert(settings.reset_tutorials() == OK)
	assert(not settings.has_seen_tutorial("desktop_intro"))
	assert(not settings.has_seen_tutorial("blueprint_workshop_intro"))

	# 1) Desktop first-time tutorial triggers on first unlock/boot finish, persists on dismiss, and does not re-trigger.
	var desktop_scene := load("res://scenes/interaction/desktop/desktop.tscn") as PackedScene
	var desktop := desktop_scene.instantiate() as Control
	desktop.login_scene = null
	root.add_child(desktop)
	await process_frame
	while desktop._boot_cover.visible:
		await process_frame
	await process_frame
	assert(desktop.is_tutorial_visible(), "Desktop first-time tutorial must appear on first entry")
	desktop.dismiss_tutorial()
	await process_frame
	assert(not desktop.is_tutorial_visible(), "Desktop tutorial must close on dismiss")
	assert(settings.has_seen_tutorial("desktop_intro"), "Desktop tutorial seen flag must persist in memory")
	desktop.queue_free()
	await process_frame

	settings.reload_tutorials()
	assert(settings.has_seen_tutorial("desktop_intro"), "Desktop tutorial seen flag must reload from user://tutorials.cfg")

	var desktop_again := desktop_scene.instantiate() as Control
	desktop_again.login_scene = null
	root.add_child(desktop_again)
	await process_frame
	while desktop_again._boot_cover.visible:
		await process_frame
	await process_frame
	assert(not desktop_again.is_tutorial_visible(), "Desktop tutorial must NOT re-trigger after dismissal")
	desktop_again.queue_free()
	await process_frame

	# 2) Workshop first-time tutorial triggers even with 0 owned blueprints, persists on dismiss, and does not re-trigger.
	var workshop_scene := load("res://scenes/interaction/workshop/transmission_workshop.tscn") as PackedScene
	var workshop := workshop_scene.instantiate() as Control
	workshop.demo_blueprint = false
	root.add_child(workshop)
	await process_frame
	assert(workshop._owned_puzzles().is_empty(), "Expected 0 owned blueprints on fresh run")
	assert(workshop.is_tutorial_visible(), "Workshop tutorial must appear on first entry even with 0 blueprints")
	workshop.dismiss_tutorial()
	await process_frame
	assert(not workshop.is_tutorial_visible(), "Workshop tutorial must close on dismiss")
	assert(settings.has_seen_tutorial("blueprint_workshop_intro"))
	workshop.queue_free()
	await process_frame

	settings.reload_tutorials()
	assert(settings.has_seen_tutorial("blueprint_workshop_intro"), "Workshop tutorial seen flag must reload from user://tutorials.cfg")

	var workshop_again := workshop_scene.instantiate() as Control
	workshop_again.demo_blueprint = false
	root.add_child(workshop_again)
	await process_frame
	assert(not workshop_again.is_tutorial_visible(), "Workshop tutorial must NOT re-trigger after dismissal")
	workshop_again.queue_free()
	await process_frame


func _test_class_lockout_and_hud() -> void:
	var saves := root.get_node("GameSave")
	var clock := root.get_node("GameClock")
	var career := root.get_node("CareerProgress")

	assert(saves.start_new_game() == OK)
	await scene_changed
	await process_frame
	await process_frame

	# Move to Classroom Corridor Floor 1 so we can verify both HUD and classroom door behavior.
	change_scene_to_file("res://scenes/movement/classroom_corridor_floor1.tscn")
	await scene_changed
	await process_frame
	await process_frame

	var profile := current_scene.get_node("PlayerProfile")
	var player := current_scene.get_node("Player") as CharacterBody2D
	var door := current_scene.get_node("Door")
	player.position = Vector2(1170.0, 592.0)
	await physics_frame
	await physics_frame

	# Boundary 1: 07:59 (start - 1) -> allowed, upcoming
	clock.restore_save_state({"minutes": 7 * 60 + 59, "remainder": 0})
	await process_frame
	assert(career.can_enter_class(1, 1), "07:59 (start - 1) must allow entering class")
	assert(not career.is_class_missed(1, 1))
	var st_upcoming: Dictionary = career.get_today_schedule_status()
	assert(st_upcoming.state == "class_upcoming")
	assert(profile._hud_quest_badge.text == "JADWAL KELAS")
	assert(profile._hud_quest_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(profile._hud_toast.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	# Boundary 2: 08:00 (start) -> allowed, open
	clock.restore_save_state({"minutes": 8 * 60, "remainder": 0})
	await process_frame
	assert(career.can_enter_class(1, 1), "08:00 (start) must allow entering class")
	assert(not career.is_class_missed(1, 1))
	var st_open: Dictionary = career.get_today_schedule_status()
	assert(st_open.state == "class_open")
	assert(profile._hud_quest_badge.text == "KELAS DIBUKA")

	# Boundary 3: 08:59 (start + 59) -> allowed, open, door not locked out
	clock.restore_save_state({"minutes": 8 * 60 + 59, "remainder": 0})
	await process_frame
	assert(career.can_enter_class(1, 1), "08:59 (start + 59) must STILL allow entering class")
	assert(not career.is_class_missed(1, 1))
	assert(not door._is_classroom_locked_out())
	assert(door.get_node("Prompt/Button").text == "E · Masuk kelas")

	# Boundary 4: 09:00 (start + 60) -> BLOCKED, missed persisted, door locked with clear sign, HUD red/amber + toast
	clock.restore_save_state({"minutes": 9 * 60, "remainder": 0})
	await process_frame
	assert(not career.can_enter_class(1, 1), "09:00 (start + 60) must BLOCK entering class")
	assert(career.is_class_missed(1, 1), "09:00 must mark class missed")
	assert(career.class_data(1, 1).missed == true, "Missed flag must be written to career state")
	assert(door._is_classroom_locked_out(), "Classroom door must lock out at 09:00")
	assert(not door._request_open(), "Classroom door _request_open() must reject entry when missed")
	assert("KELAS TERLEWAT" in door.get_node("Prompt/Button").text, "Classroom door prompt must display missed sign")
	assert(profile._hud_quest_badge.text == "KELAS TERLEWAT", "HUD quest badge must show KELAS TERLEWAT")
	assert(profile._hud_toast.visible, "Missed-class toast should appear when crossing 09:00")

	# Verify missed flag persists across CareerProgress.reload_progress()
	career.reload_progress()
	assert(career.class_data(1, 1).missed == true, "Missed flag must persist across save/reload")
	assert(not career.can_enter_class(1, 1))

	# Verify classroom interior also blocks starting lesson and shows missed sign
	change_scene_to_file("res://scenes/movement/campus_classroom.tscn")
	await scene_changed
	await process_frame
	await process_frame
	var classroom := current_scene.get_node("ClassActivity")
	assert("KELAS TERLEWAT" in classroom.get_node("%ClassStatus").text, "Classroom interior status must display missed sign")
	var seat := classroom.get_node("Seat") as Area2D
	current_scene.get_node("Player").global_position = seat.global_position
	await physics_frame
	classroom._open_lesson(seat)
	assert(classroom._lesson == null, "Classroom must block starting lesson when missed")

	# Verify same-day Library recovery is unlocked for missed class and transitions HUD to class_done
	var review_info: Dictionary = career.review_details(1, 1)
	assert(not review_info.is_empty(), "Library catch-up must unlock on the same day after missing class")
	var lesson := Curriculum.lesson(1, 1)
	assert(career.review_class(1, 1, lesson.keyword) == OK)
	assert(career.class_data(1, 1).finished == true)
	assert(not career.is_class_missed(1, 1))

	# Exam day (Hari 6 at 09:30) is NOT blocked by morning class lockout
	clock.restore_save_state({"minutes": 5 * clock.MINUTES_PER_DAY + 9 * 60 + 30, "remainder": 0})
	await process_frame
	assert(career.day_in_semester() == 6)
	assert(career.can_enter_class(1, 6), "Exam day (Hari 6) must remain accessible after 09:00")
	var st_exam: Dictionary = career.get_today_schedule_status()
	assert(st_exam.state == "exam_ready")
