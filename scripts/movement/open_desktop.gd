extends Button

const DESKTOP_SCENE := "res://scenes/interaction/desktop/desktop.tscn"
const RETURN_CONTEXT := &"desktop_return_context"

@export var return_spawn: StringName = &"InitialSpawn"


func _pressed() -> void:
	if SceneTransition.is_active():
		return
	var tree := get_tree()
	var origin := tree.current_scene
	if origin == null or origin.scene_file_path.is_empty():
		return
	tree.set_meta(RETURN_CONTEXT, {"scene": origin.scene_file_path, "spawn": return_spawn})
	if tree.change_scene_to_file(DESKTOP_SCENE) != OK:
		tree.remove_meta(RETURN_CONTEXT)
		tooltip_text = "Could not open the desktop."
