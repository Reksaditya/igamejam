extends Control

signal submitted
signal abandoned

const Assignment = preload("res://scripts/interaction/desktop/lms/lms_assignment.gd")
const Quiz = preload("res://scripts/interaction/desktop/lms/lms_quiz.gd")
const QUIZ_SCENE := preload("res://scenes/interaction/desktop/lms/lms_quiz.tscn")
const PEEK_SECONDS := 0.18

var assignment: Assignment
var university_name: String
var loading_seconds: float
var countdown_seconds: float
var deadline_minutes: int = -1
var track_name := "Kuis"
var chapter_name := ""
var _countdown_end: int = -1
var _clock_token := 0
var _expired := false
var _notebook_fade: Tween
var _finished: bool = false
var _quiz: Quiz
var _quiz_focus: Control
var _peeking: bool = false
var _sliding: bool = false

@onready var _screen: PanelContainer = $Screen
@onready var _content: VBoxContainer = %Content
@onready var _timer: Timer = $LoadingTimer
@onready var _confirm: ConfirmationDialog = %ConfirmExit
@onready var _exit: Button = %ExitQuiz
@onready var _desk: Control = $Desk
@onready var _return_to_quiz: Button = _desk.get_node("%ReturnToQuiz")


func _ready() -> void:
	if countdown_seconds > 0.0:
		_clock_token = GameClock.begin_timed_attempt(self)
		if _clock_token == 0:
			_abandon.call_deferred()
			return
	%University.text = university_name
	%LoadingAssignment.text = assignment.title
	if track_name == "Tugas":
		%LoadingTitle.text = "Memulai Tugas…"
		_exit.text = "Keluar tugas"
		_confirm.title = "Keluar dari tugas?"
	_confirm.get_cancel_button().text = "Batal"
	_screen.resized.connect(_fit_content)
	resized.connect(_fit_views)
	_fit_content()
	_fit_views()
	_exit.pressed.connect(_request_exit)
	_confirm.confirmed.connect(_abandon)
	_confirm.canceled.connect(_resume)
	%Peek.pressed.connect(_toggle_notebook)
	_return_to_quiz.pressed.connect(_toggle_notebook)
	var notebook_scroll: ScrollContainer = _desk.get_node("%Scroll")
	_link_notebook_focus(_return_to_quiz, notebook_scroll)
	_link_notebook_focus(notebook_scroll, _return_to_quiz)
	StudyNotes.notes_changed.connect(_on_notes_changed)
	_exit.grab_focus()
	_timer.timeout.connect(_show_quiz)
	GameClock.minute_changed.connect(_on_minute_changed)
	if loading_seconds <= 0.0:
		_show_quiz.call_deferred()
	else:
		_timer.start(loading_seconds)


func _link_notebook_focus(control: Control, neighbor: Control) -> void:
	var path := control.get_path_to(neighbor)
	control.focus_next = path
	control.focus_previous = path
	control.focus_neighbor_left = path
	control.focus_neighbor_right = path
	control.focus_neighbor_top = path
	control.focus_neighbor_bottom = path


func _fit_content() -> void:
	_content.custom_minimum_size.x = clampf(_screen.size.x - 40.0, 0.0, 640.0)


func _input(event: InputEvent) -> void:
	if not is_node_ready() or not is_instance_valid(_quiz) or _finished or _expired or _confirm.visible:
		return
	if _sliding:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		get_viewport().set_input_as_handled()
		if not event.echo:
			_toggle_notebook()
	elif _peeking and event is InputEventKey and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_toggle_notebook()


func _fit_views() -> void:
	var notebook: Control = _desk.get_node("%Notebook")
	var scroll: Control = _desk.get_node("%Scroll")
	notebook.custom_minimum_size.x = clampf(size.x - 56.0, 0.0, 640.0)
	scroll.custom_minimum_size.y = clampf(size.y - 150.0, 60.0, 260.0)


func _toggle_notebook() -> void:
	if _sliding or _finished or _expired or not is_instance_valid(_quiz) or _confirm.visible:
		return
	_sliding = true
	_peeking = not _peeking
	if _peeking:
		_quiz_focus = get_viewport().gui_get_focus_owner()
		_refresh_notebook()
		_desk.modulate.a = 0.0
		_desk.show()
		_return_to_quiz.grab_focus()
	_notebook_fade = create_tween()
	_notebook_fade.tween_property(_desk, "modulate:a", 1.0 if _peeking else 0.0, PEEK_SECONDS)
	_notebook_fade.finished.connect(_finish_fade)


func _finish_fade() -> void:
	_sliding = false
	if not _peeking:
		_desk.hide()
		if is_instance_valid(_quiz_focus) and _quiz_focus.is_visible_in_tree():
			_quiz_focus.grab_focus()
		elif is_instance_valid(_quiz):
			_quiz.focus_current_answer()


func _on_notes_changed(assignment_id: String) -> void:
	if _peeking and assignment_id == assignment.get_notebook_id():
		_refresh_notebook()


func _refresh_notebook() -> void:
	var entries: VBoxContainer = _desk.get_node("%Entries")
	for child: Node in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var unlocked := StudyNotes.get_unlocked_entries(assignment.get_notebook_id())
	if unlocked.is_empty():
		var empty := Label.new()
		empty.text = "Belum ada catatan yang terbuka."
		empty.theme_type_variation = &"LmsMeta"
		entries.add_child(empty)
		return
	for note in unlocked:
		var entry := Label.new()
		entry.text = note.notebook_text
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entries.add_child(entry)


func _show_quiz() -> void:
	if _finished or _confirm.visible or not is_inside_tree() or is_instance_valid(_quiz):
		return
	%Loading.hide()
	_quiz = QUIZ_SCENE.instantiate() as Quiz
	_quiz.assignment = assignment
	_quiz.submit_label = "Kumpulkan " + track_name
	_quiz.grade_metadata = {"item_title": assignment.title, "chapter": chapter_name, "track": track_name}
	_quiz.submitted.connect(_on_submitted)
	_quiz.tree_exited.connect(_on_quiz_removed, CONNECT_DEFERRED)
	_content.add_child(_quiz)
	%Peek.show()
	if countdown_seconds > 0.0 and not _expired:
		_countdown_end = Time.get_ticks_msec() + roundi(countdown_seconds * 1000.0)
		%Countdown.show()
		_update_countdown()


func _process(_delta: float) -> void:
	if _countdown_end >= 0 and not _finished and not _expired:
		_update_countdown()


func _update_countdown() -> void:
	var remaining := maxi(0, ceili((_countdown_end - Time.get_ticks_msec()) / 1000.0))
	@warning_ignore("integer_division")
	%Countdown.text = "Sisa waktu %02d:%02d" % [remaining / 60, remaining % 60]
	if remaining == 0:
		_expire_attempt()


func _on_minute_changed(now: int) -> void:
	if deadline_minutes >= 0 and now >= deadline_minutes:
		_expire_attempt()


func _expire_attempt() -> void:
	if _finished or _expired:
		return
	_expired = true
	_timer.stop()
	_confirm.hide()
	if _notebook_fade != null:
		_notebook_fade.kill()
	_desk.hide()
	_sliding = false
	_peeking = false
	_show_quiz()
	%Peek.hide()
	_quiz.complete_attempt()



func _request_exit() -> void:
	_confirm.popup_centered(Vector2i(360, 0))
	_confirm.get_cancel_button().grab_focus()


func _resume() -> void:
	_exit.grab_focus()
	if %Loading.visible and _timer.is_stopped():
		_show_quiz.call_deferred()


func _abandon() -> void:
	if _finished:
		return
	_finished = true
	GameClock.cancel_activity(_take_clock_token())
	abandoned.emit()


func _on_submitted(_score: int, _max_score: int) -> void:
	if _finished:
		return
	_finished = true
	GameClock.complete_timed_attempt(_take_clock_token())
	submitted.emit()


func _take_clock_token() -> int:
	var token := _clock_token
	_clock_token = 0
	return token


func _on_quiz_removed() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_abandon()
