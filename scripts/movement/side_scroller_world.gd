extends Node2D

@export var world_title: String = "WORLD 01 · HALAMAN KAMPUS"
@export_file("*.tscn") var left_destination: String
@export_file("*.tscn") var right_destination: String

var _transitioning: bool = false
var _campus_map: Node2D

@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	if scene_file_path in ["res://scenes/movement/top_down_movement.tscn", "res://scenes/movement/dorm_exterior.tscn"]:
		_campus_map = preload("res://scripts/movement/campus_map.gd").new()
		_campus_map.name = "CampusMap"
		add_child(_campus_map)
	$LeftExit.body_entered.connect(_on_exit_entered.bind(left_destination, &"RightSpawn"))
	$RightExit.body_entered.connect(_on_exit_entered.bind(right_destination, &"LeftSpawn"))
	var spawn: StringName = get_tree().get_meta(&"side_scroller_spawn", &"InitialSpawn")
	if get_tree().has_meta(&"side_scroller_spawn"):
		get_tree().remove_meta(&"side_scroller_spawn")
	var marker := get_node_or_null(NodePath(spawn)) as Marker2D
	if marker != null:
		_player.position = marker.position
	GameSave.register_world(self, _player)
	_player.get_node("Camera2D").reset_smoothing()


func _on_exit_entered(body: Node2D, destination: String, spawn: StringName) -> void:
	if body != _player or _transitioning or destination.is_empty():
		return
	_transitioning = true
	_change_world.call_deferred(destination, spawn)


func _change_world(destination: String, spawn: StringName) -> void:
	get_tree().set_meta(&"side_scroller_spawn", spawn)
	var error := get_tree().change_scene_to_file(destination)
	if error != OK:
		get_tree().remove_meta(&"side_scroller_spawn")
		_transitioning = false


func get_player_save_position(player: CharacterBody2D) -> Vector2:
	if is_instance_valid(_campus_map):
		return Vector2(80 + clampf((player.position.x - 22) / (_campus_map.WIDTH - 44), 0, 1) * 1760, 400)
	if scene_file_path.get_file().begins_with("dorm_floor"):
		return Vector2(80 + clampf((player.position.x - 22) / 3028.0, 0, 1) * 1760, 400)
	return Vector2(clampf(player.position.x, 80, 1840), clampf(player.position.y, 0, 592))


func restore_player_position(player: CharacterBody2D, saved: Vector2) -> void:
	if is_instance_valid(_campus_map) or scene_file_path.get_file().begins_with("dorm_floor"):
		var width: float = _campus_map.WIDTH if is_instance_valid(_campus_map) else 3072.0
		var x: float = 22 + (saved.x - 80) / 1760.0 * (width - 44) if saved.y == 400 else saved.x
		player.position = Vector2(clampf(x, 22, width - 22), 592)
	else:
		player.position = saved
