extends Node2D

var player: CharacterBody2D
var _caught: bool = false


func _draw() -> void:
	draw_circle(Vector2(0, -64), 14, Color("#bf9983"))
	draw_rect(Rect2(-17, -52, 34, 9), Color("#24364d"))
	draw_rect(Rect2(-16, -42, 32, 35), Color("#456a83"))
	draw_rect(Rect2(-14, -7, 10, 25), Color("#24364d"))
	draw_rect(Rect2(4, -7, 10, 25), Color("#24364d"))


func _physics_process(delta: float) -> void:
	if _caught or not is_instance_valid(player) or player.is_studying() or SceneTransition.is_active():
		return
	position.x = move_toward(position.x, player.position.x, 430.0 * delta)
	if absf(position.x - player.position.x) < 38:
		_caught = true
		SceneTransition.change_scene("res://scenes/movement/dorm_floor1.tscn", &"InteriorSpawn")
