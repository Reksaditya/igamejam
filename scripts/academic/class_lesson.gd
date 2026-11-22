extends CanvasLayer

signal closed

const Qte = preload("res://scripts/interaction/classroom/focus_qte.gd")
const ActivityPanel = preload("res://scripts/ui/activity_panel.gd")
const Curriculum = preload("res://scripts/academic/curriculum.gd")

var player: CharacterBody2D
var seat_position: Vector2
var notes_only: bool = false
var term: int = 1
var study_week: int = 1
var _qte: Control
var _teaching: Label
var _phase: int = 0
var _delay: float = 4.0
var _index: int = 0
var _class_started: bool = false
var _summary: CanvasLayer


func _ready() -> void:
	layer = 20
	if notes_only:
		_show_summary()
		return
	var error := CareerProgress.begin_activity("class", "class_" + CareerProgress.key_for(term, study_week))
	if error != OK:
		var panel := ActivityPanel.new()
		add_child(panel)
		panel.label("Energi tidak cukup atau progres belum tersimpan. Istirahat di asrama sebelum belajar.")
		panel.add_close()
		panel.closed.connect(_close)
		return
	if not GameClock.begin_class(self):
		_close()
		return
	_class_started = true
	player.position = seat_position
	player.set_studying(true)
	_qte = Qte.new()
	_qte.focus_mode = Control.FOCUS_ALL
	_qte.size = Vector2(110, 110)
	_qte.resolved.connect(_resolved)
	add_child(_qte)
	_qte.hide()
	var teaching_panel := PanelContainer.new()
	teaching_panel.theme = preload("res://scenes/ui/menu_theme.tres")
	teaching_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	teaching_panel.offset_left = 24
	teaching_panel.offset_right = -24
	teaching_panel.offset_top = -150
	teaching_panel.offset_bottom = -16
	teaching_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(teaching_panel)
	_teaching = Label.new()
	_teaching.add_theme_font_size_override("font_size", 18)
	_teaching.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_teaching.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teaching_panel.add_child(_teaching)
	_next_section()


func _next_section() -> void:
	var data := CareerProgress.class_data(term, study_week)
	while _index < 3 and data.attempted.has(_index):
		_index += 1
	if _index == 3:
		if CareerProgress.finish_class(term, study_week) != OK:
			_teaching.text = "Catatan belum tersimpan. Keluar lalu lanjutkan kelas untuk mencoba kembali."
			return
		GameClock.complete_class(self)
		_class_started = false
		_show_summary()
		return
	var lesson := Curriculum.lesson(term, study_week)
	_teaching.text = "%s\n%s" % [lesson.title, lesson.sections[_index]]
	_phase = 0
	_delay = 4.0 if data.attempted.is_empty() else randf_range(5.0, 11.0)
	_qte.hide()


func _process(delta: float) -> void:
	if not is_instance_valid(_qte) or not is_instance_valid(player) or is_instance_valid(_summary):
		return
	_qte.position = player.get_global_transform_with_canvas() * Vector2(0, -102) - Vector2(55, 110)
	if _phase == 1:
		return
	_delay -= delta
	if _delay > 0:
		return
	if _phase == 2:
		_index += 1
		_next_section()
		return
	if CareerProgress.attempt_section(term, study_week, _index) != OK:
		_index += 1
		_next_section()
		return
	_phase = 1
	_qte.show()
	_qte.start(_index, 3)
	if PlayerStats.get_energy() <= 0:
		_qte._resolve(false)


func _resolved(success: bool) -> void:
	CareerProgress.finish_section(term, study_week, _index, success)
	_phase = 2
	_delay = 1.2


func _show_summary() -> void:
	if is_instance_valid(player):
		player.set_studying(false)
	if is_instance_valid(_qte):
		_qte.hide()
		_teaching.get_parent().hide()
	_summary = ActivityPanel.new()
	add_child(_summary)
	var data := CareerProgress.class_data(term, study_week)
	var lesson := Curriculum.lesson(term, study_week)
	_summary.label("Catatan akhir · Semester %d · Minggu %d" % [term, study_week], 26)
	_summary.label(lesson.title, 24)
	for index: int in 3:
		_summary.label(lesson.sections[index] if data.complete.has(index) else "________________ (catatan kosong)")
	_summary.label("Materi yang dilewati tidak dapat diulang di kelas. Lengkapi catatan melalui Library pada komputer asrama.", 16)
	_summary.add_close()
	_summary.closed.connect(_close)


func _close() -> void:
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.set_studying(false)
	if _class_started:
		GameClock.cancel_class(self)
