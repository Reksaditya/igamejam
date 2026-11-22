class_name DesktopFolder
extends Resource

@export var folder_name: String
## Each scene should have a document or image launcher as its root.
@export var files: Array[PackedScene]
## Assign other DesktopFolder resources here.
@export var subfolders: Array[Resource]
