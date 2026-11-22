extends Control

signal resolved(success: bool)

const FONT := preload("res://assets/fonts/pixelify_sans/pixelify_sans.ttf")

@export_range(1.0, 10.0, 0.1) var starting_duration_seconds: float = 3.0
@export_range(1.0, 10.0, 0.1) var ending_duration_seconds: float = 1.8
@export_range(0.05, 0.4, 0.01) var starting_target_width: float = 0.18
@export_range(0.05, 0.4, 0.01) var ending_target_width: float = 0.1

var duration_seconds: float = 3.0
var target_width: float = 0.18

var _elapsed: float = 0.0
var _target_start: float = 0.5
var _active: bool = false
var _outcome: int = 0


func _ready() -> void:
	resized.connect(queue_redraw)


func start(material_index: int = 0, material_count: int = 1) -> void:
	var progress := clampf(float(material_index) / maxi(1, material_count - 1), 0.0, 1.0)
	var difficulty := clampf((progress - 0.5) * 2.0, 0.0, 1.0)
	duration_seconds = lerpf(starting_duration_seconds, minf(starting_duration_seconds, ending_duration_seconds), difficulty)
	target_width = lerpf(starting_target_width, minf(starting_target_width, ending_target_width), difficulty)
	_elapsed = 0.0
	_target_start = randf_range(0.4, 0.7 - target_width)
	_active = true
	_outcome = 0
	grab_focus()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= duration_seconds:
		_resolve(false)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active or not event.is_action_pressed("class_focus") or event.is_echo():
		return
	var progress := _elapsed / duration_seconds
	get_viewport().set_input_as_handled()
	_resolve(progress >= _target_start and progress <= _target_start + target_width)


func _resolve(success: bool) -> void:
	if not _active:
		return
	_active = false
	_outcome = 1 if success else -1
	queue_redraw()
	resolved.emit(success)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.39
	draw_circle(center, radius - 8, Color("#172b3d"))
	var font_size := maxi(12, int(radius * 0.4))
	var text_width := FONT.get_string_size("SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(FONT, center + Vector2(-text_width * 0.5, font_size * 0.35), "SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#fff1d2"))
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 96, Color("#3d566d"), 12.0, true)
	draw_arc(center, radius, _target_start * TAU - PI * 0.5, (_target_start + target_width) * TAU - PI * 0.5, 32, Color("#8fd4a3"), 14.0, true)
	var angle := clampf(_elapsed / duration_seconds, 0.0, 1.0) * TAU - PI * 0.5
	var ink := Color("#ffda90")
	if _outcome != 0:
		ink = Color("#8fd4a3") if _outcome > 0 else Color("#ef8b83")
	draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, 10.0, ink, true, -1.0, true)
