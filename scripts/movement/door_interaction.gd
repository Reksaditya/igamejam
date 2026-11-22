extends Area2D

@export_file("*.tscn") var destination: String
@export var destination_spawn: StringName = &"InteriorSpawn"
@export var action_text: String = "Masuk"
@export var transition_style: SceneTransition.TransitionStyle = SceneTransition.TransitionStyle.SLIDE_LEFT

var _player: CharacterBody2D
var _opening: bool = false

@onready var _prompt: Control = $Prompt
@onready var _prompt_button: Button = $Prompt/Button


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt_button.pressed.connect(_request_open)
	SceneTransition.transition_finished.connect(_on_transition_finished)
	if _is_classroom_door() or _is_dorm_exit_door():
		GameClock.minute_changed.connect(_on_schedule_changed)
	if _is_classroom_door():
		CareerProgress.changed.connect(_refresh_prompt)
	_refresh_prompt()
	_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _request_open():
		get_viewport().set_input_as_handled()


func _is_classroom_door() -> bool:
	return destination.contains("campus_classroom")


func _is_dorm_exit_door() -> bool:
	return destination.ends_with("dorm_exterior.tscn")


func _is_dorm_curfew_locked() -> bool:
	if not _is_dorm_exit_door():
		return false
	var minute_of_day := posmod(GameClock.get_absolute_minutes(), GameClock.MINUTES_PER_DAY)
	return minute_of_day >= 22 * 60 or minute_of_day < 6 * 60


func _is_classroom_locked_out() -> bool:
	if not _is_classroom_door():
		return false
	CareerProgress.check_class_attendance_cutoff()
	return not CareerProgress.can_enter_class(CareerProgress.semester(), CareerProgress.day_in_semester())


func _on_schedule_changed(_minutes: int) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not is_instance_valid(_prompt_button):
		return
	if _is_dorm_curfew_locked():
		_prompt_button.text = "Asrama terkunci (jam malam). Istirahat di kamar dulu."
		_prompt_button.tooltip_text = "Pintu keluar asrama terkunci pukul 22:00–06:00."
		_prompt_button.add_theme_color_override("font_color", Color("#d8d8de"))
		_prompt_button.add_theme_color_override("font_hover_color", Color("#f0f0f2"))
	elif _is_classroom_locked_out():
		_prompt_button.text = "KELAS TERLEWAT · Terlambat > 1 jam"
		_prompt_button.tooltip_text = "Pintu kelas ditutup setelah 09:00. Kejar catatan di Perpustakaan."
		_prompt_button.add_theme_color_override("font_color", Color("#ffb4a2"))
		_prompt_button.add_theme_color_override("font_hover_color", Color("#ffd0c4"))
	else:
		_prompt_button.text = "E · " + action_text
		_prompt_button.tooltip_text = ""
		_prompt_button.remove_theme_color_override("font_color")
		_prompt_button.remove_theme_color_override("font_hover_color")


func _resolved_transition_style() -> SceneTransition.TransitionStyle:
	if destination.ends_with("transmission_workshop.tscn") or destination.ends_with("desktop.tscn"):
		return SceneTransition.TransitionStyle.FADE
	if transition_style == SceneTransition.TransitionStyle.SLIDE_LEFT and action_text.containsn("keluar"):
		return SceneTransition.TransitionStyle.SLIDE_RIGHT
	return transition_style


func _request_open() -> bool:
	if _opening or SceneTransition.is_active() or not is_instance_valid(_player) or not overlaps_body(_player) or destination.is_empty():
		return false
	if _is_dorm_curfew_locked() or _is_classroom_locked_out():
		_refresh_prompt()
		return false
	_opening = true
	_open.call_deferred()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player = body
		_refresh_prompt()
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_prompt.hide()


func _open() -> void:
	SceneTransition.change_scene(destination, destination_spawn, _resolved_transition_style())


func _on_transition_finished(error: Error) -> void:
	if error != OK:
		_opening = false
