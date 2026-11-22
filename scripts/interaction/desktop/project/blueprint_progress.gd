extends Node

signal changed

const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://blueprint_progress.cfg"


func is_owned(blueprint_id: String) -> bool:
	return _owns(Save.load_config(SAVE_PATH), blueprint_id)


func grant(blueprint_id: String) -> Error:
	if not blueprint_id.is_valid_identifier():
		return ERR_INVALID_PARAMETER
	var config := Save.load_config(SAVE_PATH)
	if _owns(config, blueprint_id):
		return OK
	for legacy_key: String in ["unlocked", "placed", "rotations"]:
		if config.has_section_key(blueprint_id, legacy_key):
			config.erase_section_key(blueprint_id, legacy_key)
	config.set_value(blueprint_id, "completed", true)
	var error := Save.write_config(config, SAVE_PATH)
	if error == OK:
		changed.emit()
	return error


func _owns(config: ConfigFile, blueprint_id: String) -> bool:
	var completed: Variant = config.get_value(blueprint_id, "completed", false)
	return completed is bool and completed
