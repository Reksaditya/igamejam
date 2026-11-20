extends VBoxContainer

signal exam_mode_changed(active: bool)

enum Category { DUE, OVERDUE, SUBMITTED }

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")
const Exam = preload("res://scripts/interaction/desktop/lms/lms_exam.gd")
const AttachmentForm = preload("res://scripts/interaction/desktop/lms/lms_attachment_form.gd")
const EXAM_SCENE := preload("res://scenes/interaction/desktop/lms/lms_exam.tscn")
const ATTACHMENT_SCENE := preload("res://scenes/interaction/desktop/lms/lms_attachment_form.tscn")
const CATEGORY_LABELS := ["Due", "Overdue", "Submitted"]
const EMPTY_LABELS := ["Nothing due", "Nothing overdue", "Nothing submitted"]

@export var university_name: String = "The University"
@export var assignments: Array[Assignment]
@export_range(0.0, 10.0, 0.1, "or_greater") var exam_loading_seconds: float = 1.0

var _exam: Exam
var _exam_instance_id: int = 0
var _next_deadline: int = -1
var _cards: Array[VBoxContainer] = []
var _focus_targets: Dictionary[String, Control] = {}
var _attachment_form: AttachmentForm
var _attachment_provider: Callable

@onready var _profile: Control = %Profile


func _ready() -> void:
	%UniversityName.text = university_name
	_profile.draw.connect(_draw_profile)
	for title: String in CATEGORY_LABELS:
		_create_section(title)
	GameClock.minute_changed.connect(_on_minute_changed)
	_rebuild_groups()


func _exit_tree() -> void:
	_release_exam()


func set_attachment_provider(provider: Callable) -> void:
	_attachment_provider = provider


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


func _rebuild_groups() -> void:
	_focus_targets.clear()
	_next_deadline = -1
	for cards: VBoxContainer in _cards:
		for child: Node in cards.get_children():
			cards.remove_child(child)
			child.queue_free()

	var now := GameClock.get_absolute_minutes()
	for assignment: Assignment in assignments:
		if assignment == null or (assignment.kind == Assignment.Kind.QUIZ and assignment.questions.is_empty()):
			continue
		var result := Results.read_result(assignment.id)
		var category := Category.SUBMITTED
		if result.is_empty():
			var deadline := assignment.get_deadline_minutes()
			category = Category.OVERDUE if deadline >= 0 and now >= deadline else Category.DUE
			if deadline > now and (_next_deadline < 0 or deadline < _next_deadline):
				_next_deadline = deadline
		_add_card(_cards[category], assignment, result)

	for index: int in _cards.size():
		if _cards[index].get_child_count() == 0:
			var empty := Label.new()
			empty.theme_type_variation = &"LmsMeta"
			empty.text = EMPTY_LABELS[index]
			_cards[index].add_child(empty)


func _add_card(cards: VBoxContainer, assignment: Assignment, result: Dictionary) -> void:
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
			caption.text = "Score %d / %d" % [result.score, result.max_score]
		caption.focus_mode = Control.FOCUS_ALL
		_focus_targets[assignment.id] = caption
		return

	caption.text = "No deadline"
	if assignment.deadline_day > 0:
		caption.text = "Day %d · %02d:%02d" % [assignment.deadline_day, assignment.deadline_hour, assignment.deadline_minute]
	var start := Button.new()
	start.text = "Open assignment" if assignment.kind == Assignment.Kind.ATTACHMENT else "Start quiz"
	start.accessibility_name = start.text + " " + assignment.title
	start.theme_type_variation = &"LmsPrimaryButton"
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start.pressed.connect(_open_assignment.bind(assignment))
	row.add_child(start)
	_focus_targets[assignment.id] = start


func _open_assignment(assignment: Assignment) -> void:
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

	_exam = EXAM_SCENE.instantiate() as Exam
	_exam_instance_id = _exam.get_instance_id()
	_exam.assignment = assignment
	_exam.university_name = university_name
	_exam.loading_seconds = exam_loading_seconds
	_exam.submitted.connect(_end_exam.bind(assignment.id))
	_exam.abandoned.connect(_end_exam.bind(assignment.id))
	_exam.tree_exited.connect(_on_exam_removed.bind(_exam_instance_id, assignment.id), CONNECT_DEFERRED)
	exam_mode_changed.emit(true)
	get_viewport().add_child(_exam)


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
