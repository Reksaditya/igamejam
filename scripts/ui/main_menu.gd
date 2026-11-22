extends Control

const SaveCatalog = preload("res://scripts/ui/save_catalog.gd")

var _saved_entries: Array[Dictionary] = []
var _was_paused: bool = false
var _busy: bool = false


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
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
	get_window().focus_entered.connect(_refresh_saves)
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		%Resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_show_main()


func _exit_tree() -> void:
	GameSettings.preview_volume(GameSettings.master_volume)
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %SettingsPanel.visible:
		_show_main()
		get_viewport().set_input_as_handled()


func _show_main() -> void:
	GameSettings.preview_volume(GameSettings.master_volume)
	%MainPanel.show()
	%SettingsPanel.hide()
	%MenuStatus.hide()
	_refresh_saves()
	%NewGame.grab_focus()


func _refresh_saves() -> void:
	_saved_entries = SaveCatalog.get_entries()
	%Load.disabled = _busy or (not GameSave.has_save() and _saved_entries.is_empty())
	%Load.tooltip_text = "Belum ada data permainan tersimpan" if %Load.disabled else "Lanjutkan dari autosave terakhir"


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
	if not %NewGameConfirm.visible and not _busy:
		%NewGame.grab_focus()


func _start_new_game() -> void:
	if _busy:
		return
	_create_game.call_deferred()


func _create_game() -> void:
	if _busy:
		return
	_set_busy(true)
	var error := GameSave.start_new_game()
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


func _start_failed(error: Error) -> void:
	get_tree().paused = true
	_set_busy(false)
	%MenuStatus.text = "Permainan belum dapat dibuka. " + error_string(error)
	%MenuStatus.show()
	%NewGame.grab_focus()


func _show_settings() -> void:
	%MainPanel.hide()
	%MenuStatus.hide()
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
