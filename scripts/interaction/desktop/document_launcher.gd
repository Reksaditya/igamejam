@tool
extends "res://scripts/interaction/desktop/desktop_launcher.gd"

const Notepad = preload("res://scripts/interaction/desktop/notepad.gd")

@export_multiline var starting_text: String
@export var submission_filename: String = "document.txt"


func get_attachment_metadata() -> Dictionary:
	var filename := submission_filename.strip_edges().replace("\\", "/").get_file()
	if filename.get_extension().to_lower() != "txt" or filename.get_basename().is_empty():
		return {}
	return {"filename": filename, "kind": "txt"}


func create_app() -> Control:
	var app := super.create_app() as Notepad
	if app != null:
		app.starting_text = starting_text
	return app
