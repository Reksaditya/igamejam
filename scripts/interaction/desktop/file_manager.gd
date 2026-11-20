extends MarginContainer

signal open_requested(launcher: Button)

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")


func _ready() -> void:
	var files: GridContainer = %Files
	for child: Node in files.get_children():
		_connect_item(child)
	files.child_entered_tree.connect(_connect_item)


func _connect_item(child: Node) -> void:
	var item := child as Launcher
	if item != null:
		item.open_requested.connect(func(launcher: Button) -> void: open_requested.emit(launcher))


func collect_attachments() -> Array[Dictionary]:
	var attachments: Array[Dictionary] = []
	for child: Node in $Layout/Scroll/Files.get_children():
		var item := child as Launcher
		if item == null:
			continue
		var metadata := item.get_attachment_metadata()
		if not metadata.is_empty():
			metadata["source"] = "File Manager"
			attachments.append(metadata)
	return attachments
