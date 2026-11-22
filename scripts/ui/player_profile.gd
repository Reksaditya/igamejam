extends CanvasLayer

const PORTRAIT := preload("res://assets/characters/mc/idle/1.png")
const MENU_THEME := preload("res://scenes/ui/menu_theme.tres")

var _opener: Button
var _hud_name: Label
var _hud_energy: ProgressBar
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
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); vec2 face_uv = (UV - vec2(0.225, 0.0875)) / vec2(0.6); float d = distance(face_uv, vec2(0.5)); COLOR = vec4(c.rgb, c.a * (1.0 - smoothstep(0.47, 0.5, d))); }"
		var material := ShaderMaterial.new()
		material.shader = shader
		picture.material = material
	parent.add_child(picture)
	return picture


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MENU_THEME
	add_child(root)
	var stats := preload("res://scripts/movement/stats_hud.gd").new()
	stats.position = Vector2(16, 16)
	stats.custom_minimum_size.x = 274
	root.add_child(stats)
	var clock_panel := PanelContainer.new()
	clock_panel.position = Vector2(306, 16)
	clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clock_panel)
	_hud_clock = _label(clock_panel, "", 24)
	_hud_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opener = _button(root, "", open_profile)
	_opener.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_opener.offset_left = -320
	_opener.offset_right = -20
	_opener.offset_top = 16
	_opener.offset_bottom = 98
	_opener.tooltip_text = "Buka profil player"
	_opener.accessibility_name = "Profil player"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opener.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	_hud_name = _label(info, "")
	_hud_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_energy = _bar(info)
	_hud_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait(row, Vector2(64, 64), true)


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
	_hud_clock.text = time
	_hud_clock.tooltip_text = "Hari %d · Minggu %d" % [GameClock.get_day(), GameClock.get_week()]
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
	_hud_energy.value = PlayerStats.get_energy()
	_hud_energy.tooltip_text = "Energi %d / 100" % roundi(PlayerStats.get_energy())
	_name.text = PlayerStats.player_name
	_id.text = "NIM / ID  " + PlayerStats.student_id
	_energy.value = PlayerStats.get_energy()
	_energy_text.text = "Energi   %d / 100" % roundi(PlayerStats.get_energy())
	var values := [PlayerStats.get_energy(), PlayerStats.get_sanity(), PlayerStats.get_gpa()]
	var titles := ["Energi", "Kewarasan", "IPK"]
	for index: int in values.size():
		_status_bars[index].value = values[index]
		_status_values[index].text = "%s   %.2f / %.2f" % [titles[index], values[index], _status_bars[index].max_value]
