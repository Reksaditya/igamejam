extends Node

signal changed

const ENERGY_MAX := 100.0
const SANITY_MAX := 100.0
const GPA_MAX := 4.0
const DEFAULTS := {"energy": 100.0, "sanity": 40.0, "gpa": 0.0}

var _energy := 100.0
var _sanity := 40.0
var _gpa := 0.0


func get_energy() -> float:
	return _energy


func get_sanity() -> float:
	return _sanity


func get_gpa() -> float:
	return _gpa


func set_energy(value: float) -> void:
	_update(value, _sanity, _gpa)


func set_sanity(value: float) -> void:
	_update(_energy, value, _gpa)


func set_gpa(value: float) -> void:
	_update(_energy, _sanity, value)


func get_save_state() -> Dictionary:
	return {"energy": _energy, "sanity": _sanity, "gpa": _gpa}


func restore_save_state(state: Dictionary) -> void:
	_update(
		_read_stat(state, "energy"),
		_read_stat(state, "sanity"),
		_read_stat(state, "gpa")
	)


func _read_stat(state: Dictionary, key: String) -> float:
	var value: Variant = state.get(key, DEFAULTS[key])
	return float(value) if (value is int or value is float) and is_finite(value) else DEFAULTS[key]


func _update(energy: float, sanity: float, gpa: float) -> void:
	energy = clampf(energy, 0.0, ENERGY_MAX) if is_finite(energy) else _energy
	sanity = clampf(sanity, 0.0, SANITY_MAX) if is_finite(sanity) else _sanity
	gpa = clampf(gpa, 0.0, GPA_MAX) if is_finite(gpa) else _gpa
	if _energy == energy and _sanity == sanity and _gpa == gpa:
		return
	_energy = energy
	_sanity = sanity
	_gpa = gpa
	changed.emit()
