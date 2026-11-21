extends Area2D

@export_file("*.tscn") var destination: String
@export var destination_spawn: StringName = &"InteriorSpawn"
@export var action_text: String = "Masuk"

var _player: CharacterBody2D
var _opening: bool = false

@onready var _prompt: Control = $Prompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$Prompt/Button.text = "E · " + action_text
	$Prompt/Button.pressed.connect(_request_open)
	_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _request_open():
		get_viewport().set_input_as_handled()


func _request_open() -> bool:
	if _opening or not is_instance_valid(_player) or not overlaps_body(_player) or destination.is_empty():
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
	get_tree().set_meta(&"side_scroller_spawn", destination_spawn)
	var error := get_tree().change_scene_to_file(destination)
	if error != OK:
		get_tree().remove_meta(&"side_scroller_spawn")
		_opening = false
