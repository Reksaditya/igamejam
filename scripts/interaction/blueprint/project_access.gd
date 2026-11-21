extends CanvasLayer

var _was_paused: bool = false


func _ready() -> void:
	%OpenProject.pressed.connect(_open)
	%StudyWindow.close_requested.connect(%StudyWindow.hide)
	%StudyWindow.visibility_changed.connect(_on_visibility_changed)


func _open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	%StudyWindow.popup_centered_clamped(Vector2i(620, 560), 0.9)
	%Workbench.get_node("OpenBlueprint").grab_focus()


func _on_visibility_changed() -> void:
	if not %StudyWindow.visible:
		get_tree().paused = _was_paused
		%OpenProject.grab_focus()


func _exit_tree() -> void:
	if %StudyWindow.visible:
		get_tree().paused = _was_paused
