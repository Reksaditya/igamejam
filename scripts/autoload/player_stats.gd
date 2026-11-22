extends Node

signal changed

const DEFAULTS := {"energy": 100.0, "sanity": 40.0, "gpa": 0.0, "player_name": "Yohan", "student_id": ""}

var player_name: String = "Yohan"
var student_id: String = ""
var _energy: float = 100.0
var _sanity: float = 40.0
var _gpa: float = 0.0


func _ready() -> void:
	restore_save_state(DEFAULTS)


static func make_new_state(name: String) -> Dictionary:
	var state := DEFAULTS.duplicate()
	var random := RandomNumberGenerator.new()
	random.randomize()
	state.player_name = name.strip_edges().left(32)
	state.student_id = "607%09d" % random.randi_range(0, 999999999)
	return state


func get_energy() -> float:
	return _energy


func get_sanity() -> float:
	return _sanity


func get_gpa() -> float:
	return _gpa


func set_energy(value: float) -> void:
	if is_finite(value):
		_energy = clampf(value, 0.0, 100.0)
		changed.emit()


func set_sanity(value: float) -> void:
	if is_finite(value):
		_sanity = clampf(value, 0.0, 100.0)
		changed.emit()


func set_gpa(value: float) -> void:
	if is_finite(value):
		_gpa = clampf(value, 0.0, 4.0)
		changed.emit()


func get_save_state() -> Dictionary:
	return {"energy": _energy, "sanity": _sanity, "gpa": _gpa, "player_name": player_name, "student_id": student_id}


func restore_save_state(state: Dictionary) -> void:
	_energy = clampf(_read_number(state, "energy"), 0.0, 100.0)
	_sanity = clampf(_read_number(state, "sanity"), 0.0, 100.0)
	_gpa = clampf(_read_number(state, "gpa"), 0.0, 4.0)
	var name: Variant = state.get("player_name", "Yohan")
	player_name = name.strip_edges().left(32) if name is String and not name.strip_edges().is_empty() else "Yohan"
	var id: Variant = state.get("student_id", "")
	student_id = id if id is String and id.length() == 12 and id.begins_with("607") and id.is_valid_int() else make_new_state(player_name).student_id
	changed.emit()


func _read_number(state: Dictionary, key: String) -> float:
	var value: Variant = state.get(key, DEFAULTS[key])
	return float(value) if (value is float or value is int) and is_finite(value) else DEFAULTS[key]
