@tool
extends Button

signal open_requested(launcher: Button)

enum IconKind { TEXT_DOCUMENT, IMAGE, NOTEPAD, BROWSER, FOLDER, BOOK, BLUEPRINT, BLOCKS }

const ITEM_SIZE := Vector2(126, 96)
const CAPTION_WIDTH: float = 118.0
const INK: Color = Color("#172440")
const PAPER: Color = Color("#fff1cf")
const BLUE: Color = Color("#546faa")

@export var display_title: String = "App":
	set(value):
		display_title = value
		_update_caption()

@export var icon_kind: IconKind = IconKind.TEXT_DOCUMENT:
	set(value):
		icon_kind = value
		queue_redraw()

@export var app_scene: PackedScene
@export var preferred_window_size := Vector2(512, 330)
@export var minimum_window_size := Vector2(260, 180)

var _caption: Label
var _box_selected := false


func _ready() -> void:
	custom_minimum_size = custom_minimum_size.max(ITEM_SIZE)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.theme_type_variation = &"FileCaption" if theme_type_variation == &"FileItem" else &"DesktopCaption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.max_lines_visible = 2
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_caption)
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.offset_left = -CAPTION_WIDTH * 0.5
	_caption.offset_right = CAPTION_WIDTH * 0.5
	_caption.offset_top = 50
	_caption.offset_bottom = ITEM_SIZE.y - 2
	_update_caption()

	if not Engine.is_editor_hint():
		pressed.connect(func() -> void: open_requested.emit(self))


func _update_caption() -> void:
	accessibility_name = display_title
	tooltip_text = display_title
	if is_instance_valid(_caption):
		_caption.text = display_title


func set_box_selected(selected: bool) -> void:
	if _box_selected != selected:
		_box_selected = selected
		queue_redraw()


func _draw() -> void:
	if _box_selected:
		draw_style_box(get_theme_stylebox("selected", "DesktopItem"), Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2(floorf((size.x - 40.0) / 2.0), 7.0))
	match icon_kind:
		IconKind.FOLDER:
			draw_rect(Rect2(2, 7, 18, 8), INK)
			draw_rect(Rect2(2, 13, 37, 24), INK)
			draw_rect(Rect2(4, 9, 14, 8), Color("#f6bf70"))
			draw_rect(Rect2(4, 15, 33, 20), Color("#f6bf70"))
		IconKind.TEXT_DOCUMENT:
			draw_colored_polygon(PackedVector2Array([Vector2(6, 38), Vector2(6, 2), Vector2(25, 2), Vector2(35, 12), Vector2(35, 38)]), INK)
			draw_colored_polygon(PackedVector2Array([Vector2(8, 36), Vector2(8, 4), Vector2(24, 4), Vector2(33, 13), Vector2(33, 36)]), PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(24, 4), Vector2(24, 13), Vector2(33, 13)]), BLUE)
			for y: int in [17, 23, 29]:
				draw_rect(Rect2(12, y, 16, 2), INK)
		IconKind.IMAGE:
			draw_rect(Rect2(1, 5, 38, 31), INK)
			draw_rect(Rect2(3, 7, 34, 27), PAPER)
			draw_rect(Rect2(6, 10, 28, 21), Color("#a8dcf1"))
			draw_rect(Rect2(24, 13, 5, 5), Color("#f6b95d"))
			draw_colored_polygon(PackedVector2Array([Vector2(6, 31), Vector2(16, 17), Vector2(24, 27), Vector2(28, 22), Vector2(34, 31)]), Color("#28796e"))
		IconKind.NOTEPAD:
			draw_rect(Rect2(6, 5, 30, 33), INK)
			draw_rect(Rect2(8, 8, 26, 28), Color("#f6bf70"))
			draw_rect(Rect2(11, 13, 20, 20), PAPER)
			for x: int in [11, 18, 25, 32]:
				draw_rect(Rect2(x, 2, 2, 10), INK)
			for y: int in [18, 23, 28]:
				draw_rect(Rect2(14, y, 13, 1), BLUE)
		IconKind.BROWSER:
			draw_rect(Rect2(1, 5, 38, 31), INK)
			draw_rect(Rect2(3, 7, 34, 27), Color("#8ad8c7"))
			draw_rect(Rect2(3, 7, 34, 8), BLUE)
			draw_rect(Rect2(7, 10, 4, 2), PAPER)
			draw_rect(Rect2(7, 19, 26, 3), PAPER)
			draw_rect(Rect2(7, 26, 18, 2), INK)
			draw_rect(Rect2(7, 30, 12, 2), INK)

		IconKind.BOOK:
			draw_rect(Rect2(5, 2, 30, 36), INK)
			draw_rect(Rect2(7, 4, 25, 30), Color("#a94d58"))
			draw_rect(Rect2(8, 32, 24, 4), PAPER)
			draw_rect(Rect2(10, 4, 3, 28), INK)
			draw_rect(Rect2(17, 11, 10, 2), PAPER)

		IconKind.BLUEPRINT:
			draw_rect(Rect2(2, 6, 36, 29), INK)
			draw_rect(Rect2(4, 8, 32, 25), Color("#27566f"))
			draw_circle(Vector2(19, 20), 5, PAPER, false, 1.0)
			draw_polyline(PackedVector2Array([Vector2(8, 15), Vector2(13, 15), Vector2(14, 20), Vector2(24, 20), Vector2(28, 26), Vector2(33, 26)]), Color("#94d8e6"), 1.5)

		IconKind.BLOCKS:
			draw_rect(Rect2(3, 3, 34, 34), INK)
			draw_rect(Rect2(5, 5, 30, 30), Color("#203f53"))
			for cell: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2)]:
				var fill := Color("#71d3b0") if cell.x < 2 else Color("#f6bf70")
				draw_rect(Rect2(Vector2(7, 7) + Vector2(cell) * 7, Vector2.ONE * 6), fill)


func get_attachment_metadata() -> Dictionary:
	return {}


func create_app() -> Control:
	if app_scene == null:
		return null
	var instance: Node = app_scene.instantiate()
	if instance is Control:
		return instance
	instance.free()
	return null
