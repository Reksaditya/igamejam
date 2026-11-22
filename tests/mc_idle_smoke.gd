extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	if "--capture" in OS.get_cmdline_user_args():
		current_scene.get_node("Player/Camera2D").zoom = Vector2(3, 3)
		current_scene.get_node("Player/Camera2D").position = Vector2(0, -25)
	await _frames(10)
	var player := current_scene.get_node("Player") as CharacterBody2D
	var sprite := player.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	assert(frames.get_frame_count(&"idle") == 7)
	assert(frames.get_animation_loop(&"idle"))
	assert(frames.get_animation_speed(&"idle") == 7.0)
	for index: int in 7:
		assert(frames.get_frame_texture(&"idle", index).resource_path == "res://assets/characters/mc/idle/%d.png" % (index + 1))
	assert(frames.get_frame_count(&"walk") == 6 and frames.get_animation_loop(&"walk"))
	for index: int in 6:
		assert(frames.get_frame_texture(&"walk", index).resource_path == "res://assets/characters/mc/walk/%d.png" % (index + 1))
	assert(frames.get_frame_count(&"side_idle") == 7 and frames.get_animation_loop(&"side_idle"))
	assert(player.side_idle_seconds == 3.0)
	for index: int in 7:
		assert(frames.get_frame_texture(&"side_idle", index).resource_path == "res://assets/characters/mc/side_idle/%d.png" % (index + 1))
	assert(sprite.is_playing())
	var loops: Array[int] = [0]
	sprite.animation_looped.connect(func() -> void: loops[0] += 1)
	await _frames(75)
	assert(loops[0] >= 1)
	var start_x := player.position.x
	Input.action_press("move_left")
	await _frames(15)
	assert(player.position.x < start_x)
	assert(sprite.is_playing() and sprite.animation == &"walk")
	assert(sprite.frame > 0)
	assert(sprite.flip_h)
	assert(player.get_node("Visual").scale.x == -1.5)
	await _capture("mc-walk-left")
	Input.action_release("move_left")
	await _frames(4)
	assert(sprite.is_playing() and sprite.animation == &"side_idle" and sprite.flip_h)
	assert(player.get_node("Visual").scale.x < 0)
	await _capture("mc-side-idle-left")
	await _frames(170)
	assert(sprite.animation == &"side_idle")
	await _frames(9)
	assert(sprite.animation == &"idle" and not sprite.flip_h)
	assert(player._idle_previous.visible)
	assert(sprite.modulate.a > 0 and sprite.modulate.a < 1)
	assert(player._idle_previous.modulate.a > 0 and player._idle_previous.modulate.a < 1)
	await _capture("mc-idle-blend")
	await _frames(20)
	assert(not player._idle_previous.visible and is_equal_approx(sprite.modulate.a, 1.0))
	start_x = player.position.x
	Input.action_press("move_right")
	await _frames(15)
	assert(player.position.x > start_x)
	assert(sprite.animation == &"walk" and sprite.is_playing())
	assert(player.get_node("Visual").scale.x > 0 and sprite.flip_h)
	await _capture("mc-walk-right")
	Input.action_release("move_right")
	await _frames(4)
	assert(sprite.animation == &"side_idle" and sprite.is_playing())
	assert(player.get_node("Visual").scale.x > 0 and sprite.flip_h)
	await _capture("mc-side-idle-right")
	await _frames(60)
	Input.action_press("move_right")
	await _frames(5)
	assert(sprite.animation == &"walk")
	Input.action_release("move_right")
	await _frames(174)
	assert(sprite.animation == &"side_idle")
	await _frames(17)
	assert(sprite.animation == &"idle" and not sprite.flip_h)
	await _frames(20)
	await _capture("mc-front-idle-after-walk")
	Input.action_press("move_left")
	await _frames(5)
	Input.action_release("move_left")
	await _frames(4)
	assert(sprite.animation == &"side_idle")
	player.set_studying(true)
	var position := player.position
	Input.action_press("move_right")
	await _frames(5)
	assert(player.position == position)
	assert(sprite.is_playing() and sprite.animation == &"sit" and not sprite.flip_h)
	assert(frames.get_frame_texture(&"sit", 0).resource_path == "res://assets/characters/mc/sit/1.png")
	assert(not player._idle_previous.visible and is_equal_approx(sprite.modulate.a, 1.0))
	var seated_y := sprite.position.y
	await _frames(5)
	assert(not is_equal_approx(sprite.position.y, seated_y))
	Input.action_release("move_right")
	player.set_studying(false)
	await _frames(3)
	assert(sprite.is_playing() and sprite.animation == &"idle")
	assert(sprite.position.is_equal_approx(player._sprite_home))
	assert(player.is_on_floor())
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	assert((collision.shape as CapsuleShape2D).height == 84.0)
	print("PASS: ordered idle/walk/side-idle frames, three-second crossfade, timer restart, supplied sitting pose with breathing, standing restore and grounded collision")
	quit()


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame


func _capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + id + ".png")
