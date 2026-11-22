extends "res://scripts/movement/side_scroller_world.gd"

const ActivityPanel = preload("res://scripts/ui/activity_panel.gd")
const BACKGROUNDS := [preload("res://assets/classroom/corridor/floor1.png"), preload("res://assets/classroom/corridor/floor2.png"), preload("res://assets/classroom/corridor/floor3.png")]

@export_range(1, 3) var floor_number: int = 1

var _stairs_panel: CanvasLayer


func _ready() -> void:
	$Background.hide()
	$Stairs.available = true
	$Stairs.interaction_requested.connect(_use_stairs)
	$Stairs/Prompt.text = "E · Pilih lantai" if floor_number == 2 else ("E · Naik ke lantai 2" if floor_number == 1 else "E · Turun ke lantai 2")
	super._ready()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 720), Color("#b69771"))
	draw_texture_rect(BACKGROUNDS[floor_number - 1], Rect2(0, 80, 1920, 540), false)
	draw_rect(Rect2(0, 620, 1920, 100), Color("#ffe7b5"))


func _use_stairs() -> void:
	if SceneTransition.is_active() or is_instance_valid(_stairs_panel):
		return
	if floor_number != 2:
		_travel.call_deferred("res://scenes/movement/classroom_corridor_floor2.tscn")
		return
	_stairs_panel = ActivityPanel.new()
	add_child(_stairs_panel)
	_stairs_panel.label("Tangga · Lantai 2", 26)
	_stairs_panel.button("Naik ke lantai 3", _travel.bind("res://scenes/movement/classroom_corridor_floor3.tscn"))
	_stairs_panel.button("Turun ke lantai 1", _travel.bind("res://scenes/movement/classroom_corridor_floor1.tscn"))
	_stairs_panel.add_close()
	_stairs_panel.closed.connect(func(): _stairs_panel = null)


func _travel(destination: String) -> void:
	if is_instance_valid(_stairs_panel):
		_stairs_panel.close()
	SceneTransition.change_scene(destination, &"StairsSpawn")
