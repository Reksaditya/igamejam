extends CharacterBody2D

@export var walk_speed: float = 220.0
@export var run_speed: float = 340.0
@export var gravity: float = 1200.0
@export var maximum_fall_speed: float = 900.0

@onready var _visual: Node2D = $Visual


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)
	if not is_zero_approx(direction):
		_visual.scale.x = absf(_visual.scale.x) * signf(direction)
	move_and_slide()
