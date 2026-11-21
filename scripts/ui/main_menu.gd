extends Control

const SaveCatalog = preload("res://scripts/ui/save_catalog.gd")

var _saved_entries: Array[Dictionary] = []
var _was_paused: bool = false


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	%NewGame.pressed.connect(_new_game)
	%Load.pressed.connect(_show_load)
	%Settings.pressed.connect(_show_settings)
	%Quit.pressed.connect(_quit)
	%SettingsBack.pressed.connect(_show_main)
	%LoadBack.pressed.connect(_show_main)
	%Apply.pressed.connect(_apply_settings)
	%Volume.value_changed.connect(_preview_volume)
	%SaveList.item_selected.connect(_select_save)
	%NewGamePlaceholder.visibility_changed.connect(_restore_new_game_focus)
	get_window().focus_entered.connect(_refresh_saves)
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		%Resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_show_main()


func _exit_tree() -> void:
	GameSettings.preview_volume(GameSettings.master_volume)
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (%SettingsPanel.visible or %LoadPanel.visible):
		_show_main()
		get_viewport().set_input_as_handled()


func _show_main() -> void:
	GameSettings.preview_volume(GameSettings.master_volume)
	%MainPanel.show()
	%SettingsPanel.hide()
	%LoadPanel.hide()
	_refresh_saves()
	%NewGame.grab_focus()


func _refresh_saves() -> void:
	_saved_entries = SaveCatalog.get_entries()
	%Load.disabled = _saved_entries.is_empty()
	%Load.tooltip_text = "Belum ada data permainan tersimpan" if %Load.disabled else "Lihat data permainan tersimpan"


func _new_game() -> void:
	%NewGamePlaceholder.popup_centered_clamped(Vector2i(420, 180))
	%NewGamePlaceholder.get_ok_button().grab_focus()


func _restore_new_game_focus() -> void:
	if not %NewGamePlaceholder.visible:
		%NewGame.grab_focus()


func _show_load() -> void:
	_refresh_saves()
	if _saved_entries.is_empty():
		return
	%MainPanel.hide()
	%SettingsPanel.hide()
	%LoadPanel.show()
	%SaveList.clear()
	for entry: Dictionary in _saved_entries:
		%SaveList.add_item(entry.title)
	%SaveList.select(0)
	_select_save(0)
	%SaveList.grab_focus()


func _select_save(index: int) -> void:
	if index >= 0 and index < _saved_entries.size():
		%SaveDetails.text = _saved_entries[index].details


func _show_settings() -> void:
	%MainPanel.hide()
	%LoadPanel.hide()
	%SettingsPanel.show()
	%SettingsStatus.text = ""
	%Volume.set_value_no_signal(roundi(GameSettings.master_volume * 100.0))
	%VolumeValue.text = "%d%%" % roundi(%Volume.value)
	%Resolution.select(GameSettings.resolution_index)
	%Volume.grab_focus()


func _preview_volume(value: float) -> void:
	%VolumeValue.text = "%d%%" % roundi(value)
	GameSettings.preview_volume(value / 100.0)


func _apply_settings() -> void:
	var error := GameSettings.save_settings(%Volume.value / 100.0, %Resolution.selected)
	%SettingsStatus.text = "Pengaturan tersimpan." if error == OK else "Pengaturan belum tersimpan. Coba lagi."


func _quit() -> void:
	get_tree().quit()
