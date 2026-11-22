extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/movement/top_down_movement.tscn")
	await scene_changed
	await _frames(10)
	var player := current_scene.get_node("Player") as CharacterBody2D
	var sprite := player.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	assert(frames.get_frame_count(&"idle") == 7)
	assert(frames.get_animation_loop(&"idle"))
	assert(frames.get_animation_speed(&"idle") == 7.0)
	for index: int in 7:
		assert(frames.get_frame_texture(&"idle", index).resource_path == "res://assets/characters/mc/idle/%d.png" % (index + 1))
	assert(sprite.is_playing())
	var loops: Array[int] = [0]
	sprite.animation_looped.connect(func() -> void: loops[0] += 1)
	await _frames(75)
	assert(loops[0] >= 1)
	var start_x := player.position.x
	Input.action_press("move_left")
	await _frames(15)
	assert(player.position.x < start_x)
	assert(not sprite.is_playing())
	assert(sprite.frame == 0)
	assert(player.get_node("Visual").scale.x == -1.5)
	Input.action_release("move_left")
	await _frames(4)
	assert(sprite.is_playing())
	player.set_studying(true)
	var position := player.position
	Input.action_press("move_right")
	await _frames(5)
	assert(player.position == position)
	assert(not sprite.is_playing())
	Input.action_release("move_right")
	player.set_studying(false)
	await _frames(3)
	assert(sprite.is_playing())
	assert(player.is_on_floor())
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	assert((collision.shape as CapsuleShape2D).height == 84.0)
	print("PASS: seven ordered frames, idle loop, moving frame, facing scale, study interaction, grounded collision")
	quit()


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
