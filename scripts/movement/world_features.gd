extends Node2D

const Interaction = preload("res://scripts/movement/world_interaction.gd")
const Guard = preload("res://scripts/movement/campus_guard.gd")
const StoryPanel = preload("res://scripts/academic/story_panel.gd")

var _elapsed: float = 0
var _overlay: CanvasLayer
var _guard: Node2D
var _blur: ColorRect
var _curfew_due: bool = false


func _ready() -> void:
	var path := get_parent().scene_file_path
	if path in ["res://scenes/movement/top_down_movement.tscn", "res://scenes/movement/dorm_exterior.tscn"]:
		_npc.call_deferred("student", "Mahasiswa · Raka", Vector2(1050, 540))
	if path == "res://scenes/movement/campus_lab_room.tscn":
		_interaction("workshop", "Mulai merakit mesin", Vector2(650, 540))
		_sign("Bengkel · Meja perakitan", Vector2(460, 450))
		_interaction("lecturer", "Laporkan proyek", Vector2(1530, 540))
		_sign("Dosen · Pengumpulan proyek", Vector2(1400, 430))
	elif path == "res://scenes/movement/lecturer_room.tscn":
		_interaction("lecturer", "Laporkan proyek", Vector2(650, 540))
		_sign("Dosen Teknik · Pengumpulan proyek", Vector2(420, 430))
		_npc("lecturer", "Dosen Teknik", Vector2(1250, 540))
	if path.ends_with("dorm_floor1.tscn"):
		_art_npc("Randomash", "randomash", Vector2(500, 620))
		_npc("guard", "Petugas asrama", Vector2(1450, 540))
	elif path.ends_with("dorm_floor2.tscn"):
		_art_npc("RandomKid", "random_kid", Vector2(700, 620))
	elif path.ends_with("classroom_corridor_floor1.tscn"):
		_art_npc("RandomKid", "random_kid", Vector2(480, 620))
	elif path.ends_with("classroom_corridor_floor3.tscn") or path.ends_with("campus_lab.tscn"):
		_art_npc("Randomash", "randomash", Vector2(480, 620))
	var lighting := preload("res://scripts/movement/world_lighting.gd").new()
	lighting.name = "WorldLighting"
	add_child(lighting)
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
	figure.scale = Vector2.ONE * _actor_height() / 82.0
	figure.position.y = 620 - point.y - 18 * figure.scale.y
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


func _clock_changed(minutes: int) -> void:
	var hour := (minutes % 1440) / 60.0
	if (hour >= 22 or hour < 6) and not get_parent().scene_file_path.get_file().begins_with("dorm_"):
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
	if _curfew_due and not is_instance_valid(_guard):
		_guard = Guard.new()
		_guard.player = player
		_guard.scale = Vector2.ONE * _actor_height() / 82.0
		var edge: float = player.get_node("Camera2D").limit_right - 80
		_guard.position = Vector2(clampf(player.position.x + 350, 80, edge), 620 - 18 * _guard.scale.y)
		add_child(_guard)


func _art_npc(id: String, asset: String, point: Vector2) -> void:
	var figure := Sprite2D.new()
	figure.name = id
	figure.texture = load("res://assets/npcs/%s.png" % asset)
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var actor := get_parent().get_node("Player/Visual") as Node2D
	figure.scale = Vector2.ONE * absf(actor.scale.y) * 0.16
	figure.position = point - Vector2(0, figure.texture.get_height() * figure.scale.y * 0.5)
	figure.z_index = 1
	add_child(figure)


func _actor_height() -> float:
	var visual := get_parent().get_node("Player/Visual") as Node2D
	return 64 * absf(visual.scale.y)
