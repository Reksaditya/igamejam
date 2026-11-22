extends Area2D

const ActivityPanel = preload("res://scripts/ui/activity_panel.gd")

@export var action: String = "sleep"
@export var caption: String = "Istirahat"

var _player: CharacterBody2D
var _prompt: Button
var _panel: CanvasLayer


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 140)
	collision.shape = shape
	add_child(collision)
	_prompt = Button.new()
	_prompt.theme = preload("res://scenes/ui/menu_theme.tres")
	_prompt.text = "E · " + caption
	_prompt.position = Vector2(-90, -130)
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.hide()
	add_child(_prompt)
	_prompt.pressed.connect(interact)
	body_entered.connect(func(body: Node2D):
		if body is CharacterBody2D:
			_player = body
			_prompt.show()
	)
	body_exited.connect(func(body: Node2D):
		if body == _player:
			_player = null
			_prompt.hide()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and interact():
		get_viewport().set_input_as_handled()


func interact() -> bool:
	if not is_instance_valid(_player) or not overlaps_body(_player) or _player.is_studying() or SceneTransition.is_active() or is_instance_valid(_panel):
		return false
	if action == "computer":
		GameSave.save_now()
		SceneTransition.change_scene(GameSave.DESKTOP_SCENE, &"ComputerSpawn")
		return true
	if action in ["workshop", "lecturer"]:
		var path := "res://scripts/academic/workshop.gd" if action == "workshop" else "res://scripts/academic/lecturer.gd"
		if ResourceLoader.exists(path):
			_panel = load(path).new()
			add_child(_panel)
			return true
	_panel = ActivityPanel.new()
	add_child(_panel)
	if action == "sleep":
		_panel.label("Kamar 210 · Istirahat", 26)
		_panel.label("Tidur 8 jam memulihkan energi. Tidur setelah pukul 22.00 mengurangi pemulihan 10 poin per jam keterlambatan.")
		_panel.button("Tidur 8 jam", _rest.bind(8))
		_panel.button("Istirahat singkat 1 jam", _rest.bind(1))
	else:
		_panel.label(caption, 26)
		_panel.label("Ikuti kelas, kerjakan kegiatan LMS, dan lengkapi rancangan mesin. Jangan lupa beristirahat sebelum pukul 22.00.")
	_panel.add_close()
	return true


func _rest(hours: int) -> void:
	var error := CareerProgress.rest(hours)
	_panel.clear()
	_panel.label("Istirahat selesai" if error == OK else "Istirahat belum tersimpan. Coba kembali.", 26)
	_panel.label("Energi %.0f/100 · Kewarasan %.0f/100 · %s" % [PlayerStats.get_energy(), PlayerStats.get_sanity(), GameClock.get_formatted_time()])
	_panel.add_close()
