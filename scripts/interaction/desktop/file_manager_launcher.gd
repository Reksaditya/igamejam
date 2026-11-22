@tool
extends "res://scripts/interaction/desktop/desktop_launcher.gd"

const FileManager = preload("res://scripts/interaction/desktop/file_manager.gd")


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
