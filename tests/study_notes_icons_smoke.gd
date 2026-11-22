extends SceneTree

const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var saves := root.get_node("GameSave")
	var career := root.get_node("CareerProgress")
	var notes := root.get_node("StudyNotes")

	# 1. Verify all 4 pixel-art PNGs exist, load, and icon_gpa_pixel.png has no top-left stray pixel
	for path: String in [
		"res://assets/textures/hud/icon_energy_pixel.png",
		"res://assets/textures/hud/icon_sanity_pixel.png",
		"res://assets/textures/hud/icon_gpa_pixel.png",
		"res://assets/textures/ui/study_notes_book.png",
	]:
		assert(ResourceLoader.exists(path), "Missing asset: " + path)
		var tex := load(path) as Texture2D
		assert(tex != null and tex.get_width() > 0 and tex.get_height() > 0, "Invalid texture: " + path)

	var gpa_img := (load("res://assets/textures/hud/icon_gpa_pixel.png") as Texture2D).get_image()
	for y: int in range(12):
		for x: int in range(12):
			assert(gpa_img.get_pixel(x, y).a < 0.05, "Stray pixel found in icon_gpa_pixel.png at (%d, %d)" % [x, y])

	# Verify stats_hud.gd renders icons with nearest filtering & keep aspect centered
	var stats_hud_script: Script = load("res://scripts/movement/stats_hud.gd")
	var hud: PanelContainer = stats_hud_script.new()
	root.add_child(hud)
	await _frames(2)
	assert(hud._pills.size() == 3)
	for pill: PanelContainer in hud._pills:
		var glyph := pill.get_child(0).get_child(0) as TextureRect
		assert(glyph.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		assert(glyph.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert(glyph.custom_minimum_size == Vector2(20, 20))
	hud.queue_free()
	await _frames(2)

	# 2. Verify StudyNotes open-book overlay layout across narrow, default, and wide viewports
	assert(saves.start_new_game("Rina") == OK)
	await scene_changed
	await _frames(2)
	for sec: int in range(3):
		assert(career.attempt_section(1, 1, sec) == OK)
		assert(career.finish_section(1, 1, sec, true) == OK)
	assert(career.finish_class(1, 1) == OK)

	notes.open_book(1)
	await _frames(2)
	assert(notes.is_book_open(), "StudyNotes book overlay must open")
	assert(notes._book_texture.texture.resource_path == "res://assets/textures/ui/study_notes_book.png")
	assert(notes._book_texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(notes._book_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

	var orig_scale_size := root.content_scale_size
	for vp_size: Vector2i in [Vector2i(640, 480), Vector2i(1152, 648), Vector2i(1920, 1080)]:
		root.size = vp_size
		root.content_scale_size = vp_size
		notes._fit_book()
		await _frames(2)
		var book_rect: Rect2 = notes.get_book_frame_rect()
		var left_rect: Rect2 = notes.get_left_page_rect()
		var right_rect: Rect2 = notes.get_right_page_rect()
		assert(book_rect.position.x >= 0.0 and book_rect.end.x <= float(vp_size.x) + 1.0, "Book overflows X at %s" % str(vp_size))
		assert(book_rect.position.y >= 0.0 and book_rect.end.y <= float(vp_size.y) + 1.0, "Book overflows Y at %s" % str(vp_size))
		var spine_x: float = book_rect.get_center().x
		assert(left_rect.end.x < spine_x - 10.0, "Left page must stay clear of center spine")
		assert(right_rect.position.x > spine_x + 10.0, "Right page must stay clear of center spine")
		assert(left_rect.position.x > book_rect.position.x + 12.0, "Left page must stay inside brown border")
		assert(right_rect.end.x < book_rect.end.x - 12.0, "Right page must stay inside brown border")
	root.content_scale_size = orig_scale_size
	notes.close_book()
	assert(not notes.is_book_open())

	# Verify study_desk.tscn also uses study_notes_book.png with nearest filtering
	var desk_scene := load("res://scenes/interaction/desktop/study/study_desk.tscn") as PackedScene
	var desk := desk_scene.instantiate()
	var book_tex := desk.get_node("Padding/Center/Notebook/BookTexture") as TextureRect
	assert(book_tex.texture.resource_path == "res://assets/textures/ui/study_notes_book.png")
	assert(book_tex.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	desk.free()

	# 3. Verify [Tab] hint & Tab toggle inside LMS Assessment (Tugas), LMS Exam, and Class Exam
	var assess_script: Script = load("res://scripts/academic/assessment.gd")
	var assess: CanvasLayer = assess_script.new()
	assess.term = 1
	assess.study_week = 1
	assess.kind = "tugas"
	root.add_child(assess)
	await _frames(3)
	var hint_btn := assess.content.find_child("NotesHintButton", true, false) as Button
	assert(hint_btn != null and "[Tab]" in hint_btn.text, "Assessment must show [Tab] Buka Catatan hint")
	var tab_ev := InputEventKey.new()
	tab_ev.keycode = KEY_TAB
	tab_ev.pressed = true
	assess._window_input(tab_ev)
	await _frames(2)
	assert(notes.is_book_open(), "Pressing Tab inside Assessment must open StudyNotes book")
	notes._input(tab_ev)
	await _frames(2)
	assert(not notes.is_book_open(), "Pressing Tab again must close StudyNotes book")
	assess.close()
	await _frames(2)

	var lms_exam_scene := (load("res://scenes/interaction/desktop/lms/lms_exam.tscn") as PackedScene).instantiate()
	assert("[Tab]" in lms_exam_scene.get_node("%Peek").text)
	lms_exam_scene.free()

	var class_exam_scene := (load("res://scenes/interaction/classroom/class_exam.tscn") as PackedScene).instantiate()
	assert("[Tab]" in class_exam_scene.get_node("%NotesHint").text)
	class_exam_scene.free()

	# 4. Verify concise answer-matched notes across ALL Sem 1 & Sem 2 lesson units + dinosaur notes
	var sem1_corpus := ""
	var sem2_corpus := ""
	for sem: int in [1, 2]:
		for day: int in [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]:
			var l: Dictionary = Curriculum.lesson(sem, day)
			var secs: Array = l.sections
			assert(secs.size() == 3)
			for s: String in secs:
				assert(s.begins_with("• "), "Note section must be concise bullet: " + s)
				assert(not s.begins_with("Penerapan:") and not s.begins_with("Keselamatan & Praktik:"))
				if sem == 1:
					sem1_corpus += " " + s.to_lower()
				else:
					sem2_corpus += " " + s.to_lower()

	for token: String in ["pesawat sederhana", "titik tumpu", "gesekan", "roda beralur", "makin landai", "1/2", "0,5", "50%", "motor", "roda gigi", "bantalan", "getaran berlebih"]:
		assert(token in sem1_corpus, "Semester 1 study notes missing required quiz concept: " + token)
	for token: String in ["pola bilangan", "baji", "sekrup", "roda-poros", "poros", "mesin majemuk", "1 m = 100 cm", "1 kg = 1000 g", "1 jam = 60 menit", "pemotong pizza", "ritsleting"]:
		assert(token in sem2_corpus, "Semester 2 study notes missing required quiz concept: " + token)

	assert(notes.entries.size() == 5)
	var dino_text := ""
	for n in notes.entries:
		dino_text += " " + n.notebook_text.to_lower()
	for token: String in ["triceratops", "3 tanduk", "stegosaurus", "2 baris lempeng", "jura akhir", "kapur akhir", "trias"]:
		assert(token in dino_text, "Dinosaur study notes missing answer fact: " + token)

	print("PASS: pixel open-book StudyNotes UI, clean HUD pixel icons, [Tab] quiz/exam hints & toggle, and 100% answer-matched concise notes")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
