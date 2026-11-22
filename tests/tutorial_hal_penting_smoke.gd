extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("GameSettings")
	var saves := root.get_node("GameSave")
	assert(settings.reset_tutorials() == OK)

	# 1. Desktop squared-pointer spotlight tutorial (4 steps) + Hal Penting -> website.txt
	var desktop_scene := load("res://scenes/interaction/desktop/desktop.tscn") as PackedScene
	var desktop := desktop_scene.instantiate() as Control
	desktop.login_scene = null
	root.add_child(desktop)
	desktop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	desktop.size = Vector2(1152.0, 648.0)
	await _frames(2)
	while desktop._boot_cover.visible:
		await process_frame
	await _frames(4)

	assert(desktop.is_tutorial_visible(), "Desktop spotlight tutorial must appear on first entry")
	var dtut: Node = desktop._tutorial
	assert(dtut.step_count() == 4, "Desktop tutorial must have 4 brisk steps, got %d" % dtut.step_count())
	var seen_captions: PackedStringArray = PackedStringArray()
	for i: int in range(4):
		assert(dtut.current_step_index() == i)
		var rect: Rect2 = dtut.get_highlight_rect()
		assert(rect.size.x > 10.0 and rect.size.y > 10.0, "Desktop tutorial step %d must have valid highlight rect: %s" % [i, str(rect)])
		var cap: String = dtut.get_caption_text()
		assert(not cap.is_empty() and not cap.contains("\n"), "Caption must be a single crisp line: " + cap)
		assert(cap.split(" ", false).size() <= 12, "Caption too wordy: " + cap)
		seen_captions.append(cap)
		dtut.advance()
		await _frames(2)
	# Wait for 0.2s fade-out to complete cleanly
	await create_timer(0.32).timeout
	assert(not desktop.is_tutorial_visible(), "Desktop tutorial must close after last step")
	assert(settings.has_seen_tutorial("desktop_intro"), "desktop_intro must persist after completing walkthrough")

	# Verify Hal Penting folder on Desktop -> opens website.txt with exact 2 websites
	var hal_penting := desktop.get_node("%Launchers/HalPentingLauncher")
	assert(hal_penting.display_title == "Hal Penting")
	var fm: Control = hal_penting.create_app()
	assert(fm != null and fm.root_folder != null and fm.root_folder.folder_name == "Hal Penting")
	assert(fm.root_folder.files.size() >= 1)
	var web_launcher: Control = fm.root_folder.files[0].instantiate()
	assert(web_launcher.display_title == "website.txt")
	var notepad: Control = web_launcher.create_app()
	assert(notepad != null)
	var content: String = notepad.starting_text
	assert("www.redlineuni.com" in content and "LMS" in content and "Universitas Redline" in content)
	assert("www.placetostudy.com" in content and "Perpustakaan" in content and "Perpustakaan Belajar" in content)
	notepad.free()
	web_launcher.free()
	fm.free()

	# Verify File Manager Documents replaced Catatan.txt with website.txt
	var docs := load("res://scenes/interaction/desktop/folders/documents.tres") as DesktopFolder
	var has_website := false
	var has_catatan := false
	for scene: PackedScene in docs.files:
		var inst := scene.instantiate()
		if inst.display_title == "website.txt":
			has_website = true
		if inst.display_title.to_lower() == "catatan.txt":
			has_catatan = true
		inst.free()
	assert(has_website and not has_catatan, "Documents folder must replace Catatan.txt with website.txt")

	desktop.queue_free()
	await _frames(2)

	# 2. Workshop squared-pointer spotlight tutorial EVEN WITH 0 owned blueprints
	var workshop_scene := load("res://scenes/interaction/workshop/transmission_workshop.tscn") as PackedScene
	var workshop := workshop_scene.instantiate() as Control
	workshop.demo_blueprint = false
	root.add_child(workshop)
	workshop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	workshop.size = Vector2(1152.0, 648.0)
	await _frames(4)
	assert(workshop._owned_puzzles().is_empty(), "Expected 0 owned blueprints")
	assert(workshop.is_tutorial_visible(), "Workshop spotlight tutorial must trigger even with 0 blueprints")
	var wtut: Node = workshop._tutorial
	assert(wtut.step_count() == 4, "Workshop tutorial must have 4 steps")
	for i: int in range(4):
		var rect: Rect2 = wtut.get_highlight_rect()
		assert(rect.size.x > 20.0 and rect.size.y > 16.0, "Workshop step %d (including hidden Crank fallback) must have non-zero rect: %s" % [i, str(rect)])
		var cap: String = wtut.get_caption_text()
		assert(not cap.is_empty() and not cap.contains("\n") and cap.split(" ", false).size() <= 12)
		if i < 3:
			wtut.advance()
			await _frames(2)
	wtut.skip()
	await create_timer(0.32).timeout
	assert(not workshop.is_tutorial_visible(), "Workshop tutorial must close cleanly on skip")
	assert(settings.has_seen_tutorial("blueprint_workshop_intro"))
	workshop.queue_free()
	await _frames(2)

	# 3. Verify New Game resets tutorial flags cleanly
	assert(saves.start_new_game("FreshPlayer") == OK)
	await scene_changed
	await _frames(2)
	assert(not settings.has_seen_tutorial("desktop_intro"), "New Game must reset desktop_intro tutorial flag")
	assert(not settings.has_seen_tutorial("blueprint_workshop_intro"), "New Game must reset blueprint_workshop_intro tutorial flag")

	print("PASS: visual fade-in squared-pointer tutorials (Desktop 4 steps & 0-blueprint Workshop 4 steps), Hal Penting -> website.txt, and New Game tutorial reset")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
