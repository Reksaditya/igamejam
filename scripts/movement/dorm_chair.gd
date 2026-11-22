extends Area2D

var seated: bool = false
var seat_offset := Vector2(0, -1)
var _player: CharacterBody2D
var _prompt: Button


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 110)
	collision.shape = shape
	add_child(collision)
	_prompt = Button.new()
	_prompt.theme = preload("res://scenes/ui/menu_theme.tres")
	_prompt.position = Vector2(-70, -112)
	_prompt.text = "E · Duduk"
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.hide()
	add_child(_prompt)
	_prompt.pressed.connect(interact)
	body_entered.connect(_entered)
	body_exited.connect(_exited)


func _entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player = body
		_prompt.show()


func _exited(body: Node2D) -> void:
	if body == _player and not seated:
		_player = null
		_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and interact():
		get_viewport().set_input_as_handled()


func interact() -> bool:
	if not is_instance_valid(_player) or SceneTransition.is_active():
		return false
	if seated:
		stand()
		return true
	if not overlaps_body(_player) or _player.is_studying():
		return false
	seated = true
	_player.set_studying(true)
	var visual := _player.get_node("Visual") as Node2D
	visual.scale.x = absf(visual.scale.x)
	update_seat()
	_prompt.text = "E · Berdiri"
	_prompt.show()
	return true


func update_seat() -> void:
	if seated and is_instance_valid(_player):
		_player.global_position = global_position + seat_offset


func stand() -> void:
	if not seated or not is_instance_valid(_player):
		return
	seated = false
	_player.set_studying(false)
	_player.global_position = global_position + Vector2(-28, 2)
	_prompt.text = "E · Duduk"
	_prompt.visible = overlaps_body(_player)


func _exit_tree() -> void:
	if seated and is_instance_valid(_player) and _player.is_inside_tree():
		_player.set_studying(false)
