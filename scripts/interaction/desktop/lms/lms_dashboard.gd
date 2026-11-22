extends VBoxContainer

signal exam_mode_changed(active: bool)

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")
const Exam = preload("res://scripts/interaction/desktop/lms/lms_exam.gd")
const AttachmentForm = preload("res://scripts/interaction/desktop/lms/lms_attachment_form.gd")
const EXAM_SCENE := preload("res://scenes/interaction/desktop/lms/lms_exam.tscn")
const ATTACHMENT_SCENE := preload("res://scenes/interaction/desktop/lms/lms_attachment_form.tscn")
const Chapter = preload("res://scripts/interaction/desktop/lms/lms_chapter.gd")

@export var university_name: String = "The University"
@export var chapters: Array[Chapter]
## Used to identify results from older builds.
@export var legacy_assignments: Array[Assignment]
@export var attachment_assignments: Array[Assignment]
@export_range(0.0, 10.0, 0.1, "or_greater") var exam_loading_seconds: float = 1.0

var _exam: Exam
var _exam_instance_id: int = 0
var _next_deadline: int = -1
var _cards: Array[VBoxContainer] = []
var _history: VBoxContainer
var _focus_targets: Dictionary[String, Control] = {}
var _attachment_form: AttachmentForm
var _attachment_provider: Callable
var _exam_host: Control

@onready var _profile: Control = %Profile


func _ready() -> void:
	%UniversityName.text = university_name
	_profile.draw.connect(_draw_profile)
	GameClock.resume_timeline()
	for title: String in ["Kotak Tugas", "Kotak Kuis", "Submitted"]:
		_create_section(title)
	_history = _cards[2]
	if not attachment_assignments.is_empty():
		_create_section("Attachment assignment")
	GameClock.minute_changed.connect(_on_minute_changed)
	_rebuild_groups()


func _exit_tree() -> void:
	_release_exam()


func set_attachment_provider(provider: Callable) -> void:
	_attachment_provider = provider


func set_exam_host(host: Control) -> void:
	_exam_host = host


func _draw_profile() -> void:
	var center := _profile.size * 0.5
	var ink := _profile.get_theme_color("font_color", "LmsMeta")
	_profile.draw_circle(center, 17.0, Color(0.93, 0.93, 0.94), true, -1.0, true)
	_profile.draw_circle(center + Vector2(0, -5), 4.0, ink, true, -1.0, true)
	_profile.draw_arc(center + Vector2(0, 8), 6.0, PI, TAU, 16, ink, 3.0, true)


func _create_section(title: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"LmsSection"
	%Sections.add_child(panel)
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	panel.add_child(section)
	var heading := Label.new()
	heading.theme_type_variation = &"LmsSubheading"
	heading.text = title
	section.add_child(heading)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	section.add_child(cards)
	_cards.append(cards)


func _on_minute_changed(absolute_minutes: int) -> void:
	if _next_deadline >= 0 and absolute_minutes >= _next_deadline:
		var focused_id: Variant = _focus_targets.find_key(get_viewport().gui_get_focus_owner())
		_rebuild_groups()
		if focused_id is String:
			_focus_assignment(focused_id)


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _rebuild_groups() -> void:
	_focus_targets.clear()
	_next_deadline = -1
	for cards: VBoxContainer in _cards:
		_clear(cards)

	_add_track(_cards[0], 0, "Tugas", 0.0)
	_add_track(_cards[1], 1, "Kuis", 600.0)
	if _cards.size() > 3:
		for assignment: Assignment in attachment_assignments:
			if assignment != null and assignment.kind == Assignment.Kind.ATTACHMENT:
				_add_card(_cards[3], assignment, Results.read_result(assignment.id))
	_rebuild_history()


func _schedule_refresh(minute: int, now: int) -> void:
	if minute > now and (_next_deadline < 0 or minute < _next_deadline):
		_next_deadline = minute


func _add_track(container: VBoxContainer, track: int, track_name: String, duration: float) -> void:
	var now := GameClock.get_absolute_minutes()
	var active: Assignment
	var chapter_name := ""
	for chapter: Chapter in chapters:
		if chapter == null:
			continue
		var items := chapter.tugas if track == 0 else chapter.kuis
		for item: Assignment in items:
			if item == null or item.kind != Assignment.Kind.QUIZ or item.questions.size() != 10:
				continue
			var release := item.get_release_minutes()
			var deadline := item.get_chapter_deadline()
			_schedule_refresh(release, now)
			_schedule_refresh(deadline, now)
			if release <= now and now < deadline and (active == null or release < active.get_release_minutes()):
				active = item
				chapter_name = chapter.title
	if active == null:
		_add_label(container, "No item currently available.")
		return
	_add_label(container, chapter_name)
	_add_card(container, active, Results.read_result(active.id), track_name, duration, chapter_name)


func _add_label(container: Control, message: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"LmsMeta"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	container.add_child(label)


func _rebuild_history() -> void:
	var catalog: Dictionary[String, PackedStringArray] = {}
	for chapter: Chapter in chapters:
		if chapter == null:
			continue
		for item: Assignment in chapter.tugas:
			if item != null:
				catalog[item.id] = PackedStringArray([item.title, chapter.title, "Tugas"])
		for item: Assignment in chapter.kuis:
			if item != null:
				catalog[item.id] = PackedStringArray([item.title, chapter.title, "Kuis"])
	var attachment_ids := PackedStringArray()
	for item: Assignment in legacy_assignments + attachment_assignments:
		if item == null:
			continue
		if item.kind == Assignment.Kind.ATTACHMENT:
			attachment_ids.append(item.id)
		else:
			catalog[item.id] = PackedStringArray([item.title, "Legacy", "Kuis"])
	for id: String in Results.result_ids():
		var result := Results.read_result(id)
		if result.is_empty() or id in attachment_ids or result.has("attachment_filename"):
			continue
		var item: PackedStringArray = catalog.get(id, PackedStringArray([id, "Legacy", "Kuis"]))
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"LmsCard"
		_history.add_child(panel)
		var layout := VBoxContainer.new()
		panel.add_child(layout)
		_add_label(layout, result.get("item_title", item[0]))
		_add_label(layout, "%s · %s · %d / %d" % [result.get("chapter", item[1]), result.get("track", item[2]), result.score, result.max_score])
	if _history.get_child_count() == 0:
		_add_label(_history, "No grades yet.")


func _add_card(cards: VBoxContainer, assignment: Assignment, result: Dictionary, track_name: String = "", duration: float = 0.0, chapter_name: String = "") -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"LmsCard"
	cards.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var title := Label.new()
	title.text = assignment.title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(title)

	var caption := Label.new()
	caption.theme_type_variation = &"LmsMeta"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(caption)
	if not result.is_empty():
		caption.theme_type_variation = &"LmsResult"
		if assignment.kind == Assignment.Kind.ATTACHMENT or result.has("attachment_filename"):
			caption.text = "Attachment submitted"
		else:
			caption.text = "Submitted"
		caption.focus_mode = Control.FOCUS_ALL
		_focus_targets[assignment.id] = caption
		return

	caption.text = "No deadline"
	if not track_name.is_empty():
		var deadline := assignment.get_chapter_deadline()
		var minute_of_day := deadline % 1440
		@warning_ignore("integer_division")
		caption.text = "Due Day %d · %02d:%02d" % [deadline / 1440 + 1, minute_of_day / 60, minute_of_day % 60]
	elif assignment.deadline_day > 0:
		caption.text = "Day %d Â· %02d:%02d" % [assignment.deadline_day, assignment.deadline_hour, assignment.deadline_minute]
	var start := Button.new()
	start.text = "Open assignment" if assignment.kind == Assignment.Kind.ATTACHMENT else "Start " + track_name
	start.accessibility_name = start.text + " " + assignment.title
	start.theme_type_variation = &"LmsPrimaryButton"
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start.pressed.connect(_open_assignment.bind(assignment, track_name, duration, chapter_name))
	row.add_child(start)
	_focus_targets[assignment.id] = start


func _open_assignment(assignment: Assignment, track_name: String, duration: float, chapter_name: String) -> void:
	if _exam_instance_id != 0 or is_instance_valid(_attachment_form):
		return
	if not Results.read_result(assignment.id).is_empty():
		_rebuild_groups()
		return

	if assignment.kind == Assignment.Kind.ATTACHMENT:
		_attachment_form = ATTACHMENT_SCENE.instantiate() as AttachmentForm
		_attachment_form.assignment = assignment
		_attachment_form.attachment_provider = _attachment_provider
		_attachment_form.closed.connect(_close_attachment_form.bind(assignment.id))
		%Sections.hide()
		add_child(_attachment_form)
		return

	if duration > 0.0 and GameClock.is_activity_running():
		return
	var now := GameClock.get_absolute_minutes()
	if now < assignment.get_release_minutes() or now >= assignment.get_chapter_deadline():
		_rebuild_groups()
		return
	_exam = EXAM_SCENE.instantiate() as Exam
	_exam_instance_id = _exam.get_instance_id()
	_exam.assignment = assignment
	_exam.university_name = university_name
	_exam.loading_seconds = exam_loading_seconds
	_exam.countdown_seconds = duration
	_exam.deadline_minutes = assignment.get_chapter_deadline()
	_exam.track_name = track_name
	_exam.chapter_name = chapter_name
	_exam.submitted.connect(_end_exam.bind(assignment.id))
	_exam.abandoned.connect(_end_exam.bind(assignment.id))
	_exam.tree_exited.connect(_on_exam_removed.bind(_exam_instance_id, assignment.id), CONNECT_DEFERRED)
	exam_mode_changed.emit(true)
	var host: Node = _exam_host if is_instance_valid(_exam_host) else get_viewport()
	host.add_child(_exam)


func _close_attachment_form(assignment_id: String) -> void:
	remove_child(_attachment_form)
	_attachment_form.queue_free()
	_attachment_form = null
	%Sections.show()
	_rebuild_groups()
	_focus_assignment(assignment_id)


func _on_exam_removed(instance_id: int, assignment_id: String) -> void:
	if is_inside_tree() and _exam_instance_id == instance_id:
		_end_exam(assignment_id)


func _end_exam(assignment_id: String) -> void:
	_release_exam()
	if not is_inside_tree():
		return
	_rebuild_groups()
	_focus_assignment(assignment_id)


func _release_exam() -> void:
	if _exam_instance_id == 0:
		return
	_exam_instance_id = 0
	if is_instance_valid(_exam):
		_exam.hide()
		_exam.queue_free()
	_exam = null
	exam_mode_changed.emit(false)


func _focus_assignment(assignment_id: String) -> void:
	var target: Control = _focus_targets.get(assignment_id)
	if is_instance_valid(target) and target.is_visible_in_tree():
		target.grab_focus()
