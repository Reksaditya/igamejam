extends CharacterBody2D

@export var walk_speed: float = 220.0
@export var run_speed: float = 340.0
@export var gravity: float = 1200.0
@export var maximum_fall_speed: float = 900.0
@export_range(0, 10, 0.1) var side_idle_seconds: float = 3.0
@export_range(0.05, 0.5, 0.01) var idle_blend_seconds: float = 0.2

var _studying: bool = false
var _standing_scale: Vector2
var _side_idle_remaining: float = 0.0
var _idle_previous: AnimatedSprite2D
var _idle_blend: Tween
var _seated_elapsed: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var _sprite_home: Vector2 = _sprite.position


func _ready() -> void:
	_idle_previous = _sprite.duplicate() as AnimatedSprite2D
	_idle_previous.name = "IdleTransition"
	_idle_previous.autoplay = ""
	_idle_previous.hide()
	_visual.add_child(_idle_previous)
	_idle_previous.stop()


func _physics_process(delta: float) -> void:
	if _studying:
		velocity = Vector2.ZERO
		_update_animation(false)
		_seated_elapsed += delta
		_sprite.position.y = _sprite_home.y + sin(_seated_elapsed * TAU * 0.6) * 0.35
		return
	var direction := Input.get_axis("move_left", "move_right")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)
	if not is_zero_approx(direction):
		_visual.scale.x = absf(_visual.scale.x) * signf(direction)
	move_and_slide()
	if is_on_floor() and not is_zero_approx(velocity.x):
		_side_idle_remaining = side_idle_seconds
	else:
		_side_idle_remaining = maxf(0, _side_idle_remaining - delta)
	_update_animation(is_zero_approx(direction) and is_on_floor())


func _update_animation(idle: bool) -> void:
	if _studying:
		_cancel_idle_blend()
		_sprite.flip_h = false
		if _sprite.animation != &"sit" or not _sprite.is_playing():
			_sprite.play(&"sit")
		return
	if not is_on_floor():
		_cancel_idle_blend()
		_sprite.animation = &"idle"
		_sprite.flip_h = false
		_sprite.stop()
		_sprite.frame = 0
		return
	var animation: StringName = &"walk"
	if idle or is_zero_approx(velocity.x):
		animation = &"side_idle" if _side_idle_remaining > 0 else &"idle"
	var blend := _sprite.animation != animation and _sprite.animation in [&"side_idle", &"idle"] and animation in [&"side_idle", &"idle"]
	if blend:
		_begin_idle_blend()
	elif animation == &"walk":
		_cancel_idle_blend()
	_sprite.flip_h = animation in [&"walk", &"side_idle"]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _begin_idle_blend() -> void:
	_cancel_idle_blend()
	_idle_previous.animation = _sprite.animation
	_idle_previous.frame = _sprite.frame
	_idle_previous.flip_h = _sprite.flip_h
	_idle_previous.position = _sprite.position
	_idle_previous.modulate.a = 1.0
	_idle_previous.show()
	_sprite.modulate.a = 0.0
	_idle_blend = create_tween().set_parallel(true)
	_idle_blend.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_blend.tween_property(_idle_previous, "modulate:a", 0.0, idle_blend_seconds)
	_idle_blend.tween_property(_sprite, "modulate:a", 1.0, idle_blend_seconds)
	_idle_blend.finished.connect(func():
		_idle_previous.hide()
		_idle_blend = null
	)


func _cancel_idle_blend() -> void:
	if _idle_blend != null:
		_idle_blend.kill()
		_idle_blend = null
	if is_instance_valid(_idle_previous):
		_idle_previous.hide()
	_sprite.modulate.a = 1.0


func set_studying(studying: bool) -> void:
	if _studying == studying:
		return
	_studying = studying
	velocity = Vector2.ZERO
	_cancel_idle_blend()
	_seated_elapsed = 0.0
	_sprite.position = _sprite_home
	if studying:
		_side_idle_remaining = 0.0
		_standing_scale = _visual.scale
		_visual.scale.x = absf(_visual.scale.x)
		_update_animation(false)
	else:
		_visual.scale = _standing_scale
		_update_animation(is_on_floor())


func is_studying() -> bool:
	return _studying
