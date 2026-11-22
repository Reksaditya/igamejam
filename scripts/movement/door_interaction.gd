extends Area2D

@export_file("*.tscn") var destination: String
@export var destination_spawn: StringName = &"InteriorSpawn"
@export var action_text: String = "Masuk"
@export var transition_style: SceneTransition.TransitionStyle = SceneTransition.TransitionStyle.SLIDE_LEFT

var _player: CharacterBody2D
var _opening: bool = false

@onready var _prompt: Control = $Prompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$Prompt/Button.text = "E · " + action_text
	$Prompt/Button.pressed.connect(_request_open)
	SceneTransition.transition_finished.connect(_on_transition_finished)
	_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _request_open():
		get_viewport().set_input_as_handled()


func _resolved_transition_style() -> SceneTransition.TransitionStyle:
	if destination.ends_with("transmission_workshop.tscn") or destination.ends_with("desktop.tscn"):
		return SceneTransition.TransitionStyle.FADE
	if transition_style == SceneTransition.TransitionStyle.SLIDE_LEFT and action_text.containsn("keluar"):
		return SceneTransition.TransitionStyle.SLIDE_RIGHT
	return transition_style


func _request_open() -> bool:
	if _opening or SceneTransition.is_active() or not is_instance_valid(_player) or not overlaps_body(_player) or destination.is_empty():
		return false
	_opening = true
	_open.call_deferred()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player = body
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
