extends CanvasLayer

const PORTRAIT := preload("res://assets/characters/mc/idle/1.png")
const MENU_THEME := preload("res://scenes/ui/menu_theme.tres")
const HUD_FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")
const CLOCK_DAY_ACCENT := Color("#ffd277")
const CLOCK_NIGHT_ACCENT := Color("#91bde9")
const HUD_SURFACE := Color("#0d1824e8")
const HUD_INK := Color("#f9faf5")
const HUD_MUTED := Color("#a5bccd")


class DayNightDial extends Control:
	const DIAL_SIZE := Vector2(72.0, 72.0)
	const BODY_EXTENT := 7.5
	const STARS := [
		Vector2(-0.52, -0.44),
		Vector2(-0.22, -0.62),
		Vector2(0.16, -0.58),
		Vector2(0.50, -0.36),
		Vector2(-0.04, -0.32),
	]

	var minute_of_day: int = 360


	func _init() -> void:
		custom_minimum_size = DIAL_SIZE
		size = DIAL_SIZE
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func set_minute_of_day(value: int) -> void:
		var normalized := posmod(value, GameClock.MINUTES_PER_DAY)
		if minute_of_day == normalized:
			return
		minute_of_day = normalized
		queue_redraw()


	func is_daytime() -> bool:
		return minute_of_day >= 360 and minute_of_day < 1080


	func phase_progress() -> float:
		if is_daytime():
			return clampf(float(minute_of_day - 360) / 720.0, 0.0, 1.0)
		var night_elapsed := posmod(minute_of_day - 1080, GameClock.MINUTES_PER_DAY)
		return clampf(float(night_elapsed) / 720.0, 0.0, 1.0)


	func get_sky_radius() -> float:
		var side := minf(size.x, size.y)
		return maxf(8.0, side * 0.5 - 8.0)


	func get_celestial_center() -> Vector2:
		var center := size * 0.5
		var sky_r := get_sky_radius()
		var arc_origin := center + Vector2(0.0, sky_r * 0.22)
		var arc_r := sky_r * 0.58
		var angle := lerpf(0.32, PI - 0.32, phase_progress())
		var raw := arc_origin + Vector2(-cos(angle) * arc_r, -sin(angle) * arc_r)
		var max_offset := maxf(0.0, sky_r - BODY_EXTENT - 2.0)
		var offset := raw - center
		if offset.length() > max_offset and offset.length() > 0.001:
			raw = center + offset.normalized() * max_offset
		var margin := BODY_EXTENT + 2.0
		raw.x = clampf(raw.x, margin, maxf(margin, size.x - margin))
		raw.y = clampf(raw.y, margin, maxf(margin, size.y - margin))
		return raw


	func _draw() -> void:
		var center := size * 0.5
		var sky_r := get_sky_radius()
		var daytime := is_daytime()
		var accent := CLOCK_DAY_ACCENT if daytime else CLOCK_NIGHT_ACCENT

		# Outer Persona dial bezel strictly inside DIAL_SIZE bounds.
		draw_circle(center + Vector2(1.5, 2.0), sky_r + 3.5, Color("#060d17cc"), true, -1.0, true)
		draw_circle(center, sky_r + 3.0, accent, true, -1.0, true)
		draw_circle(center, sky_r + 1.4, Color("#e7edf2"), true, -1.0, true)

		var sky := _sky_palette()
		var sky_top: Color = sky[0]
		var sky_mid: Color = sky[1]
		var sky_horizon: Color = sky[2]

		# Base upper sky fill + mathematically clipped gradient bands.
		draw_circle(center, sky_r, sky_top, true, -1.0, true)
		_draw_circle_band(center, sky_r, center.y - sky_r * 0.22, center.y + sky_r * 0.16, sky_mid)
		_draw_circle_band(center, sky_r, center.y + sky_r * 0.12, center.y + sky_r * 0.44, sky_horizon)

		# Subtle dotted arc track showing the sun/moon path.
		var arc_origin := center + Vector2(0.0, sky_r * 0.22)
		var arc_r := sky_r * 0.58
		var track_color := Color(1.0, 0.98, 0.9, 0.24 if daytime else 0.18)
		for step: int in range(9):
			var t := float(step) / 8.0
			var a := lerpf(0.32, PI - 0.32, t)
			var pt := arc_origin + Vector2(-cos(a) * arc_r, -sin(a) * arc_r)
			if pt.distance_to(center) <= sky_r - 3.0:
				draw_circle(pt, 0.95, track_color, true, -1.0, true)

		# Twinkling pixel stars during twilight and night.
		var star_alpha := _star_alpha()
		if star_alpha > 0.02:
			for idx: int in range(STARS.size()):
				var star_dir: Vector2 = STARS[idx]
				var star_pos := center + star_dir * sky_r
				var star_r := 1.4 if idx % 2 == 0 else 1.0
				draw_circle(star_pos, star_r, Color(0.92, 0.96, 1.0, star_alpha), true, -1.0, false)

		# Moving Sun (06:00-17:59) or Crescent Moon (18:00-05:59).
		var body_pos := get_celestial_center()
		if daytime:
			draw_circle(body_pos, 7.4, Color(1.0, 0.84, 0.44, 0.28), true, -1.0, true)
			for ray: int in range(8):
				var ray_angle := float(ray) * TAU / 8.0 + phase_progress() * 0.65
				var ray_dir := Vector2(cos(ray_angle), sin(ray_angle))
				draw_line(body_pos + ray_dir * 4.8, body_pos + ray_dir * 7.2, Color("#ffe89e"), 1.35, true)
			draw_circle(body_pos, 4.5, Color("#ffd277"), true, -1.0, true)
			draw_circle(body_pos + Vector2(-1.1, -1.1), 2.1, Color("#fff7d6"), true, -1.0, true)
		else:
			draw_circle(body_pos, 7.2, Color(0.57, 0.74, 0.92, 0.25), true, -1.0, true)
			draw_circle(body_pos, 4.9, Color("#eef5ff"), true, -1.0, true)
			draw_circle(body_pos + Vector2(2.1, -1.2), 4.2, sky_top.lerp(sky_mid, 0.35), true, -1.0, true)

		# Clipped horizon silhouette across the lower chord of the sky disc.
		var horizon_y := center.y + sky_r * 0.36
		var ground_color := Color("#122234") if daytime else Color("#09111d")
		_draw_circle_band(center, sky_r, horizon_y, center.y + sky_r, ground_color)
		var half_chord := sqrt(maxf(0.0, sky_r * sky_r - pow(horizon_y - center.y, 2.0)))
		if half_chord > 2.0:
			var rim := Color(accent, 0.72)
			draw_line(Vector2(center.x - half_chord + 1.0, horizon_y), Vector2(center.x + half_chord - 1.0, horizon_y), rim, 1.3, true)

		# Crisp inner ring to keep the sky dial edge razor sharp.
		draw_arc(center, sky_r, 0.0, TAU, 48, Color("#0a1420cc"), 1.3, true)


	func _draw_circle_band(center: Vector2, radius: float, y_top: float, y_bottom: float, color: Color) -> void:
		var top_y := clampf(y_top, center.y - radius, center.y + radius)
		var bot_y := clampf(y_bottom, center.y - radius, center.y + radius)
		if bot_y <= top_y + 0.25:
			return
		var steps := 10
		var left_pts: PackedVector2Array = PackedVector2Array()
		var right_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(steps + 1):
			var y := lerpf(top_y, bot_y, float(i) / float(steps))
			var dy := y - center.y
			var dx := sqrt(maxf(0.0, radius * radius - dy * dy))
			left_pts.append(Vector2(center.x - dx, y))
			right_pts.append(Vector2(center.x + dx, y))
		var poly := PackedVector2Array()
		for pt: Vector2 in left_pts:
			poly.append(pt)
		for i: int in range(right_pts.size() - 1, -1, -1):
			poly.append(right_pts[i])
		if poly.size() >= 3:
			draw_colored_polygon(poly, color)


	func _sky_palette() -> Array[Color]:
		var hour := float(minute_of_day) / 60.0
		if hour >= 5.5 and hour < 7.5:
			var t := (hour - 5.5) / 2.0
			return [
				Color("#1c2b4d").lerp(Color("#4c88c4"), t),
				Color("#5f4c6e").lerp(Color("#88b8de"), t),
				Color("#d68760").lerp(Color("#f4cb8c"), t),
			]
		if hour >= 7.5 and hour < 11.5:
			var t := (hour - 7.5) / 4.0
			return [
				Color("#4c88c4").lerp(Color("#2f7fc9"), t),
				Color("#88b8de").lerp(Color("#69b1e6"), t),
				Color("#f4cb8c").lerp(Color("#cbe7fa"), t),
			]
		if hour >= 11.5 and hour < 15.0:
			return [Color("#2f7fc9"), Color("#69b1e6"), Color("#cbe7fa")]
		if hour >= 15.0 and hour < 18.0:
			var t := (hour - 15.0) / 3.0
			return [
				Color("#2f7fc9").lerp(Color("#364572"), t),
				Color("#69b1e6").lerp(Color("#b06558"), t),
				Color("#cbe7fa").lerp(Color("#f0a45a"), t),
			]
		if hour >= 18.0 and hour < 20.0:
			var t := (hour - 18.0) / 2.0
			return [
				Color("#364572").lerp(Color("#0d192e"), t),
				Color("#b06558").lerp(Color("#162844"), t),
				Color("#f0a45a").lerp(Color("#243b5e"), t),
			]
		return [Color("#0d192e"), Color("#162844"), Color("#243b5e")]


	func _star_alpha() -> float:
		var hour := float(minute_of_day) / 60.0
		if hour >= 20.0 or hour < 5.0:
			return 0.88
		if hour >= 18.0 and hour < 20.0:
			return lerpf(0.25, 0.88, (hour - 18.0) / 2.0)
		if hour >= 5.0 and hour < 6.0:
			return lerpf(0.88, 0.0, hour - 5.0)
		return 0.0


var _opener: Button
var _hud_stats: PanelContainer
var _hud_name: Label
var _hud_name_plate: PanelContainer
var _hud_clock_panel: PanelContainer
var _hud_clock_style: StyleBoxFlat
var _hud_dial: DayNightDial
var _hud_semester: Label
var _hud_day: Label
var _hud_week: Label
var _hud_period: Label
var _hud_period_badge: PanelContainer
var _hud_period_style: StyleBoxFlat
var _popup: Window
var _overview: HBoxContainer
var _status: VBoxContainer
var _journal: VBoxContainer
var _name: Label
var _id: Label
var _energy: ProgressBar
var _energy_text: Label
var _status_values: Array[Label] = []
var _status_bars: Array[ProgressBar] = []
var _kind: OptionButton
var _semester: OptionButton
var _week: OptionButton
var _entries: VBoxContainer
var _message: Label
var _hud_clock: Label
var _profile_clock: Label
var _profile_date: Label
var _settings: VBoxContainer
var _volume: HSlider
var _volume_value: Label
var _resolution: OptionButton
var _settings_message: Label
var _owns_pause: bool = false
var _was_paused: bool = false
var _clock_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	_build_hud()
	_build_popup()
	PlayerStats.changed.connect(_refresh_stats)
	GameClock.minute_changed.connect(_refresh_clock)
	get_viewport().size_changed.connect(_fit_popup, CONNECT_DEFERRED)
	_refresh_stats()
	_refresh_clock(GameClock.get_absolute_minutes())


func _process(_delta: float) -> void:
	var player := get_parent().get_node_or_null("Player")
	_opener.disabled = get_tree().paused or SceneTransition.is_active() or (player != null and player.is_studying())


func _exit_tree() -> void:
	if is_instance_valid(_settings) and _settings.visible:
		GameSettings.preview_volume(GameSettings.master_volume)
	if _owns_pause:
		GameClock.process_mode = _clock_process_mode
		get_tree().paused = _was_paused


func _label(parent: Node, value: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _bar(parent: Node, maximum: float = 100.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("18232e")
	background.set_corner_radius_all(4)
	background.set_border_width_all(1)
	background.border_color = Color("b79a68")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("64b5a0")
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _portrait(parent: Node, minimum: Vector2, face: bool = false) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = PORTRAIT
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = minimum
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face:
		var atlas := AtlasTexture.new()
		atlas.atlas = PORTRAIT
		atlas.region = Rect2(90, 35, 240, 240)
		picture.texture = atlas
	parent.add_child(picture)
	return picture


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MENU_THEME
	add_child(root)
	_build_clock_hud(root)

	var cluster := HBoxContainer.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_theme_constant_override("separation", 10)
	root.add_child(cluster)
	cluster.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cluster.offset_left = -14
	cluster.offset_right = -14
	cluster.offset_top = 12
	cluster.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_hud_stats = preload("res://scripts/movement/stats_hud.gd").new()
	_hud_stats.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cluster.add_child(_hud_stats)

	var portrait_column := VBoxContainer.new()
	portrait_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_column.add_theme_constant_override("separation", 4)
	cluster.add_child(portrait_column)

	_opener = _button(portrait_column, "", open_profile)
	_opener.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_opener.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_opener.accessibility_name = "Buka profil pemain"
	_style_portrait_button(_opener)
	var portrait := _portrait(_opener, Vector2.ZERO, true)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 4
	portrait.offset_top = 4
	portrait.offset_right = -4
	portrait.offset_bottom = -4

	_hud_name_plate = PanelContainer.new()
	_hud_name_plate.clip_contents = true
	_hud_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_name_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = HUD_SURFACE
	name_style.border_color = Color("#7a95a699")
	name_style.set_border_width_all(1)
	name_style.set_corner_radius_all(6)
	name_style.content_margin_left = 8
	name_style.content_margin_right = 8
	name_style.content_margin_top = 2
	name_style.content_margin_bottom = 2
	_hud_name_plate.add_theme_stylebox_override("panel", name_style)
	portrait_column.add_child(_hud_name_plate)

	_hud_name = _label(_hud_name_plate, "", 13)
	_hud_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_name.clip_text = true
	_hud_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud_name.add_theme_font_override("font", HUD_FONT)
	_hud_name.add_theme_color_override("font_color", HUD_INK)

	_hud_stats.minimum_size_changed.connect(_match_portrait_height)
	_match_portrait_height()


func _style_portrait_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = HUD_SURFACE
	normal.border_color = Color("#d8b674d8")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#16283af2")
	hover.border_color = CLOCK_DAY_ACCENT

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#0b141ef5")
	pressed.border_color = Color("#f6e1a8")

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#0d1824a8")
	disabled.border_color = Color("#6b7f8e88")

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = CLOCK_DAY_ACCENT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)


func _match_portrait_height() -> void:
	var side := maxf(68.0, _hud_stats.get_combined_minimum_size().y)
	_opener.custom_minimum_size = Vector2(side, side)
	if is_instance_valid(_hud_name):
		_hud_name.custom_minimum_size.x = maxf(side + 12.0, 84.0)


func _build_clock_hud(root: Control) -> void:
	_hud_clock_panel = PanelContainer.new()
	_hud_clock_panel.clip_contents = true
	_hud_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_clock_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hud_clock_panel.offset_left = 14
	_hud_clock_panel.offset_top = 12
	_hud_clock_panel.custom_minimum_size = Vector2(216, 0)

	_hud_clock_style = StyleBoxFlat.new()
	_hud_clock_style.bg_color = HUD_SURFACE
	_hud_clock_style.border_color = CLOCK_DAY_ACCENT
	_hud_clock_style.border_width_left = 4
	_hud_clock_style.border_width_top = 1
	_hud_clock_style.border_width_right = 1
	_hud_clock_style.border_width_bottom = 2
	_hud_clock_style.set_corner_radius_all(8)
	_hud_clock_style.content_margin_left = 8
	_hud_clock_style.content_margin_right = 12
	_hud_clock_style.content_margin_top = 5
	_hud_clock_style.content_margin_bottom = 5
	_hud_clock_panel.add_theme_stylebox_override("panel", _hud_clock_style)
	root.add_child(_hud_clock_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_hud_clock_panel.add_child(row)

	_hud_dial = DayNightDial.new()
	_hud_dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hud_dial)

	var readout := VBoxContainer.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.alignment = BoxContainer.ALIGNMENT_CENTER
	readout.add_theme_constant_override("separation", 1)
	row.add_child(readout)

	var cal_row := HBoxContainer.new()
	cal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cal_row.add_theme_constant_override("separation", 5)
	readout.add_child(cal_row)

	_hud_semester = _hud_label(cal_row, "SEM 1", 13, CLOCK_DAY_ACCENT)
	_hud_label(cal_row, "·", 13, Color("#738b9c"))
	_hud_day = _hud_label(cal_row, "HARI 1", 13, Color("#e7edf2"))

	var time_row := HBoxContainer.new()
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_theme_constant_override("separation", 7)
	readout.add_child(time_row)

	_hud_clock = _hud_label(time_row, "06:00", 22, HUD_INK)
	_hud_clock.add_theme_color_override("font_outline_color", Color("#060d17cc"))
	_hud_clock.add_theme_constant_override("outline_size", 3)

	_hud_period_badge = PanelContainer.new()
	_hud_period_badge.clip_contents = true
	_hud_period_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_period_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hud_period_style = StyleBoxFlat.new()
	_hud_period_style.set_border_width_all(1)
	_hud_period_style.set_corner_radius_all(4)
	_hud_period_style.content_margin_left = 6
	_hud_period_style.content_margin_right = 6
	_hud_period_style.content_margin_top = 1
	_hud_period_style.content_margin_bottom = 1
	_hud_period_badge.add_theme_stylebox_override("panel", _hud_period_style)
	time_row.add_child(_hud_period_badge)
	_hud_period = _hud_label(_hud_period_badge, "Pagi", 12, Color("#fff3cf"))
	_hud_period.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hud_week = _hud_label(readout, "Minggu 1", 12, HUD_MUTED)


func _hud_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := _label(parent, value, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HUD_FONT)
	label.add_theme_color_override("font_color", color)
	return label


func _period_info(minute_of_day: int) -> Dictionary:
	if minute_of_day >= 360 and minute_of_day < 660:
		return {"label": "Pagi", "bg": Color("#4a3a18f0"), "border": CLOCK_DAY_ACCENT, "text": Color("#fff3cf")}
	if minute_of_day >= 660 and minute_of_day < 900:
		return {"label": "Siang", "bg": Color("#193c58f0"), "border": Color("#86c5f4"), "text": Color("#e6f6ff")}
	if minute_of_day >= 900 and minute_of_day < 1080:
		return {"label": "Sore", "bg": Color("#4c2a1bf0"), "border": Color("#f09d62"), "text": Color("#ffead9")}
	return {"label": "Malam", "bg": Color("#182444f0"), "border": CLOCK_NIGHT_ACCENT, "text": Color("#dcebff")}


func _build_popup() -> void:
	_popup = Window.new()
	_popup.title = "Profil Player"
	_popup.theme = MENU_THEME
	_popup.visible = false
	_popup.transient = true
	_popup.exclusive = true
	_popup.min_size = Vector2i(560, 340)
	add_child(_popup)
	_popup.close_requested.connect(_popup.hide)
	_popup.visibility_changed.connect(_popup_visibility_changed)
	_popup.window_input.connect(_popup_input)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	scroll.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	_label(heading, "PLAYER PROFILE", 26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Tutup", _popup.hide)
	_overview = HBoxContainer.new()
	_overview.add_theme_constant_override("separation", 24)
	layout.add_child(_overview)
	var portrait_column := VBoxContainer.new()
	portrait_column.custom_minimum_size.x = 220
	portrait_column.add_theme_constant_override("separation", 8)
	_overview.add_child(portrait_column)
	_portrait(portrait_column, Vector2(220, 260)).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_clock = _label(portrait_column, "", 26)
	_profile_date = _label(portrait_column, "", 16)
	_profile_date.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 16)
	_overview.add_child(details)
	_name = _label(details, "", 30)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_id = _label(details, "", 18)
	_energy_text = _label(details, "Energi")
	_energy = _bar(details)
	_button(details, "Status", _show_status)
	_button(details, "Jurnal", _show_journal)
	_button(details, "Settings", _show_settings)
	_status = VBoxContainer.new()
	_status.hide()
	_status.add_theme_constant_override("separation", 18)
	layout.add_child(_status)
	_label(_status, "Status Player", 26)
	for title: String in ["Energi", "Kewarasan", "IPK"]:
		_status_values.append(_label(_status, title))
		_status_bars.append(_bar(_status, 4.0 if title == "IPK" else 100.0))
	_button(_status, "Kembali ke Profil", _show_overview)
	_journal = VBoxContainer.new()
	_journal.hide()
	_journal.add_theme_constant_override("separation", 12)
	layout.add_child(_journal)
	_label(_journal, "Jurnal", 26)
	var filters := HBoxContainer.new()
	_journal.add_child(filters)
	_kind = OptionButton.new()
	_kind.add_item("Catatan")
	_kind.add_item("Proyek")
	filters.add_child(_kind)
	_semester = OptionButton.new()
	filters.add_child(_semester)
	_week = OptionButton.new()
	filters.add_child(_week)
	for option: OptionButton in [_kind, _semester, _week]:
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.item_selected.connect(func(_index: int): _refresh_journal())
	_message = _label(_journal, "", 16)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entries = VBoxContainer.new()
	_entries.add_theme_constant_override("separation", 18)
	_journal.add_child(_entries)
	_button(_journal, "Kembali ke Profil", _show_overview)
	_build_settings(layout)


func _build_settings(parent: Node) -> void:
	_settings = VBoxContainer.new()
	_settings.hide()
	_settings.add_theme_constant_override("separation", 16)
	parent.add_child(_settings)
	_label(_settings, "Settings", 26)
	var volume_row := HBoxContainer.new()
	_settings.add_child(volume_row)
	_label(volume_row, "Volume").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_value = _label(volume_row, "")
	_volume = HSlider.new()
	_volume.max_value = 100
	_volume.step = 1
	_volume.custom_minimum_size.y = 28
	_volume.accessibility_name = "Volume utama"
	_settings.add_child(_volume)
	_volume.value_changed.connect(_preview_volume)
	_label(_settings, "Resolusi")
	_resolution = OptionButton.new()
	_resolution.accessibility_name = "Resolusi layar"
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		_resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_settings.add_child(_resolution)
	_resolution.item_selected.connect(_change_resolution)
	_settings_message = _label(_settings, "", 16)
	_settings_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_settings, "Terapkan", _apply_settings)
	_button(_settings, "Kembali ke Profil", _show_overview)


func _show_settings() -> void:
	_set_clock_running(false)
	_overview.hide()
	_status.hide()
	_journal.hide()
	_settings.show()
	_settings_message.text = ""
	_volume.set_value_no_signal(roundi(GameSettings.master_volume * 100.0))
	_volume_value.text = "%d%%" % roundi(_volume.value)
	_resolution.select(GameSettings.resolution_index)
	_volume.grab_focus()


func _preview_volume(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value)
	GameSettings.preview_volume(value / 100.0)


func _change_resolution(index: int) -> void:
	var error := GameSettings.save_settings(GameSettings.master_volume, index)
	_settings_message.text = "Resolusi tersimpan." if error == OK else "Resolusi belum dapat diubah. Coba lagi."
	if error != OK:
		_resolution.select(GameSettings.resolution_index)
	else:
		_fit_popup.call_deferred()
	GameSettings.preview_volume(_volume.value / 100.0)


func _apply_settings() -> void:
	var error := GameSettings.save_settings(_volume.value / 100.0, _resolution.selected)
	_settings_message.text = "Pengaturan tersimpan." if error == OK else "Pengaturan belum tersimpan. Coba lagi."
	if error == OK:
		_fit_popup.call_deferred()


func _fit_popup() -> void:
	if _popup.visible:
		_popup.popup_centered_clamped(Vector2i(780, 570))


func _refresh_clock(absolute_minutes: int) -> void:
	var time := GameClock.get_formatted_time()
	var minute_of_day := posmod(absolute_minutes, GameClock.MINUTES_PER_DAY)
	var semester_num := CareerProgress.semester()
	var day_in_sem := CareerProgress.day_in_semester()
	var period := _period_info(minute_of_day)

	_hud_dial.set_minute_of_day(minute_of_day)
	var accent := CLOCK_DAY_ACCENT if _hud_dial.is_daytime() else CLOCK_NIGHT_ACCENT
	_hud_clock_style.border_color = accent
	_hud_semester.text = "SEM %d" % semester_num
	_hud_semester.add_theme_color_override("font_color", accent)
	_hud_day.text = "HARI %d/12" % day_in_sem
	_hud_clock.text = time
	if day_in_sem == CareerProgress.Curriculum.MIDTERM_DAY:
		_hud_week.text = "HARI UJIAN · UTS"
	elif day_in_sem == CareerProgress.Curriculum.FINAL_DAY:
		_hud_week.text = "HARI UJIAN · UAS"
	elif day_in_sem < CareerProgress.Curriculum.MIDTERM_DAY:
		_hud_week.text = "Paruh 1 · UTS H6"
	else:
		_hud_week.text = "Paruh 2 · UAS H12"

	_hud_period_style.bg_color = period.bg
	_hud_period_style.border_color = period.border
	_hud_period_badge.queue_redraw()
	_hud_period.text = period.label
	_hud_period.add_theme_color_override("font_color", period.text)

	var summary := "Semester %d · Hari %d/12 (%s %s)" % [semester_num, day_in_sem, time, period.label]
	_hud_clock.tooltip_text = summary
	_hud_clock_panel.accessibility_name = summary
	_profile_clock.text = time
	_profile_date.text = "Hari %d · Minggu %d" % [GameClock.get_day(), GameClock.get_week()]


func open_profile() -> void:
	if get_tree().paused or SceneTransition.is_active():
		return
	var player := get_parent().get_node_or_null("Player")
	if player != null and player.is_studying():
		return
	_was_paused = get_tree().paused
	_clock_process_mode = GameClock.process_mode
	_owns_pause = true
	get_tree().paused = true
	_show_overview()
	_popup.popup_centered_clamped(Vector2i(780, 570))
	_overview.get_child(1).get_child(4).grab_focus()


func _popup_visibility_changed() -> void:
	if not _popup.visible and _owns_pause:
		GameSettings.preview_volume(GameSettings.master_volume)
		GameClock.process_mode = _clock_process_mode
		get_tree().paused = _was_paused
		_owns_pause = false
		_opener.disabled = false
		_opener.grab_focus()


func _popup_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overview.visible:
			_popup.hide()
		else:
			_show_overview()
		_popup.set_input_as_handled()


func _show_overview() -> void:
	_set_clock_running(true)
	GameSettings.preview_volume(GameSettings.master_volume)
	_settings.hide()
	_overview.show()
	_status.hide()
	_journal.hide()
	_refresh_stats()


func _show_status() -> void:
	_set_clock_running(true)
	_settings.hide()
	_overview.hide()
	_status.show()
	_journal.hide()
	_status.get_child(_status.get_child_count() - 1).grab_focus()


func _show_journal() -> void:
	_set_clock_running(true)
	_settings.hide()
	_overview.hide()
	_status.hide()
	_journal.show()
	var error := PlayerJournal.sync_legacy()
	_message.text = "Jurnal belum dapat disimpan. Coba lagi." if error != OK else "Catatan tersedia setelah kelas selesai."
	_semester.clear()
	_semester.add_item("Semua semester", 0)
	var semesters: Array[int] = []
	for entry: Dictionary in PlayerJournal.get_entries():
		if entry.semester > 0 and entry.semester not in semesters:
			semesters.append(entry.semester)
	semesters.sort()
	for semester: int in semesters:
		_semester.add_item("Semester %d" % semester, semester)
	_semester.add_item("Arsip Lama", -1)
	_semester.set_item_metadata(_semester.item_count - 1, true)
	_week.clear()
	_week.add_item("Semua minggu", 0)
	for week: int in range(1, 17):
		_week.add_item("Minggu %d" % week, week)
	_refresh_journal()
	_kind.grab_focus()


func _set_clock_running(running: bool) -> void:
	if _owns_pause:
		GameClock.process_mode = Node.PROCESS_MODE_ALWAYS if running else Node.PROCESS_MODE_PAUSABLE


func _refresh_journal() -> void:
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var archive: bool = _semester.get_selected_metadata() == true
	var semester := _semester.get_selected_id()
	var week := _week.get_selected_id()
	_week.disabled = archive
	var count := 0
	var data := PlayerJournal.get_entries()
	data.reverse()
	for entry: Dictionary in data:
		if entry.kind != ("notes" if _kind.selected == 0 else "project"):
			continue
		if archive and entry.semester != 0:
			continue
		if not archive and semester > 0 and entry.semester != semester:
			continue
		if not archive and week > 0 and entry.week != week:
			continue
		count += 1
		var card := PanelContainer.new()
		_entries.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		card.add_child(content)
		_label(content, "Arsip Lama" if entry.semester == 0 else "Semester %d · Minggu %d" % [entry.semester, entry.week], 16)
		_label(content, entry.title, 22).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(content, entry.body, 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if count == 0:
		_label(_entries, "Belum ada catatan pada kategori ini." if _kind.selected == 0 else "Belum ada proyek selesai pada kategori ini.", 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh_stats() -> void:
	_hud_name.text = PlayerStats.player_name
	_hud_name.get_parent().tooltip_text = PlayerStats.player_name
	_opener.tooltip_text = "Profil " + PlayerStats.player_name
	_name.text = PlayerStats.player_name
	_id.text = "NIM / ID  " + PlayerStats.student_id
	_energy.value = PlayerStats.get_energy()
	_energy_text.text = "Energi   %d / 100" % roundi(PlayerStats.get_energy())
	var values := [PlayerStats.get_energy(), PlayerStats.get_sanity(), PlayerStats.get_gpa()]
	var titles := ["Energi", "Kewarasan", "IPK"]
	for index: int in values.size():
		_status_bars[index].value = values[index]
		_status_values[index].text = "%s   %.2f / %.2f" % [titles[index], values[index], _status_bars[index].max_value]
