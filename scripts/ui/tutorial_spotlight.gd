class_name TutorialSpotlight
extends CanvasLayer

signal step_changed(index: int, total: int)
signal finished

const HUD_FONT: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")
const DIM_COLOR := Color(0.05, 0.05, 0.06, 0.58)
const FRAME_COLOR := Color("#f0f0f2")
const FRAME_GLOW := Color(0.95, 0.84, 0.55, 0.55)
const CALLOUT_BG := Color("#161618f5")
const CALLOUT_BORDER := Color("#5a5a64")
const TEXT_COLOR := Color("#f0f0f2")
const MUTED_COLOR := Color("#a0a0aa")
const FADE_IN_SECONDS := 0.25
const FADE_OUT_SECONDS := 0.20


class SpotlightBackdrop extends Control:
	var hole_rect := Rect2()
	var callout_rect := Rect2()
	var pulse_phase: float = 0.0


	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		if hole_rect.size.x <= 1.0 or hole_rect.size.y <= 1.0:
			draw_rect(full, DIM_COLOR)
			return

		var r := Rect2(hole_rect.position.floor(), hole_rect.size.ceil())
		# 4 dimmed bands around the cutout so the highlighted control stays crisp and bright.
		if r.position.y > 0.0:
			draw_rect(Rect2(0.0, 0.0, size.x, r.position.y), DIM_COLOR)
		if r.end.y < size.y:
			draw_rect(Rect2(0.0, r.end.y, size.x, size.y - r.end.y), DIM_COLOR)
		if r.position.x > 0.0:
			draw_rect(Rect2(0.0, r.position.y, r.position.x, r.size.y), DIM_COLOR)
		if r.end.x < size.x:
			draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), DIM_COLOR)

		# Subtle outer pulse + sharp pixel-aligned squared border.
		var glow_alpha := 0.30 + 0.28 * (0.5 + 0.5 * sin(pulse_phase * 4.2))
		var glow := Color(FRAME_GLOW.r, FRAME_GLOW.g, FRAME_GLOW.b, glow_alpha)
		draw_rect(r.grow(3.0), glow, false, 2.0)
		draw_rect(r, FRAME_COLOR, false, 2.0)

		# Crisp corner ticks for squared tactical framing.
		var tick := minf(10.0, minf(r.size.x, r.size.y) * 0.35)
		var accent := Color("#f2c46d")
		draw_line(r.position, r.position + Vector2(tick, 0.0), accent, 2.0)
		draw_line(r.position, r.position + Vector2(0.0, tick), accent, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - tick, r.position.y), accent, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + tick), accent, 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + tick, r.end.y), accent, 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - tick), accent, 2.0)
		draw_line(r.end, r.end - Vector2(tick, 0.0), accent, 2.0)
		draw_line(r.end, r.end - Vector2(0.0, tick), accent, 2.0)

		# Small directional triangle pointer connecting the callout tag to the squared frame.
		if callout_rect.size.x > 1.0 and callout_rect.size.y > 1.0:
			_draw_pointer(r, callout_rect)


	func _draw_pointer(target: Rect2, tag: Rect2) -> void:
		var tri := PackedVector2Array()
		if tag.position.y >= target.end.y - 2.0:
			# Callout is below target -> upward pointer on top edge of callout.
			var px := clampf(target.get_center().x, tag.position.x + 14.0, tag.end.x - 14.0)
			var py := tag.position.y
			tri = PackedVector2Array([Vector2(px, py - 8.0), Vector2(px - 7.0, py + 1.0), Vector2(px + 7.0, py + 1.0)])
		elif tag.end.y <= target.position.y + 2.0:
			# Callout is above target -> downward pointer on bottom edge of callout.
			var px := clampf(target.get_center().x, tag.position.x + 14.0, tag.end.x - 14.0)
			var py := tag.end.y
			tri = PackedVector2Array([Vector2(px, py + 8.0), Vector2(px - 7.0, py - 1.0), Vector2(px + 7.0, py - 1.0)])
		elif tag.position.x >= target.end.x - 2.0:
			# Callout is to the right -> left pointer on left edge of callout.
			var px := tag.position.x
			var py := clampf(target.get_center().y, tag.position.y + 14.0, tag.end.y - 14.0)
			tri = PackedVector2Array([Vector2(px - 8.0, py), Vector2(px + 1.0, py - 7.0), Vector2(px + 1.0, py + 7.0)])
		elif tag.end.x <= target.position.x + 2.0:
			# Callout is to the left -> right pointer on right edge of callout.
			var px := tag.end.x
			var py := clampf(target.get_center().y, tag.position.y + 14.0, tag.end.y - 14.0)
			tri = PackedVector2Array([Vector2(px + 8.0, py), Vector2(px - 1.0, py - 7.0), Vector2(px - 1.0, py + 7.0)])
		if tri.size() == 3:
			draw_colored_polygon(tri, CALLOUT_BG)
			draw_polyline(PackedVector2Array([tri[1], tri[0], tri[2]]), CALLOUT_BORDER, 1.5, true)


var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _closing: bool = false
var _root: Control
var _backdrop: SpotlightBackdrop
var _callout: PanelContainer
var _counter_label: Label
var _caption_label: Label
var _skip_button: Button
var _next_button: Button
var _fade_tween: Tween


func _init() -> void:
	layer = 25


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)

	_backdrop = SpotlightBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	_root.add_child(_backdrop)

	_callout = PanelContainer.new()
	_callout.name = &"TutorialCallout"
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = CALLOUT_BG
	style.border_color = CALLOUT_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	_callout.add_theme_stylebox_override("panel", style)
	_root.add_child(_callout)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_callout.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_counter_label = Label.new()
	_counter_label.add_theme_font_override("font", HUD_FONT)
	_counter_label.add_theme_font_size_override("font_size", 12)
	_counter_label.add_theme_color_override("font_color", Color("#f2c46d"))
	top_row.add_child(_counter_label)

	_caption_label = Label.new()
	_caption_label.add_theme_font_override("font", HUD_FONT)
	_caption_label.add_theme_font_size_override("font_size", 14)
	_caption_label.add_theme_color_override("font_color", TEXT_COLOR)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.custom_minimum_size.x = 240.0
	top_row.add_child(_caption_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	vbox.add_child(actions)

	_skip_button = _make_button("Lewati", false)
	_skip_button.name = &"SkipButton"
	_skip_button.pressed.connect(skip)
	actions.add_child(_skip_button)

	_next_button = _make_button("Lanjut", true)
	_next_button.name = &"NextButton"
	_next_button.pressed.connect(advance)
	actions.add_child(_next_button)

	get_viewport().size_changed.connect(_refresh_geometry, CONNECT_DEFERRED)


func _make_button(label_text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", HUD_FONT)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", TEXT_COLOR if primary else MUTED_COLOR)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#2a2a30") if primary else Color("#1c1c20")
	normal.border_color = Color("#70707a") if primary else Color("#3c3c44")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3a3a42") if primary else Color("#28282e")
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#f2c46d")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", focus)
	return btn


func start(steps: Array[Dictionary]) -> void:
	_steps = steps
	_step_index = 0
	_closing = false
	if _steps.is_empty():
		_finish_immediately()
		return
	_begin_after_layout.call_deferred()


func _begin_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_apply_step()
	_fade_to(1.0, FADE_IN_SECONDS)
	_next_button.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if is_instance_valid(_backdrop):
		_backdrop.pulse_phase += delta
		_refresh_geometry()


func _input(event: InputEvent) -> void:
	if _closing or not visible or not is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			advance()
			get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			advance()
			get_viewport().set_input_as_handled()


func current_step_index() -> int:
	return _step_index


func step_count() -> int:
	return _steps.size()


func get_highlight_rect() -> Rect2:
	return _backdrop.hole_rect if is_instance_valid(_backdrop) else Rect2()


func get_caption_text() -> String:
	return _caption_label.text if is_instance_valid(_caption_label) else ""


func advance() -> void:
	if _closing:
		return
	if _step_index + 1 < _steps.size():
		_step_index += 1
		_apply_step()
	else:
		_close_with_fade()


func skip() -> void:
	if _closing:
		return
	_close_with_fade()


func dismiss_immediately() -> void:
	_finish_immediately()


func _apply_step() -> void:
	if _step_index < 0 or _step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_step_index]
	_counter_label.text = "%d/%d" % [_step_index + 1, _steps.size()]
	_caption_label.text = str(step.get("caption", ""))
	_next_button.text = "Selesai" if _step_index == _steps.size() - 1 else "Lanjut"
	_skip_button.visible = _step_index < _steps.size() - 1
	_callout.reset_size()
	_refresh_geometry()
	step_changed.emit(_step_index, _steps.size())


func _resolve_step_rect(step: Dictionary) -> Rect2:
	var pad := float(step.get("pad", 6.0))
	var target: Variant = step.get("target", null)
	if target is Control and is_instance_valid(target):
		var ctrl := target as Control
		if ctrl.is_visible_in_tree():
			var rect := ctrl.get_global_rect()
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				return rect.grow(pad)
	var provider: Variant = step.get("rect_provider", null)
	if provider is Callable and (provider as Callable).is_valid():
		var custom: Variant = (provider as Callable).call()
		if custom is Rect2:
			var rect := custom as Rect2
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				return rect.grow(pad)
	var fallback: Variant = step.get("fallback_target", null)
	if fallback is Control and is_instance_valid(fallback):
		var fb := fallback as Control
		var rect := fb.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			return rect.grow(pad)
	return Rect2()


func _refresh_geometry() -> void:
	if not is_inside_tree() or get_viewport() == null or not is_instance_valid(_backdrop) or _step_index >= _steps.size():
		return
	var view_size := _backdrop.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = get_viewport().get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	var hole := _resolve_step_rect(_steps[_step_index])
	if hole.size.x > 1.0 and hole.size.y > 1.0:
		hole.size.x = minf(hole.size.x, maxf(8.0, view_size.x - 8.0))
		hole.size.y = minf(hole.size.y, maxf(8.0, view_size.y - 8.0))
		hole.position.x = clampf(hole.position.x, 4.0, maxf(4.0, view_size.x - hole.size.x - 4.0))
		hole.position.y = clampf(hole.position.y, 4.0, maxf(4.0, view_size.y - hole.size.y - 4.0))
	_backdrop.hole_rect = hole

	var tag_size := _callout.get_combined_minimum_size()
	tag_size.x = maxf(tag_size.x, 260.0)
	_callout.size = tag_size
	var pos := _compute_callout_position(hole, tag_size, view_size)
	_callout.position = pos.round()
	_backdrop.callout_rect = Rect2(_callout.position, _callout.size)
	_backdrop.queue_redraw()


func _compute_callout_position(hole: Rect2, tag_size: Vector2, view_size: Vector2) -> Vector2:
	var margin := 12.0
	var gap := 12.0
	if hole.size.x <= 1.0 or hole.size.y <= 1.0:
		return (view_size - tag_size) * 0.5

	var pos := Vector2.ZERO
	# Prefer below, then above, then right, then left — always clamped inside viewport.
	if hole.end.y + gap + tag_size.y + margin <= view_size.y:
		pos = Vector2(hole.get_center().x - tag_size.x * 0.5, hole.end.y + gap)
	elif hole.position.y - gap - tag_size.y >= margin:
		pos = Vector2(hole.get_center().x - tag_size.x * 0.5, hole.position.y - gap - tag_size.y)
	elif hole.end.x + gap + tag_size.x + margin <= view_size.x:
		pos = Vector2(hole.end.x + gap, hole.get_center().y - tag_size.y * 0.5)
	elif hole.position.x - gap - tag_size.x >= margin:
		pos = Vector2(hole.position.x - gap - tag_size.x, hole.get_center().y - tag_size.y * 0.5)
	else:
		pos = Vector2(hole.get_center().x - tag_size.x * 0.5, view_size.y - tag_size.y - margin)

	pos.x = clampf(pos.x, margin, maxf(margin, view_size.x - tag_size.x - margin))
	pos.y = clampf(pos.y, margin, maxf(margin, view_size.y - tag_size.y - margin))
	return pos


func _fade_to(alpha: float, duration: float, on_done: Callable = Callable()) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.tween_property(_root, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if on_done.is_valid():
		_fade_tween.finished.connect(on_done)


func _close_with_fade() -> void:
	if _closing:
		return
	_closing = true
	_fade_to(0.0, FADE_OUT_SECONDS, _finish_immediately)


func _finish_immediately() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_closing = true
	finished.emit()
	queue_free()
