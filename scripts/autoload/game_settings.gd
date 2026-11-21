extends Node

const SAVE_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var master_volume: float = 0.8
var resolution_index: int = 2


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SAVE_PATH) == OK:
		var volume: Variant = settings.get_value("audio", "master_volume", master_volume)
		var resolution: Variant = settings.get_value("display", "resolution_index", resolution_index)
		if volume is float or volume is int:
			master_volume = clampf(volume, 0.0, 1.0)
		if resolution is int and resolution >= 0 and resolution < RESOLUTIONS.size():
			resolution_index = resolution
	_apply.call_deferred()


func preview_volume(volume: float) -> void:
	var level := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(0, is_zero_approx(level))


func save_settings(volume: float, resolution: int) -> Error:
	if resolution < 0 or resolution >= RESOLUTIONS.size():
		return ERR_INVALID_PARAMETER
	var settings := ConfigFile.new()
	settings.set_value("audio", "master_volume", clampf(volume, 0.0, 1.0))
	settings.set_value("display", "resolution_index", resolution)
	var error := settings.save(SAVE_PATH + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if error != OK:
		return error
	master_volume = clampf(volume, 0.0, 1.0)
	resolution_index = resolution
	_apply()
	return OK


func _apply() -> void:
	preview_volume(master_volume)
	if DisplayServer.get_name() == "headless":
		return
	var resolution := RESOLUTIONS[resolution_index]
	DisplayServer.window_set_size(resolution)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position + ((usable.size - resolution) / 2).max(Vector2i.ZERO))
