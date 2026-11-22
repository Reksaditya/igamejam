extends Control

const SaveCatalog = preload("res://scripts/ui/save_catalog.gd")
const FONT_SEMIBOLD: Font = preload("res://assets/fonts/pixelify_sans/PixelifySans-SemiBold.ttf")

const COLOR_WHITE := Color("#ffffff")
const COLOR_BLUE := Color("#38b6ff")
const COLOR_BLUE_LIT_BG := Color("#e6f5ff")
const COLOR_BLUE_LIT_BORDER := Color("#4dc0ff")
const COLOR_BLUE_LIT_TEXT := Color("#008fe8")
const COLOR_BLUE_PRESSED_BG := Color("#d0ecff")
const COLOR_BLUE_PRESSED_BORDER := Color("#229ce8")
const COLOR_BLUE_PRESSED_TEXT := Color("#0078c8")

const COLOR_RED := Color("#ff3b3b")
const COLOR_RED_LIT_BG := Color("#ffecec")
const COLOR_RED_LIT_BORDER := Color("#ff4d4d")
const COLOR_RED_LIT_TEXT := Color("#e02424")
const COLOR_RED_PRESSED_BG := Color("#ffd9d9")
const COLOR_RED_PRESSED_BORDER := Color("#d92626")
const COLOR_RED_PRESSED_TEXT := Color("#b81d1d")

const COLOR_DISABLED_BG := Color("#f4f6f8")
const COLOR_DISABLED_BORDER := Color("#b3c7d6")
const COLOR_DISABLED_TEXT := Color("#9ab0c2")
const COLOR_SETTINGS_TEXT := Color("#1e242b")

const ENTRANCE_DURATION := 0.50
const BUTTON_STAGGER := 0.06
const HOVER_DURATION := 0.12
const HOVER_NUDGE := Vector2(8.0, -2.0)
const FLOAT_AMPLITUDE := 2.5
const FLOAT_SPEED := 2.1
const FLOAT_PHASE_STEP := 0.9
const TITLE_FLOAT_AMPLITUDE := 2.0
const TITLE_FLOAT_SPEED := 1.55

var _saved_entries: Array[Dictionary] = []
var _was_paused: bool = false
var _busy: bool = false
var _float_time: float = 0.0
var _menu_buttons: Array[Button] = []
var _hover_offsets: Dictionary[Button, Vector2] = {}
var _hover_tweens: Dictionary[Button, Tween] = {}
var _button_styles: Dictionary[Button, Dictionary] = {}
var _hovered: Dictionary[Button, bool] = {}
var _focused: Dictionary[Button, bool] = {}
var _entrance_tween: Tween


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_menu_buttons = [%NewGame, %Load, %Settings, %Quit]
	_setup_visual_theme()
	_setup_button_motion()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()

	%NewGame.pressed.connect(_new_game)
	%Load.pressed.connect(_load_game)
	%Settings.pressed.connect(_show_settings)
	%Quit.pressed.connect(_quit)
	%SettingsBack.pressed.connect(_show_main)
	%Apply.pressed.connect(_apply_settings)
	%Volume.value_changed.connect(_preview_volume)
	%Resolution.item_selected.connect(_change_resolution)
	%NewGameConfirm.visibility_changed.connect(_restore_new_game_focus)
	%NewGameConfirm.confirmed.connect(_start_new_game)
	%NameDialog.confirmed.connect(_create_game)
	%NameDialog.visibility_changed.connect(_restore_new_game_focus)
	%PlayerName.text_changed.connect(func(value: String) -> void: %NameDialog.get_ok_button().disabled = value.strip_edges().is_empty())
	%PlayerName.text_submitted.connect(func(value: String) -> void:
		if not value.strip_edges().is_empty():
			%NameDialog.hide()
			_create_game()
	)
	get_window().focus_entered.connect(_refresh_saves)
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		%Resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_show_main()
	_play_entrance_animation()


func _exit_tree() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	for button: Button in _hover_tweens:
		var tween := _hover_tweens[button]
		if tween != null and tween.is_valid():
			tween.kill()
	GameSettings.preview_volume(GameSettings.master_volume)
	get_tree().paused = _was_paused


func _process(delta: float) -> void:
	_float_time += delta
	if %MainPanel.visible:
		%TitleBox.offset_transform_position = Vector2(0.0, sin(_float_time * TITLE_FLOAT_SPEED) * TITLE_FLOAT_AMPLITUDE)
		for index: int in _menu_buttons.size():
			var button := _menu_buttons[index]
			var float_y := sin(_float_time * FLOAT_SPEED + float(index) * FLOAT_PHASE_STEP) * FLOAT_AMPLITUDE
			var hover_offset: Vector2 = _hover_offsets.get(button, Vector2.ZERO)
			button.offset_transform_position = Vector2(hover_offset.x, float_y + hover_offset.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %SettingsPanel.visible:
		_show_main()
		get_viewport().set_input_as_handled()


func _setup_visual_theme() -> void:
	%TitleBox.add_theme_stylebox_override("panel", _make_box(COLOR_WHITE, COLOR_BLUE, 5, 22, 22, 18, 18))
	%SettingsCard.add_theme_stylebox_override("panel", _make_box(COLOR_WHITE, COLOR_BLUE, 4, 28, 28, 24, 24))
	%SettingsTitle.add_theme_color_override("font_color", COLOR_BLUE)
	for label: Label in [%VolumeTitle, %VolumeValue, %ResolutionTitle, %SettingsStatus]:
		label.add_theme_color_override("font_color", COLOR_SETTINGS_TEXT)
	%MenuStatus.add_theme_color_override("font_color", COLOR_RED_PRESSED_TEXT)

	_configure_action_button(%NewGame, false)
	_configure_action_button(%Load, false)
	_configure_action_button(%Settings, false)
	_configure_action_button(%Quit, true)
	_configure_settings_button(%Apply)
	_configure_settings_button(%SettingsBack)


func _configure_action_button(button: Button, is_exit: bool) -> void:
	var idle_border := COLOR_RED if is_exit else COLOR_BLUE
	var idle_text := COLOR_RED if is_exit else COLOR_BLUE
	var lit_bg := COLOR_RED_LIT_BG if is_exit else COLOR_BLUE_LIT_BG
	var lit_border := COLOR_RED_LIT_BORDER if is_exit else COLOR_BLUE_LIT_BORDER
	var lit_text := COLOR_RED_LIT_TEXT if is_exit else COLOR_BLUE_LIT_TEXT
	var pressed_bg := COLOR_RED_PRESSED_BG if is_exit else COLOR_BLUE_PRESSED_BG
	var pressed_border := COLOR_RED_PRESSED_BORDER if is_exit else COLOR_BLUE_PRESSED_BORDER
	var pressed_text := COLOR_RED_PRESSED_TEXT if is_exit else COLOR_BLUE_PRESSED_TEXT

	var style_idle := _make_box(COLOR_WHITE, idle_border, 3, 14, 18, 10, 10)
	var style_lit := _make_box(lit_bg, lit_border, 3, 14, 18, 10, 10)
	var style_pressed := _make_box(pressed_bg, pressed_border, 3, 14, 18, 10, 10)
	var style_disabled := _make_box(COLOR_DISABLED_BG, COLOR_DISABLED_BORDER, 3, 14, 18, 10, 10)

	_button_styles[button] = {
		"idle": style_idle,
		"lit": style_lit,
		"idle_text": idle_text,
		"lit_text": lit_text,
	}

	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_constant_override("icon_max_width", 28)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_stylebox_override("normal", style_idle)
	button.add_theme_stylebox_override("hover", style_lit)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", idle_text)
	button.add_theme_color_override("font_hover_color", lit_text)
	button.add_theme_color_override("font_focus_color", lit_text)
	button.add_theme_color_override("font_pressed_color", pressed_text)
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED_TEXT)


func _configure_settings_button(button: Button) -> void:
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _make_box(COLOR_WHITE, COLOR_BLUE, 3, 16, 16, 10, 10))
	button.add_theme_stylebox_override("hover", _make_box(COLOR_BLUE_LIT_BG, COLOR_BLUE_LIT_BORDER, 3, 16, 16, 10, 10))
	button.add_theme_stylebox_override("pressed", _make_box(COLOR_BLUE_PRESSED_BG, COLOR_BLUE_PRESSED_BORDER, 3, 16, 16, 10, 10))
	button.add_theme_stylebox_override("focus", _make_box(COLOR_BLUE_LIT_BG, COLOR_BLUE_LIT_BORDER, 3, 16, 16, 10, 10))
	button.add_theme_color_override("font_color", COLOR_BLUE)
	button.add_theme_color_override("font_hover_color", COLOR_BLUE_LIT_TEXT)
	button.add_theme_color_override("font_focus_color", COLOR_BLUE_LIT_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_BLUE_PRESSED_TEXT)


func _make_box(
	bg: Color,
	border: Color,
	border_width: int,
	margin_left: float,
	margin_right: float,
	margin_top: float,
	margin_bottom: float
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.content_margin_left = margin_left
	box.content_margin_right = margin_right
	box.content_margin_top = margin_top
	box.content_margin_bottom = margin_bottom
	return box


func _setup_button_motion() -> void:
	%MainPanel.offset_transform_enabled = true
	%MainPanel.offset_transform_visual_only = true
	%TitleBox.offset_transform_enabled = true
	%TitleBox.offset_transform_visual_only = true
	for button: Button in _menu_buttons:
		button.offset_transform_enabled = true
		button.offset_transform_visual_only = true
		_hover_offsets[button] = Vector2.ZERO
		_hovered[button] = false
		_focused[button] = false
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		button.focus_entered.connect(_on_button_focus.bind(button, true))
		button.focus_exited.connect(_on_button_focus.bind(button, false))


func _on_button_hover(button: Button, entered: bool) -> void:
	_hovered[button] = entered
	_update_button_visual(button)


func _on_button_focus(button: Button, entered: bool) -> void:
	_focused[button] = entered
	_update_button_visual(button)


func _update_responsive_layout() -> void:
	var compact := size.y < 560.0
	%Margin.add_theme_constant_override("margin_left", 40 if compact else 72)
	%Margin.add_theme_constant_override("margin_top", 24 if compact else 64)
	%Margin.add_theme_constant_override("margin_right", 40 if compact else 72)
	%Margin.add_theme_constant_override("margin_bottom", 24 if compact else 44)
	%MainPanel.add_theme_constant_override("separation", 20 if compact else 38)
	%ButtonColumn.add_theme_constant_override("separation", 10 if compact else 16)
	%Logo.custom_minimum_size = Vector2(334, 60) if compact else Vector2(456, 82)
	var min_size := Vector2(216, 46) if compact else Vector2(236, 56)
	for button: Button in _menu_buttons:
		button.custom_minimum_size = min_size


func _play_entrance_animation() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	%MainPanel.modulate.a = 0.0
	%MainPanel.offset_transform_position = Vector2(0.0, 14.0)
	for button: Button in _menu_buttons:
		button.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entrance_tween.set_ignore_time_scale(true)
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(%MainPanel, "modulate:a", 1.0, ENTRANCE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(%MainPanel, "offset_transform_position", Vector2.ZERO, ENTRANCE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index: int in _menu_buttons.size():
		var button := _menu_buttons[index]
		_entrance_tween.tween_property(button, "modulate:a", 1.0, 0.36).set_delay(float(index) * BUTTON_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_button_visual(button: Button) -> void:
	var active: bool = not button.disabled and (_hovered.get(button, false) or _focused.get(button, false))
	var styles: Dictionary = _button_styles.get(button, {})
	if not styles.is_empty():
		var normal_box: StyleBoxFlat = styles["lit"] if active else styles["idle"]
		var text_color: Color = styles["lit_text"] if active else styles["idle_text"]
		button.add_theme_stylebox_override("normal", normal_box)
		button.add_theme_color_override("font_color", text_color)
	var target := HOVER_NUDGE if active else Vector2.ZERO
	var previous: Tween = _hover_tweens.get(button)
	if previous != null and previous.is_valid():
		previous.kill()
	var start: Vector2 = _hover_offsets.get(button, Vector2.ZERO)
	if start.is_equal_approx(target):
		_hover_offsets[button] = target
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_method(func(value: Vector2) -> void: _hover_offsets[button] = value, start, target, HOVER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tweens[button] = tween


func _show_main() -> void:
	GameSettings.preview_volume(GameSettings.master_volume)
	%MainPanel.show()
	%SettingsCard.hide()
	%SettingsPanel.hide()
	%MenuStatus.hide()
	_refresh_saves()
	%NewGame.grab_focus()
	for button: Button in _menu_buttons:
		_hovered[button] = false
		_focused[button] = button.has_focus()
		_update_button_visual(button)


func _refresh_saves() -> void:
	_saved_entries = SaveCatalog.get_entries()
	%Load.disabled = _busy or (not GameSave.has_save() and _saved_entries.is_empty())
	%Load.tooltip_text = "Belum ada data permainan tersimpan" if %Load.disabled else "Lanjutkan dari autosave terakhir"
	_update_button_visual(%Load)


func _new_game() -> void:
	if _busy:
		return
	_refresh_saves()
	if GameSave.has_save() or not _saved_entries.is_empty() or FileAccess.file_exists(GameSave.SAVE_PATH):
		%NewGameConfirm.popup_centered_clamped(Vector2i(560, 240))
		%NewGameConfirm.get_cancel_button().grab_focus()
	else:
		_start_new_game()


func _restore_new_game_focus() -> void:
	if not %NewGameConfirm.visible and not %NameDialog.visible and not _busy:
		%NewGame.grab_focus()


func _start_new_game() -> void:
	if _busy:
		return
	_show_name_dialog.call_deferred()


func _show_name_dialog() -> void:
	%PlayerName.clear()
	%NameDialog.get_ok_button().disabled = true
	%NameDialog.popup_centered_clamped(Vector2i(480, 200))
	%PlayerName.grab_focus()


func _create_game() -> void:
	if _busy or %PlayerName.text.strip_edges().is_empty():
		return
	_set_busy(true)
	var error := GameSave.start_new_game(%PlayerName.text)
	if error != OK:
		_start_failed(error)


func _load_game() -> void:
	_refresh_saves()
	if _busy or %Load.disabled:
		return
	_set_busy(true)
	var error := GameSave.load_game(not _saved_entries.is_empty())
	if error != OK:
		_start_failed(error)


func _set_busy(busy: bool) -> void:
	_busy = busy
	%NewGame.disabled = busy
	%Settings.disabled = busy
	%Quit.disabled = busy
	_refresh_saves()
	for button: Button in _menu_buttons:
		_update_button_visual(button)


func _start_failed(error: Error) -> void:
	get_tree().paused = true
	_set_busy(false)
	%MenuStatus.text = "Permainan belum dapat dibuka. " + error_string(error)
	%MenuStatus.show()
	%NewGame.grab_focus()


func _show_settings() -> void:
	%MainPanel.hide()
	%MenuStatus.hide()
	%SettingsCard.show()
	%SettingsPanel.show()
	%SettingsStatus.text = ""
	%Volume.set_value_no_signal(roundi(GameSettings.master_volume * 100.0))
	%VolumeValue.text = "%d%%" % roundi(%Volume.value)
	%Resolution.select(GameSettings.resolution_index)
	%Volume.grab_focus()


func _preview_volume(value: float) -> void:
	%VolumeValue.text = "%d%%" % roundi(value)
	GameSettings.preview_volume(value / 100.0)


func _change_resolution(index: int) -> void:
	var error := GameSettings.save_settings(GameSettings.master_volume, index)
	%SettingsStatus.text = "Resolusi tersimpan." if error == OK else "Resolusi belum dapat diubah. Coba lagi."
	if error != OK:
		%Resolution.select(GameSettings.resolution_index)
	GameSettings.preview_volume(%Volume.value / 100.0)


func _apply_settings() -> void:
	var error := GameSettings.save_settings(%Volume.value / 100.0, %Resolution.selected)
	%SettingsStatus.text = "Pengaturan tersimpan." if error == OK else "Pengaturan belum tersimpan. Coba lagi."


func _quit() -> void:
	get_tree().quit()
