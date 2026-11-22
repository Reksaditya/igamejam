extends CanvasLayer

const PORTRAIT := preload("res://assets/characters/mc/idle/1.png")
const MENU_THEME := preload("res://scenes/ui/menu_theme.tres")
const HUD_FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

const HUD_SURFACE := Color("#161618de")
const HUD_BORDER := Color("#4a4a52")
const HUD_INK := Color("#f0f0f2")
const HUD_MUTED := Color("#b8b8be")
const HUD_OUTLINE := Color(0.06, 0.06, 0.07, 0.96)

## Room-by-room routing table toward today's classroom.
const CLASS_ROUTE := {
	"dorm_room210.tscn": {"target": "Door", "label": "Keluar kamar", "edge": "left"},
	"dorm_floor2.tscn": {"target": "Door", "label": "Turun Lt. 1", "edge": "right"},
	"dorm_floor1.tscn": {"target": "Door", "label": "Keluar asrama", "edge": "left"},
	"dorm_exterior.tscn": {"target": "RightExit", "label": "Ke Kampus", "edge": "right"},
	"campus_lab.tscn": {"target": "LeftExit", "label": "Ke Kampus", "edge": "left"},
	"campus_lab_room.tscn": {"target": "Door", "label": "Keluar lab", "edge": "left"},
	"lecturer_room.tscn": {"target": "Door", "label": "Keluar ruang dosen", "edge": "left"},
	"top_down_movement.tscn": {"target": "Door", "label": "Gedung Kelas", "edge": "right"},
	"classroom_corridor_floor1.tscn": {"target": "Door", "label": "Pintu Kelas", "edge": "right"},
	"classroom_corridor_floor2.tscn": {"target": "Door", "label": "Pintu Kelas", "edge": "right"},
	"classroom_corridor_floor3.tscn": {"target": "Door", "label": "Pintu Kelas", "edge": "right"},
}

var _opener: Button
var _hud_stats: PanelContainer
var _hud_name: Label
var _hud_name_plate: PanelContainer
var _hud_clock_panel: PanelContainer
var _hud_semester: Label
var _hud_day: Label
var _hud_clock: Label
var _hud_quest_panel: PanelContainer
var _hud_quest_badge: Label
var _hud_quest_title: Label
var _hud_toast: PanelContainer
var _hud_toast_label: Label
var _toast_tween: Tween
var _wayfinding_label: Label
var _wayfinding_time: float = 0.0
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
	CareerProgress.changed.connect(_refresh_quest_hud)
	CareerProgress.class_missed.connect(_on_class_missed)
	get_viewport().size_changed.connect(_fit_popup, CONNECT_DEFERRED)
	_refresh_stats()
	_refresh_clock(GameClock.get_absolute_minutes())
	_refresh_quest_hud()


func _process(delta: float) -> void:
	var player := get_parent().get_node_or_null("Player")
	_opener.disabled = get_tree().paused or SceneTransition.is_active() or (player != null and player.is_studying())
	_update_wayfinding_pointer(delta)


func _exit_tree() -> void:
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
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
	background.bg_color = Color("#18181b")
	background.set_corner_radius_all(4)
	background.set_border_width_all(1)
	background.border_color = HUD_BORDER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#80c8ac")
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
	_build_wayfinding_pointer(root)

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
	name_style.border_color = HUD_BORDER
	name_style.set_border_width_all(1)
	name_style.set_corner_radius_all(4)
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
	normal.border_color = HUD_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 1)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#242428f2")
	hover.border_color = Color("#7a7a84")

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#101012f5")
	pressed.border_color = Color("#a8a8b2")

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#141416a8")
	disabled.border_color = Color("#3a3a4088")

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#d8d8de")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)

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
	var left_stack := VBoxContainer.new()
	left_stack.name = &"LeftHudStack"
	left_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_stack.add_theme_constant_override("separation", 5)
	left_stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left_stack.offset_left = 14
	left_stack.offset_top = 12
	root.add_child(left_stack)

	# Ultra-simple, neutral grey-black Day & Time strip (no dial, no extra chrome).
	_hud_clock_panel = PanelContainer.new()
	_hud_clock_panel.name = &"SimpleClockStrip"
	_hud_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_clock_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var clock_style := StyleBoxFlat.new()
	clock_style.bg_color = HUD_SURFACE
	clock_style.border_color = HUD_BORDER
	clock_style.set_border_width_all(1)
	clock_style.set_corner_radius_all(4)
	clock_style.content_margin_left = 10
	clock_style.content_margin_right = 10
	clock_style.content_margin_top = 5
	clock_style.content_margin_bottom = 5
	_hud_clock_panel.add_theme_stylebox_override("panel", clock_style)
	left_stack.add_child(_hud_clock_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_hud_clock_panel.add_child(row)

	_hud_semester = _hud_label(row, "SEM 1", 15, HUD_MUTED)
	_hud_label(row, "·", 15, Color("#6a6a72"))
	_hud_day = _hud_label(row, "HARI 1/12", 15, HUD_INK)
	_hud_label(row, " ", 15, HUD_MUTED)
	_hud_clock = _hud_label(row, "06:00", 17, HUD_INK)

	_build_quest_hud(left_stack)
	_build_missed_toast(root)


func _build_quest_hud(parent: Control) -> void:
	# Background-free class schedule: uses StyleBoxEmpty (zero rectangle/panel backing).
	_hud_quest_panel = PanelContainer.new()
	_hud_quest_panel.name = &"ScheduleQuestPanel"
	_hud_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_quest_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(_hud_quest_panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	_hud_quest_panel.add_child(box)

	_hud_quest_badge = _outlined_hud_label(box, "JADWAL KELAS", 12, HUD_MUTED)
	_hud_quest_title = _outlined_hud_label(box, "→ Kelas 08:00", 14, HUD_INK)


func _build_wayfinding_pointer(root: Control) -> void:
	_wayfinding_label = Label.new()
	_wayfinding_label.name = &"ClassWayfindingPointer"
	_wayfinding_label.visible = false
	_wayfinding_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wayfinding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wayfinding_label.add_theme_font_override("font", HUD_FONT)
	_wayfinding_label.add_theme_font_size_override("font_size", 15)
	_wayfinding_label.add_theme_color_override("font_color", HUD_INK)
	_wayfinding_label.add_theme_color_override("font_outline_color", HUD_OUTLINE)
	_wayfinding_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_wayfinding_label)


func _build_missed_toast(root: Control) -> void:
	_hud_toast = PanelContainer.new()
	_hud_toast.name = &"MissedClassToast"
	_hud_toast.visible = false
	_hud_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hud_toast.offset_top = 14
	_hud_toast.offset_left = -220
	_hud_toast.offset_right = 220

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color("#18181bf0")
	toast_style.border_color = Color("#5a5a64")
	toast_style.set_border_width_all(1)
	toast_style.set_corner_radius_all(4)
	toast_style.content_margin_left = 14
	toast_style.content_margin_right = 14
	toast_style.content_margin_top = 7
	toast_style.content_margin_bottom = 7
	_hud_toast.add_theme_stylebox_override("panel", toast_style)
	root.add_child(_hud_toast)

	_hud_toast_label = _hud_label(_hud_toast, "", 13, HUD_INK)
	_hud_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_toast_label.custom_minimum_size.x = 380.0


func _hud_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := _label(parent, value, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HUD_FONT)
	label.add_theme_color_override("font_color", color)
	return label


func _outlined_hud_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := _hud_label(parent, value, font_size, color)
	label.add_theme_color_override("font_outline_color", HUD_OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	return label


func _current_scene_filename() -> String:
	var parent := get_parent()
	if parent != null and not parent.scene_file_path.is_empty():
		return parent.scene_file_path.get_file()
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene.scene_file_path.get_file()
	return ""


func _is_in_classroom_scene() -> bool:
	return _current_scene_filename().begins_with("campus_classroom")


func _should_show_class_wayfinding(state_id: String) -> bool:
	if _is_in_classroom_scene():
		return false
	return state_id in ["class_upcoming", "class_open", "exam_ready"]


func get_wayfinding_route() -> Dictionary:
	return CLASS_ROUTE.get(_current_scene_filename(), {})


func _update_wayfinding_pointer(delta: float) -> void:
	if not is_inside_tree() or get_viewport() == null or not is_instance_valid(_wayfinding_label):
		return
	var status := CareerProgress.get_today_schedule_status()
	var state_id := str(status.get("state", "class_upcoming"))
	if not _should_show_class_wayfinding(state_id):
		_wayfinding_label.hide()
		return
	var route := get_wayfinding_route()
	if route.is_empty():
		_wayfinding_label.hide()
		return
	var parent := get_parent()
	if parent == null:
		_wayfinding_label.hide()
		return
	var target := parent.get_node_or_null(str(route.target)) as Node2D
	if target == null:
		_wayfinding_label.hide()
		return

	_wayfinding_time += delta
	var bob := sin(_wayfinding_time * 4.5) * 4.0
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	var screen_pos := get_viewport().get_canvas_transform() * target.global_position
	var label_text := str(route.label)
	var is_open := state_id == "class_open" or state_id == "exam_ready"
	_wayfinding_label.add_theme_color_override("font_color", Color("#f5d78b") if is_open else HUD_INK)

	var margin_x := 86.0
	if screen_pos.x < 36.0:
		_wayfinding_label.text = "← %s" % label_text
		_wayfinding_label.size = _wayfinding_label.get_combined_minimum_size()
		_wayfinding_label.position = Vector2(18.0 + bob, clampf(view_size.y * 0.45, 96.0, view_size.y - 80.0))
	elif screen_pos.x > view_size.x - 36.0:
		_wayfinding_label.text = "%s →" % label_text
		_wayfinding_label.size = _wayfinding_label.get_combined_minimum_size()
		_wayfinding_label.position = Vector2(view_size.x - _wayfinding_label.size.x - 18.0 + bob, clampf(view_size.y * 0.45, 96.0, view_size.y - 80.0))
	else:
		_wayfinding_label.text = "%s\n▼" % label_text
		_wayfinding_label.size = _wayfinding_label.get_combined_minimum_size()
		var target_x := clampf(screen_pos.x - _wayfinding_label.size.x * 0.5, 16.0, maxf(16.0, view_size.x - _wayfinding_label.size.x - margin_x))
		var target_y := clampf(screen_pos.y - 160.0 + bob, 68.0, view_size.y - _wayfinding_label.size.y - 24.0)
		_wayfinding_label.position = Vector2(target_x, target_y)
	_wayfinding_label.show()


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


func _refresh_clock(_absolute_minutes: int) -> void:
	var time := GameClock.get_formatted_time()
	var semester_num := CareerProgress.semester()
	var day_in_sem := CareerProgress.day_in_semester()

	_hud_semester.text = "SEM %d" % semester_num
	_hud_day.text = "HARI %d/12" % day_in_sem
	_hud_clock.text = time

	var summary := "Semester %d · Hari %d/12 · %s" % [semester_num, day_in_sem, time]
	_hud_clock.tooltip_text = summary
	_hud_clock_panel.accessibility_name = summary
	_profile_clock.text = time
	_profile_date.text = "Hari %d · Minggu %d" % [GameClock.get_day(), GameClock.get_week()]
	_refresh_quest_hud()


func _refresh_quest_hud() -> void:
	if not is_instance_valid(_hud_quest_panel):
		return
	var status := CareerProgress.get_today_schedule_status()
	var state_id := str(status.get("state", "class_upcoming"))
	_hud_quest_badge.text = str(status.get("badge", "JADWAL KELAS"))

	var route := get_wayfinding_route()
	var route_hint := str(route.get("label", ""))
	var arrow := "←" if str(route.get("edge", "right")) == "left" else "→"
	match state_id:
		"class_open":
			_hud_quest_badge.add_theme_color_override("font_color", Color("#f2c46d"))
			_hud_quest_title.add_theme_color_override("font_color", HUD_INK)
			_hud_quest_title.text = ("%s %s · %s" % [arrow, str(status.get("title", "")), route_hint]) if (not route_hint.is_empty() and not _is_in_classroom_scene()) else str(status.get("title", ""))
		"class_missed":
			_hud_quest_badge.add_theme_color_override("font_color", Color("#ff9b85"))
			_hud_quest_title.add_theme_color_override("font_color", Color("#ffd4ca"))
			_hud_quest_title.text = "Kelas terlewat · Kejar di Perpustakaan"
		"class_done", "exam_done":
			_hud_quest_badge.add_theme_color_override("font_color", Color("#80c8ac"))
			_hud_quest_title.add_theme_color_override("font_color", HUD_INK)
			_hud_quest_title.text = str(status.get("title", "Kelas selesai"))
		"exam_ready":
			_hud_quest_badge.add_theme_color_override("font_color", Color("#f2c46d"))
			_hud_quest_title.add_theme_color_override("font_color", HUD_INK)
			_hud_quest_title.text = ("%s %s · %s" % [arrow, str(status.get("title", "")), route_hint]) if (not route_hint.is_empty() and not _is_in_classroom_scene()) else str(status.get("title", ""))
		_:
			_hud_quest_badge.add_theme_color_override("font_color", HUD_MUTED)
			_hud_quest_title.add_theme_color_override("font_color", HUD_INK)
			_hud_quest_title.text = ("%s Kelas 08:00 · %s" % [arrow, route_hint]) if (not route_hint.is_empty() and not _is_in_classroom_scene()) else "Kelas 08:00 · Batas 09:00"

	_update_wayfinding_pointer(0.0)


func show_notice(message: String, duration: float = 3.5) -> void:
	if not is_inside_tree() or not is_instance_valid(_hud_toast):
		return
	_hud_toast_label.text = message
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_hud_toast.modulate.a = 0.0
	_hud_toast.show()
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.set_ignore_time_scale(true)
	_toast_tween.tween_property(_hud_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_hud_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_hud_toast.hide)


func _on_class_missed(_term: int, _day_in_sem: int) -> void:
	_refresh_quest_hud()
	show_notice("KELAS TERLEWAT — Terlambat > 1 jam (Batas 09:00). Kejar catatan di Perpustakaan.", 4.0)


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
