extends CenterContainer

signal authenticated

@export var password: String = "123"
@export var account_name: String = "User"

@onready var _password: LineEdit = %Password
@onready var _message: Label = %Message


func _ready() -> void:
	%Account.text = account_name
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
