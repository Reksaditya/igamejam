extends CenterContainer

signal authenticated

@export var password: String = "123"
@export var account_name: String = "User"
@export var avatar_texture: Texture2D

@onready var _password: LineEdit = %Password
@onready var _message: Label = %Message
@onready var _avatar: TextureRect = %Avatar
@onready var _avatar_frame: PanelContainer = %AvatarFrame
@onready var _sign_in_glyph: Control = %SignInGlyph


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	%Account.text = account_name
	if avatar_texture != null:
		_avatar.texture = avatar_texture
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw.connect(_draw_logon_backdrop)
	_avatar_frame.draw.connect(_draw_avatar_sheen)
	_sign_in_glyph.draw.connect(_draw_signin_arrow)
	_sign_in_glyph.resized.connect(_sign_in_glyph.queue_redraw)
	_password.text_submitted.connect(_submit)
	%SignIn.pressed.connect(func() -> void: _submit(_password.text))
	_password.grab_focus.call_deferred()


func _submit(value: String) -> void:
	if value == password:
		_password.clear()
		authenticated.emit()
	else:
		_message.text = "Incorrect password"
		_password.select_all()
		_password.grab_focus()


func _draw_logon_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.15, 0.27, 0.28))


func _draw_avatar_sheen() -> void:
	var s := _avatar_frame.size
	if s.x <= 6.0 or s.y <= 6.0:
		return
	var gloss_h := floorf((s.y - 4.0) * 0.42)
	_avatar_frame.draw_rect(Rect2(2.0, 2.0, s.x - 4.0, gloss_h), Color(1.0, 1.0, 1.0, 0.20))
	_avatar_frame.draw_rect(Rect2(2.0, 2.0, s.x - 4.0, 1.0), Color(1.0, 1.0, 1.0, 0.72))


func _draw_signin_arrow() -> void:
	var c := (_sign_in_glyph.size * 0.5).floor() + Vector2(0.5, 0.5)
	_sign_in_glyph.draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), Color.WHITE, 2.0)
	_sign_in_glyph.draw_line(c + Vector2(1, -4), c + Vector2(5, 0), Color.WHITE, 2.0)
	_sign_in_glyph.draw_line(c + Vector2(1, 4), c + Vector2(5, 0), Color.WHITE, 2.0)
