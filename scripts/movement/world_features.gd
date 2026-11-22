extends Node2D

const Interaction = preload("res://scripts/movement/world_interaction.gd")
const DOOR := preload("res://scenes/movement/door_interaction.tscn")


func _ready() -> void:
	var path := get_parent().scene_file_path
	if path == "res://scenes/movement/top_down_movement.tscn":
		var door := DOOR.instantiate()
		door.position = Vector2(1470, 540)
		door.destination = "res://scenes/movement/lecturer_room.tscn"
		door.action_text = "Ruang dosen"
		add_child(door)
		_sign("Ruang Dosen", Vector2(1400, 430))
		var frame := Polygon2D.new()
		frame.polygon = PackedVector2Array([Vector2(1425, 460), Vector2(1515, 460), Vector2(1515, 620), Vector2(1425, 620)])
		frame.color = Color("#527a85")
		add_child(frame)
	elif path == "res://scenes/movement/campus_lab_room.tscn":
		_interaction("workshop", "Mulai merakit mesin", Vector2(650, 540))
		_sign("Bengkel · Meja perakitan", Vector2(460, 450))
	elif path == "res://scenes/movement/lecturer_room.tscn":
		_interaction("lecturer", "Laporkan proyek", Vector2(650, 540))
		_sign("Dosen Teknik · Pengumpulan proyek", Vector2(420, 430))


func _interaction(action: String, caption: String, point: Vector2) -> void:
	var target := Interaction.new()
	target.action = action
	target.caption = caption
	target.position = point
	add_child(target)


func _sign(value: String, point: Vector2) -> void:
	var sign := Label.new()
	sign.text = value
	sign.theme = preload("res://scenes/ui/menu_theme.tres")
	sign.position = point
	add_child(sign)
