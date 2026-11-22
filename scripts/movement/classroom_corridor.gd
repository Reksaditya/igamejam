extends "res://scripts/movement/side_scroller_world.gd"

const BACKGROUNDS := [preload("res://assets/classroom/corridor/floor1.png"), preload("res://assets/classroom/corridor/floor2.png"), preload("res://assets/classroom/corridor/floor3.png")]

@export_range(1, 3) var floor_number: int = 1

func _ready() -> void:
	$Background.hide()
	$Stairs.available = floor_number < 3
	$Stairs.monitoring = floor_number < 3
	$Stairs.visible = floor_number < 3
	$StairsDown.available = floor_number > 1
	$StairsDown.monitoring = floor_number > 1
	$StairsDown.visible = floor_number > 1
	$Stairs.interaction_requested.connect(_use_stairs.bind(1))
	$StairsDown.interaction_requested.connect(_use_stairs.bind(-1))
	$Stairs/Prompt.text = "E · Naik ke lantai %d" % (floor_number + 1)
	$StairsDown/Prompt.text = "E · Turun ke lantai %d" % (floor_number - 1)
	super._ready()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 720), Color("#b69771"))
	draw_texture_rect(BACKGROUNDS[floor_number - 1], Rect2(0, 80, 1920, 540), false)
	draw_rect(Rect2(0, 620, 1920, 100), Color("#ffe7b5"))


func _use_stairs(direction: int) -> void:
	var destination_floor := floor_number + direction
	if SceneTransition.is_active() or destination_floor < 1 or destination_floor > 3:
		return
	var spawn: StringName = &"DownstairsSpawn" if direction > 0 else &"UpstairsSpawn"
	_travel.call_deferred(destination_floor, spawn)


func _travel(destination_floor: int, spawn: StringName) -> void:
	SceneTransition.change_scene("res://scenes/movement/classroom_corridor_floor%d.tscn" % destination_floor, spawn)
