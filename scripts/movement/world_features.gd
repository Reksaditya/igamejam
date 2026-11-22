extends Node2D

const Interaction = preload("res://scripts/movement/world_interaction.gd")
const DOOR := preload("res://scenes/movement/door_interaction.tscn")
const Guard = preload("res://scripts/movement/campus_guard.gd")
const StoryPanel = preload("res://scripts/academic/story_panel.gd")

const DORM_INTERIOR_SCENES: PackedStringArray = ["dorm_room210.tscn", "dorm_floor1.tscn", "dorm_floor2.tscn"]

var _elapsed: float = 0
var _overlay: CanvasLayer
var _blur: ColorRect
var _curfew_due: bool = false
var _curfew_triggered: bool = false


func _ready() -> void:
	var path := get_parent().scene_file_path
	if path == "res://scenes/movement/top_down_movement.tscn":
		var door := DOOR.instantiate()
		door.position = Vector2(1470, 540)
		door.destination = "res://scenes/movement/lecturer_room.tscn"
		door.action_text = "Ruang dosen"
		add_child(door)
		_sign("Ruang Dosen", Vector2(1400, 430))
		var frame := Polygon2D.new()
		frame.polygon = PackedVector2Array([Vector2(1425, 460), Vector2(1515, 460), Vector2(1515, 620), Vector2(1425, 620)])
		frame.color = Color("#527a85")
		add_child(frame)
		_npc("student", "Mahasiswa · Raka", Vector2(400, 540))
	elif path == "res://scenes/movement/campus_lab_room.tscn":
		_interaction("workshop", "Mulai merakit mesin", Vector2(650, 540))
		_sign("Bengkel · Meja perakitan", Vector2(460, 450))
	elif path == "res://scenes/movement/lecturer_room.tscn":
		_interaction("lecturer", "Laporkan proyek", Vector2(650, 540))
		_sign("Dosen Teknik · Pengumpulan proyek", Vector2(420, 430))
		_npc("lecturer", "Dosen Teknik", Vector2(1250, 540))
	if path.ends_with("dorm_floor1.tscn"):
		_npc("student", "Teman asrama", Vector2(500, 540))
		_npc("guard", "Petugas asrama", Vector2(1450, 540))
	elif path.ends_with("campus_classroom.tscn"):
		_npc("student", "Teman sekelas", Vector2(1500, 540))
	_build_blur()
	PlayerStats.changed.connect(_update_blur)
	GameClock.minute_changed.connect(_clock_changed)
	_clock_changed(GameClock.get_absolute_minutes())
	_update_blur()


func _interaction(action: String, caption: String, point: Vector2) -> Area2D:
	var target := Interaction.new()
	target.action = action
	target.caption = caption
	target.position = point
	add_child(target)
	return target


func _sign(value: String, point: Vector2) -> void:
	var sign := Label.new()
	sign.text = value
	sign.theme = preload("res://scenes/ui/menu_theme.tres")
	sign.position = point
	add_child(sign)


func _npc(action: String, caption: String, point: Vector2) -> void:
	var target := _interaction(action, caption, point)
	var figure := Guard.new()
	figure.position.y = 52
	target.add_child(figure)


func _build_blur() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap; void fragment(){ COLOR = textureLod(screen_texture, SCREEN_UV, 2.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_blur.material = material
	layer.add_child(_blur)


func _update_blur() -> void:
	_blur.visible = PlayerStats.get_sanity() >= CareerProgress.SANITY_BLUR_THRESHOLD


func _is_inside_dorm() -> bool:
	var file_name := get_parent().scene_file_path.get_file()
	return file_name in DORM_INTERIOR_SCENES


func _clock_changed(minutes: int) -> void:
	var minute_of_day := posmod(minutes, GameClock.MINUTES_PER_DAY)
	if (minute_of_day >= 22 * 60 or minute_of_day < 6 * 60) and not _is_inside_dorm():
		_curfew_due = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.75 or get_tree().get_meta(&"suppress_world_events", false) or get_tree().paused or SceneTransition.is_active():
		return
	var player := get_parent().get_node_or_null("Player") as CharacterBody2D
	if player == null or player.is_studying() or is_instance_valid(_overlay):
		return
	if CareerProgress.should_graduate():
		CareerProgress.complete_career()
	var pending_khs := CareerProgress.get_pending_khs()
	if not pending_khs.is_empty():
		_overlay = StoryPanel.new()
		_overlay.khs_summary = pending_khs
		add_child(_overlay)
		return
	if not CareerProgress.state.ending.is_empty():
		_overlay = StoryPanel.new()
		_overlay.ending = true
		add_child(_overlay)
		return
	var event := CareerProgress.pending_story()
	if not event.is_empty():
		_overlay = StoryPanel.new()
		_overlay.event_id = event
		add_child(_overlay)
		return
	if _curfew_due and not _curfew_triggered and not _is_inside_dorm():
		_trigger_curfew_return()


func _trigger_curfew_return() -> void:
	_curfew_triggered = true
	_curfew_due = false
	var profile := get_parent().get_node_or_null("PlayerProfile")
	if profile != null and profile.has_method("show_notice"):
		profile.call("show_notice", "Sudah jam malam (22:00). Kembali ke asrama.", 2.0)
	_curfew_fade_to_dorm.call_deferred()


func _curfew_fade_to_dorm() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.85, true, false, true).timeout
	if not is_inside_tree() or _is_inside_dorm() or SceneTransition.is_active():
		return
	SceneTransition.change_scene("res://scenes/movement/dorm_room210.tscn", &"InteriorSpawn", SceneTransition.TransitionStyle.FADE)
