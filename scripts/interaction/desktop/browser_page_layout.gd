extends MarginContainer

@export var max_content_width := 680.0
@export var min_side_margin := 22


func _ready() -> void:
	resized.connect(_update_side_margins)
	_update_side_margins.call_deferred()


func _update_side_margins() -> void:
	if size.x <= 0.0:
		return
	var side := maxi(min_side_margin, int(floorf((size.x - max_content_width) * 0.5)))
	if get_theme_constant("margin_left") != side or get_theme_constant("margin_right") != side:
		add_theme_constant_override("margin_left", side)
		add_theme_constant_override("margin_right", side)
