extends CharacterBody2D

@export var walk_speed: float = 220.0
@export var run_speed: float = 340.0
@export var gravity: float = 1200.0
@export var maximum_fall_speed: float = 900.0

var _studying: bool = false
var _standing_position: Vector2
var _standing_scale: Vector2
var _standing_legs: PackedVector2Array

@onready var _visual: Node2D = $Visual


func _physics_process(delta: float) -> void:
	if _studying:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_axis("move_left", "move_right")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)
	if not is_zero_approx(direction):
		_visual.scale.x = absf(_visual.scale.x) * signf(direction)
	move_and_slide()


func set_studying(studying: bool) -> void:
	if _studying == studying:
		return
	_studying = studying
	velocity = Vector2.ZERO
	var legs := $Visual/Legs as Polygon2D
	if studying:
		_standing_position = _visual.position
		_standing_scale = _visual.scale
		_standing_legs = legs.polygon
		_visual.position += Vector2(0, 8)
		_visual.scale.x = -absf(_visual.scale.x)
		legs.polygon = PackedVector2Array([Vector2(-12, 12), Vector2(20, 12), Vector2(20, 20), Vector2(8, 20), Vector2(8, 22), Vector2(0, 22), Vector2(0, 19), Vector2(-12, 19)])
	else:
		_visual.position = _standing_position
		_visual.scale = _standing_scale
		legs.polygon = _standing_legs


func is_studying() -> bool:
	return _studying
