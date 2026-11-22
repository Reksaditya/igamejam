@tool
extends Button

signal open_requested(launcher: Button)

enum IconKind { TEXT_DOCUMENT, IMAGE, NOTEPAD, BROWSER, FOLDER, BOOK, BLUEPRINT, BLOCKS }

const ITEM_SIZE := Vector2(126, 96)
const CAPTION_WIDTH: float = 118.0
const ICON_DRAW_SIZE := Vector2(40.0, 40.0)
const LAUNCHER_ICONS: Dictionary = {
	IconKind.TEXT_DOCUMENT: preload("res://assets/textures/desktop/icon_document.png"),
	IconKind.IMAGE: preload("res://assets/textures/desktop/icon_image.png"),
	IconKind.NOTEPAD: preload("res://assets/textures/desktop/icon_notepad.png"),
	IconKind.BROWSER: preload("res://assets/textures/desktop/icon_browser.png"),
	IconKind.FOLDER: preload("res://assets/textures/desktop/icon_folder.png"),
	IconKind.BOOK: preload("res://assets/textures/desktop/icon_book.png"),
	IconKind.BLUEPRINT: preload("res://assets/textures/desktop/icon_blueprint.png"),
	IconKind.BLOCKS: preload("res://assets/textures/desktop/icon_blocks.png"),
}

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
@export var default_cell := Vector2i(-1, -1):
	set(value):
		default_cell = value
		if is_inside_tree():
			var parent := get_parent()
			if parent != null and parent.has_method("refresh_layout"):
				parent.call_deferred("refresh_layout")

var _caption: Label
var _box_selected := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var tex := LAUNCHER_ICONS.get(icon_kind) as Texture2D
	if tex != null:
		var origin := Vector2(floorf((size.x - ICON_DRAW_SIZE.x) * 0.5), 7.0)
		draw_texture_rect(tex, Rect2(origin, ICON_DRAW_SIZE), false)


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
