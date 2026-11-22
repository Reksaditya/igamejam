extends Control

const PROFILE := "Deadline Artist Preview"
const DESKTOP := "res://scenes/interaction/desktop/desktop.tscn"
const WORKSHOP := "res://scenes/interaction/workshop/transmission_workshop.tscn"


func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or ProjectSettings.get_setting("application/config/custom_user_dir_name", "") != PROFILE:
		%Desktop.disabled = true
		%Workshop.disabled = true
		%Status.text = "Jalankan build pratinjau artis untuk menggunakan menu ini."
		return
	%Desktop.pressed.connect(_open.bind(DESKTOP))
	%Workshop.pressed.connect(_open.bind(WORKSHOP))
	%Desktop.grab_focus()


func _open(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		%Status.text = "Gagal membuka adegan. " + error_string(error)
