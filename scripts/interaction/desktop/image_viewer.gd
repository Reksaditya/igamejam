extends MarginContainer

var image: Texture2D

@onready var _preview: TextureRect = $Preview
@onready var _empty: Label = $Empty


func _ready() -> void:
	_preview.texture = image
	_empty.visible = image == null
