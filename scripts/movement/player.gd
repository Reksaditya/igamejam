extends CharacterBody2D

@export var walk_speed: float = 220.0
@export var run_speed: float = 340.0
@export var gravity: float = 1200.0
@export var maximum_fall_speed: float = 900.0

var _studying: bool = false
var _standing_scale: Vector2

@onready var _visual: Node2D = $Visual
@onready var _sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if _studying:
		velocity = Vector2.ZERO
		_update_animation(false)
		return
	var direction := Input.get_axis("move_left", "move_right")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)
	if not is_zero_approx(direction):
		_visual.scale.x = absf(_visual.scale.x) * signf(direction)
	move_and_slide()
	_update_animation(is_zero_approx(direction) and is_on_floor())


func _update_animation(idle: bool) -> void:
	if idle:
		if not _sprite.is_playing():
			_sprite.play(&"idle")
	else:
		_sprite.stop()
		_sprite.frame = 0


func set_studying(studying: bool) -> void:
	if _studying == studying:
		return
	_studying = studying
	velocity = Vector2.ZERO
	if studying:
		_standing_scale = _visual.scale
		_visual.scale.x = -absf(_visual.scale.x)
		_update_animation(false)
	else:
		_visual.scale = _standing_scale
		_update_animation(is_on_floor())


func is_studying() -> bool:
	return _studying
