extends Area2D

signal interaction_requested

var available: bool = false
var _player: CharacterBody2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$Prompt.pressed.connect(_interact)
	$Prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and _interact():
		get_viewport().set_input_as_handled()


func _interact() -> bool:
	if not available or not is_instance_valid(_player) or not overlaps_body(_player) or SceneTransition.is_active():
		return false
	interaction_requested.emit()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player = body
		$Prompt.visible = available


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		$Prompt.hide()
