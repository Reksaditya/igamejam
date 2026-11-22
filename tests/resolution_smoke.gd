extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("GameSettings")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene._show_settings()
	var original_volume: float = settings.master_volume
	current_scene.get_node("%Volume").value = 0
	for index: int in settings.RESOLUTIONS.size():
		var option := current_scene.get_node("%Resolution") as OptionButton
		option.select(index)
		option.item_selected.emit(index)
		await _check_resolution(index)
		assert(settings.master_volume == original_volume)
		assert(AudioServer.is_bus_mute(0))
	assert(root.get_node("GameSave").start_new_game("Resolution Test") == OK)
	await scene_changed
	var profile := current_scene.get_node("PlayerProfile")
	profile.open_profile()
	profile._show_settings()
	profile._volume.value = 0
	for index: int in range(settings.RESOLUTIONS.size() - 1, -1, -1):
		profile._resolution.select(index)
		profile._resolution.item_selected.emit(index)
		await _check_resolution(index)
		assert(settings.master_volume == original_volume)
		assert(AudioServer.is_bus_mute(0))
		assert(profile._popup.visible and profile._settings.visible and paused)
	profile._popup.hide()
	assert(not paused and not AudioServer.is_bus_mute(0))
	print("PASS: all available resolutions apply immediately in menu and profile, save on selection, preserve volume preview, keep settings open")
	quit()


func _check_resolution(index: int) -> void:
	await create_timer(0.2).timeout
	var settings := root.get_node("GameSettings")
	assert(settings.resolution_index == index)
	var saved := ConfigFile.new()
	assert(saved.load(settings.SAVE_PATH) == OK)
	assert(saved.get_value("display", "resolution_index") == index)
	if DisplayServer.get_name() != "headless":
		assert(DisplayServer.window_get_size() == settings.RESOLUTIONS[index])
