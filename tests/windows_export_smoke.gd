extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	var menu := current_scene
	_check(menu.get_node("%Load").disabled, "Load harus nonaktif tanpa save")
	menu._show_settings()
	_check(menu.get_node("%SettingsPanel").visible, "Settings menu tidak tampil")
	menu._show_main()
	var saves := root.get_node("GameSave")
	_check(saves.start_new_game("Windows Build") == OK, "New Game gagal")
	await scene_changed
	var stats := root.get_node("PlayerStats")
	_check(stats.player_name == "Windows Build", "Nama pemain tidak tersimpan")
	_check(stats.student_id.length() == 12 and stats.student_id.begins_with("607"), "Format NIM salah")
	var profile := current_scene.get_node("PlayerProfile")
	profile.open_profile()
	profile._show_settings()
	_check(paused and profile._settings.visible, "Settings profil tidak tampil")
	profile._popup.hide()
	root.get_node("GameClock").restore_save_state({"minutes": 600, "remainder": 0})
	change_scene_to_file("res://scenes/movement/dorm_room210.tscn")
	await scene_changed
	for i: int in 8:
		await physics_frame
	var room := current_scene
	_check(room.room_rect.size.is_equal_approx((root.get_visible_rect().size * 0.6).round()), "Ukuran kamar tidak sesuai")
	for id: String in ["Bed", "Nightstand", "Chair", "Clock"]:
		_check(room.get_node("Furniture/" + id).texture != null, "Texture furniture hilang: " + id)
	var player := room.get_node("Player") as CharacterBody2D
	var chair := room.get_node("Chair")
	player.position = chair.position + Vector2(0, 2)
	for i: int in 8:
		await physics_frame
	_press_e()
	for i: int in 4:
		await physics_frame
	_check(chair.seated, "Interaksi E kursi gagal")
	_press_e()
	for i: int in 4:
		await physics_frame
	_check(not chair.seated, "Berdiri dari kursi gagal")
	_check(saves.save_now() == OK and saves.has_save(), "Autosave gagal")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	_check(not current_scene.get_node("%Load").disabled, "Load tidak aktif setelah save")
	current_scene._load_game()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("dorm_room210.tscn"), "Load tidak kembali ke kamar")
	for path: String in ["res://scenes/movement/campus_classroom.tscn", "res://scenes/movement/campus_lab_room.tscn", "res://scenes/interaction/desktop/desktop.tscn"]:
		_check(ResourceLoader.exists(path) and load(path) != null, "Resource ekspor hilang: " + path)
	if not _failed:
		print("PASS: exported Windows New Game, identity, settings, profile, room assets, E chair, save and Load")
	quit(1 if _failed else 0)


func _press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_E
	Input.parse_input_event(released)
