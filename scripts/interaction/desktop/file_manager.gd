extends MarginContainer

signal open_requested(launcher: Button)

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")

@export var root_folder: DesktopFolder

var _path: Array[DesktopFolder] = []
var _pages: Dictionary[DesktopFolder, HFlowContainer] = {}


func _ready() -> void:
	%Up.pressed.connect(_open_parent)
	if root_folder != null:
		_open_subfolder(root_folder)
	else:
		%Up.hide()
		%Location.text = "No folder configured"


func _open_subfolder(folder: DesktopFolder) -> void:
	if folder != null and folder not in _path:
		_path.append(folder)
		_show_folder()


func _open_parent() -> void:
	if _path.size() > 1:
		_path.pop_back()
		_show_folder()


func _show_folder() -> void:
	var current := _path.back() as DesktopFolder
	if not _pages.has(current):
		_pages[current] = _build_page(current)
	for folder: DesktopFolder in _pages:
		_pages[folder].visible = folder == current
	var names := PackedStringArray()
	for folder: DesktopFolder in _path:
		names.append(folder.folder_name)
	%Location.text = " / ".join(names)
	%Location.tooltip_text = %Location.text
	%Up.visible = _path.size() > 1
	%Scroll.scroll_vertical = 0
	var page := _pages[current]
	for child: Node in page.get_children():
		if child is Launcher:
			child.grab_focus()
			break


func _build_page(folder: DesktopFolder) -> HFlowContainer:
	var page := HFlowContainer.new()
	page.add_theme_constant_override("h_separation", 10)
	page.add_theme_constant_override("v_separation", 10)
	%Pages.add_child(page)
	for resource: Resource in folder.subfolders:
		var child := resource as DesktopFolder
		if child == null or child in _path:
			continue
		var item := Launcher.new()
		item.display_title = child.folder_name
		item.icon_kind = Launcher.IconKind.FOLDER
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item.theme_type_variation = &"FileItem"
		item.pressed.connect(_open_subfolder.bind(child))
		page.add_child(item)
	for scene: PackedScene in folder.files:
		var item := _create_file(scene)
		if item != null:
			item.theme_type_variation = &"FileItem"
			item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			item.open_requested.connect(func(launcher: Button) -> void: open_requested.emit(launcher))
			page.add_child(item)
	if page.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "This folder is empty."
		page.add_child(empty)
	return page


func _create_file(scene: PackedScene) -> Launcher:
	if scene == null:
		return null
	var instance := scene.instantiate()
	if instance is Launcher:
		return instance
	instance.free()
	return null


func collect_attachments() -> Array[Dictionary]:
	var attachments: Array[Dictionary] = []
	var visited: Array[DesktopFolder] = []
	_collect_folder(root_folder, visited, attachments)
	return attachments


func _collect_folder(folder: DesktopFolder, visited: Array[DesktopFolder], attachments: Array[Dictionary]) -> void:
	if folder == null or folder in visited:
		return
	visited.append(folder)
	for scene: PackedScene in folder.files:
		var item := _create_file(scene)
		if item != null:
			var metadata := item.get_attachment_metadata()
			item.free()
			if not metadata.is_empty():
				metadata["source"] = "File Manager"
				attachments.append(metadata)
	for resource: Resource in folder.subfolders:
		_collect_folder(resource as DesktopFolder, visited, attachments)
