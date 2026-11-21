extends Button

var piece_index: int
var silhouette: bool = false


func _ready() -> void:
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_pressed: bool) -> void: queue_redraw())


func _draw() -> void:
	var project := BlueprintProgress.PROJECT
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#10253b"))
	var tint := Color("#496176") if silhouette else Color.WHITE
	draw_texture_rect_region(project.image, rect, project.get_region(piece_index), tint)
	draw_rect(rect.grow(-1.0), Color("#ffcf7d") if has_focus() or button_pressed else Color("#618aa2"), false, 2.0)
