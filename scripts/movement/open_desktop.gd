extends Button

const DESKTOP_SCENE := "res://scenes/interaction/desktop/desktop.tscn"
const RETURN_CONTEXT := &"desktop_return_context"

@export var return_spawn: StringName = &"InitialSpawn"

var _loading := false


func _pressed() -> void:
	if _loading or SceneTransition.is_active():
		return
	var tree := get_tree()
	var origin := tree.current_scene
	if origin == null or origin.scene_file_path.is_empty():
		return

	_loading = true
	disabled = true
	var original_text := text
	text = "Opening desktop…"
	var desktop: PackedScene
	if DisplayServer.get_name() != "headless":
		var error := OK
		if ResourceLoader.load_threaded_get_status(DESKTOP_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			error = ResourceLoader.load_threaded_request(DESKTOP_SCENE, "PackedScene")
		if error == OK:
			while ResourceLoader.load_threaded_get_status(DESKTOP_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await tree.process_frame
			desktop = ResourceLoader.load_threaded_get(DESKTOP_SCENE) as PackedScene
	if tree.current_scene != origin or SceneTransition.is_active():
		_finish_loading(original_text, false)
		return
	if desktop == null:
		desktop = ResourceLoader.load(DESKTOP_SCENE, "PackedScene") as PackedScene
	if desktop == null:
		_finish_loading(original_text, true)
		return

	tree.set_meta(RETURN_CONTEXT, {"scene": origin.scene_file_path, "spawn": return_spawn})
	if tree.change_scene_to_packed(desktop) != OK:
		tree.remove_meta(RETURN_CONTEXT)
		_finish_loading(original_text, true)


func _finish_loading(original_text: String, failed: bool) -> void:
	_loading = false
	disabled = false
	text = original_text
	if failed:
		tooltip_text = "Could not open the desktop."
