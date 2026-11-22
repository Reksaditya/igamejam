@tool
extends "res://scripts/interaction/desktop/desktop_launcher.gd"

const FileManager = preload("res://scripts/interaction/desktop/file_manager.gd")

@export var folder: DesktopFolder


func create_app() -> Control:
	var app := super.create_app() as FileManager
	if app != null and folder != null:
		app.root_folder = folder
	return app


func collect_attachments(open_content: Control) -> Array[Dictionary]:
	if open_content is FileManager:
		return open_content.collect_attachments()
	var instance := create_app()
	var attachments: Array[Dictionary] = []
	if instance is FileManager:
		attachments = instance.collect_attachments()
	if instance != null:
		instance.free()
	return attachments
