@tool
extends "res://scripts/interaction/desktop/desktop_launcher.gd"

const ImageViewer = preload("res://scripts/interaction/desktop/image_viewer.gd")
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "gif", "dds", "exr", "hdr", "ktx"]

@export var image: Texture2D
## Leave blank to use the filename of the assigned image.
@export var submission_filename: String


func get_attachment_metadata() -> Dictionary:
	if image == null:
		return {}
	var configured := submission_filename.strip_edges()
	var filename := (image.resource_path if configured.is_empty() else configured).replace("\\", "/").get_file()
	if filename.get_extension().to_lower() not in IMAGE_EXTENSIONS or filename.get_basename().is_empty():
		return {}
	return {"filename": filename, "kind": "image"}


func create_app() -> Control:
	var app := super.create_app() as ImageViewer
	if app != null:
		app.image = image
	return app
