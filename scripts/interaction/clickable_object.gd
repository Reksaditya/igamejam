extends Area2D

signal clicked

@export var alternate_color: Color = Color(0.98, 0.76, 0.36)

var _next_color: Color

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	_next_color = alternate_color


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var previous_color: Color = _visual.color
		_visual.color = _next_color
		_next_color = previous_color
		clicked.emit()
