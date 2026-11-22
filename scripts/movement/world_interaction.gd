extends Area2D

const ActivityPanel = preload("res://scripts/ui/activity_panel.gd")

@export var action: String = "sleep"
@export var caption: String = "Istirahat"
@export var interaction_size := Vector2(100, 140)

var _player: CharacterBody2D
var _prompt: Button
var _panel: CanvasLayer


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = interaction_size
	collision.shape = shape
	add_child(collision)
	_prompt = Button.new()
	_prompt.z_index = 10
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
		return GameSave.open_desktop_from(get_tree().current_scene, &"ComputerSpawn")
	if action in ["workshop", "lecturer"]:
		var path := "res://scripts/academic/workshop.gd" if action == "workshop" else "res://scripts/academic/lecturer.gd"
		if ResourceLoader.exists(path):
			_panel = load(path).new()
			add_child(_panel)
			return true
	_panel = ActivityPanel.new()
	add_child(_panel)
	if action == "sleep":
		_panel.label("Kamar 203 · Istirahat", 26)
		_panel.label("Tidur 8 jam sebelum/tepat pukul 22.00 memulihkan Energi ke 100 dan Kewarasan ke Normal (50). Tidur pukul 23.00 ke atas mengurangi Energi bangun 10 poin per jam lewat pukul 22.00.")
		_panel.button("Tidur 8 jam", _rest.bind(8))
		_panel.button("Istirahat singkat 1 jam", _rest.bind(1))
		_panel.button("Tidur sampai besok pagi (06:00)", _next_week)
	elif action == "unavailable_building":
		_panel.label("Gedung belum tersedia", 26)
		_panel.label("Perpustakaan belum dapat dimasuki.")
	elif action == "locked_room":
		_panel.label(caption, 26)
		_panel.label("Kamar ini milik penghuni lain dan terkunci. Kamarmu adalah kamar 203 di lantai dua.")
	else:
		_panel.label(caption, 26)
		_panel.label("Jam malam mulai pukul 22.00. Kamar 203 berada di lantai dua. Tidur delapan jam dan masuk asrama sebelum terlambat." if action == "guard" else "Lengkapi catatan kelas di Perpustakaan lewat komputer asrama. Dapatkan blueprint dari kelas atau panduan di Perpustakaan, lalu rakit mesinnya di bengkel dan laporkan kepada dosen. Kita juga perlu beristirahat sebelum pukul 22.00.")
	_panel.add_close()
	return true


func _rest(hours: int) -> void:
	await _sleep_pose()
	var error := CareerProgress.rest(hours)
	_panel.clear()
	_panel.label("Istirahat selesai" if error == OK else "Istirahat belum tersimpan. Coba kembali.", 26)
	_panel.label("Energi %.0f/100 · Kewarasan %.0f/100 · %s" % [PlayerStats.get_energy(), PlayerStats.get_sanity(), GameClock.get_formatted_time()])
	_panel.add_close()


func _next_week() -> void:
	await _sleep_pose()
	var error := CareerProgress.sleep_until_morning()
	_panel.clear()
	_panel.label("Hari berikutnya dimulai" if error == OK else "Istirahat belum tersimpan. Coba kembali.", 26)
	_panel.label("Semester %d · Hari %d/12 · %s · Energi %.0f/100 · Kewarasan %.0f/100" % [
		CareerProgress.semester(),
		CareerProgress.day_in_semester(),
		GameClock.get_formatted_time(),
		PlayerStats.get_energy(),
		PlayerStats.get_sanity(),
	])
	_panel.add_close()


func _sleep_pose() -> void:
	var room := get_tree().current_scene
	if not room.has_method("play_sleep"):
		return
	_panel.can_close = false
	_prompt.hide()
	_panel.window.hide()
	await room.play_sleep()
	_panel.can_close = true
	_panel.window.show()
	_prompt.visible = is_instance_valid(_player) and overlaps_body(_player)
