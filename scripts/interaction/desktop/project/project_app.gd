extends PanelContainer

const Blueprint = preload("res://scripts/interaction/desktop/project/blueprint.gd")

@export var blueprints: Array[Blueprint]
@export var demo_blueprints := false

var _drawings: Dictionary[String, TextureRect] = {}
var _hints: Dictionary[String, Label] = {}


func _ready() -> void:
	for blueprint: Blueprint in blueprints:
		if blueprint == null or not blueprint.blueprint_id.is_valid_identifier() or blueprint.artwork == null:
			continue
		if not _drawings.has(blueprint.blueprint_id):
			_add_blueprint(blueprint)
	%Empty.visible = _drawings.is_empty()
	ProjectBlueprints.changed.connect(_refresh)
	_refresh()


func _add_blueprint(blueprint: Blueprint) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	%Drawings.add_child(group)

	var title := Label.new()
	title.text = blueprint.title
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#1b3346"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(title)

	var drawing := TextureRect.new()
	drawing.texture = blueprint.artwork
	drawing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drawing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drawing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drawing.custom_minimum_size.y = 210.0
	drawing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.accessibility_name = blueprint.title + " blueprint"
	group.add_child(drawing)
	_drawings[blueprint.blueprint_id] = drawing

	var hint := Label.new()
	hint.text = "Earn this blueprint by completing the class notes or opening its Library book."
	hint.add_theme_color_override("font_color", Color("#314d60"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(hint)
	_hints[blueprint.blueprint_id] = hint


func _refresh() -> void:
	for blueprint_id: String in _drawings:
		var owned := demo_blueprints or ProjectBlueprints.is_owned(blueprint_id)
		_drawings[blueprint_id].visible = owned
		_hints[blueprint_id].visible = not owned
