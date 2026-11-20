extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0

@onready var _facing: Polygon2D = $Visual/Facing


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector2
	if absf(input_direction.x) > absf(input_direction.y):
		direction = Vector2(signf(input_direction.x), 0.0)
	else:
		direction = Vector2(0.0, signf(input_direction.y))

	var speed: float = run_speed if Input.is_action_pressed("run") else walk_speed
	velocity = direction * speed * input_direction.length()

	if direction != Vector2.ZERO:
		_facing.rotation = direction.angle()

	move_and_slide()
