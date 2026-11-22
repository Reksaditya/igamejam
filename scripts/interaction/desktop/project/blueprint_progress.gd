extends Node

signal changed

enum State { LOCKED, UNLOCKED, WORKED, COMPLETED }

const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://blueprint_progress.cfg"
const WORKSHOP_SAVE_PATH := "user://workshop_progress.cfg"


func is_owned(blueprint_id: String) -> bool:
	return _owns(Save.load_config(SAVE_PATH), blueprint_id)


func is_worked(blueprint_id: String, workshop_puzzle_id := "") -> bool:
	var state := get_state(blueprint_id, workshop_puzzle_id)
	return state == State.WORKED or state == State.COMPLETED


func is_workshop_completed(blueprint_id: String, workshop_puzzle_id := "") -> bool:
	return get_state(blueprint_id, workshop_puzzle_id) == State.COMPLETED


func get_state(blueprint_id: String, workshop_puzzle_id := "") -> State:
	var config := Save.load_config(SAVE_PATH)
	if not _owns(config, blueprint_id):
		return State.LOCKED
	if _is_workshop_completed_in_config(config, blueprint_id) or _is_legacy_workshop_completed(workshop_puzzle_id):
		return State.COMPLETED
	if _is_worked_in_config(config, blueprint_id):
		return State.WORKED
	return State.UNLOCKED


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


func mark_worked(blueprint_id: String, completed := false) -> Error:
	if not blueprint_id.is_valid_identifier():
		return ERR_INVALID_PARAMETER
	var config := Save.load_config(SAVE_PATH)
	if not _owns(config, blueprint_id):
		return ERR_UNAVAILABLE
	var already_worked := _is_worked_in_config(config, blueprint_id)
	var already_completed := _is_workshop_completed_in_config(config, blueprint_id)
	if already_worked and (not completed or already_completed):
		return OK
	config.set_value(blueprint_id, "worked", true)
	if completed:
		config.set_value(blueprint_id, "workshop_completed", true)
	var error := Save.write_config(config, SAVE_PATH)
	if error == OK:
		changed.emit()
	return error


func _owns(config: ConfigFile, blueprint_id: String) -> bool:
	var completed: Variant = config.get_value(blueprint_id, "completed", false)
	return completed is bool and completed


func _is_worked_in_config(config: ConfigFile, blueprint_id: String) -> bool:
	var worked: Variant = config.get_value(blueprint_id, "worked", false)
	return worked is bool and worked


func _is_workshop_completed_in_config(config: ConfigFile, blueprint_id: String) -> bool:
	var done: Variant = config.get_value(blueprint_id, "workshop_completed", false)
	return done is bool and done


func _is_legacy_workshop_completed(workshop_puzzle_id: String) -> bool:
	if workshop_puzzle_id.is_empty():
		return false
	var workshop := Save.load_config(WORKSHOP_SAVE_PATH)
	var done: Variant = workshop.get_value(workshop_puzzle_id, "completed", false)
	return done is bool and done
