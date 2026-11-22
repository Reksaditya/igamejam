extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameClock").restore_save_state({"minutes": 480, "remainder": 0})
	for scene: String in ["campus_classroom", "campus_classroom_floor2", "campus_classroom_floor3"]:
		change_scene_to_file("res://scenes/movement/%s.tscn" % scene)
		await scene_changed
		await _frames(4)
		var classroom := current_scene.get_node("ClassActivity")
		var seat := classroom.get_node("Seat4")
		var player := current_scene.get_node("Player")
		player.position = seat.position
		await _frames(6)
		assert(seat.occupied and not seat.available)
		assert(not seat.get_node("Prompt").visible)
		assert(not seat._interact())
		classroom._interact_seat(seat)
		classroom._open_lesson(seat)
		assert(not player.is_studying() and not is_instance_valid(classroom._lesson))
		assert(classroom.get_node("ClassNPCs/SeatedStudent").visible)
		assert(classroom.get_node("ClassNPCs/Lecturer").visible)
		for id: String in ["Seat", "Seat2", "Seat3"]:
			assert(not classroom.get_node(id).occupied and classroom.get_node(id).available)
		if "--capture" in OS.get_cmdline_user_args() and scene == "campus_classroom":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/classroom-npcs.png")
	for pair: Array in [["dorm_floor1", "Randomash"], ["dorm_floor2", "RandomKid"], ["classroom_corridor_floor1", "RandomKid"], ["classroom_corridor_floor3", "Randomash"]]:
		change_scene_to_file("res://scenes/movement/%s.tscn" % pair[0])
		await scene_changed
		assert(current_scene.has_node("WorldFeatures/" + pair[1]))
		var npc := current_scene.get_node("WorldFeatures/" + pair[1])
		assert(npc is Sprite2D and npc.get_child_count() == 0)
		assert(is_equal_approx(npc.texture.get_height() * npc.scale.y, 64 * absf(current_scene.get_node("Player/Visual").scale.y)))
	print("PASS: student reserves rightmost seat in all classrooms, lecturer present, three usable seats, four corridor NPC placements without dialogue")
	quit()


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
