extends Node2D

@export var world_title: String = "WORLD 01 · HALAMAN KAMPUS"
@export_file("*.tscn") var left_destination: String
@export_file("*.tscn") var right_destination: String

var _transitioning: bool = false

@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	if scene_file_path.get_file() != "dorm_room210.tscn":
		GameClock.set_room_paused(false)
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
