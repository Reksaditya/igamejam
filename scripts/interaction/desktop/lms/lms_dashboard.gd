extends VBoxContainer

signal exam_mode_changed(active: bool)

const Assessment = preload("res://scripts/academic/assessment.gd")
const Curriculum = preload("res://scripts/academic/curriculum.gd")
const Results = preload("res://scripts/interaction/desktop/lms/lms_results.gd")

@export var university_name := "Universitas Redline"

var _cards: Array[VBoxContainer] = []
var _assessment: CanvasLayer
var _locked := false
var _term := 0
var _day := 0
var _actions: Dictionary[String, Button] = {}

@onready var _profile: Control = %Profile
@onready var _course: Label = %Course


func _ready() -> void:
	%UniversityName.text = university_name
	_profile.draw.connect(_draw_profile)
	GameClock.resume_timeline()
	for title: String in ["Paruh 1 · Midterm (Tenggat Hari 6)", "Paruh 2 · Final (Tenggat Hari 12)", "Riwayat Nilai & KHS"]:
		_create_section(title)
	GameClock.minute_changed.connect(_on_minute_changed)
	CareerProgress.changed.connect(_rebuild_groups)
	_rebuild_groups()


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
	var heading := _add_label(section, title)
	heading.theme_type_variation = &"LmsSubheading"
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	section.add_child(cards)
	_cards.append(cards)


func _on_minute_changed(_now: int) -> void:
	if _term != CareerProgress.semester() or _day != CareerProgress.day_in_semester():
		_rebuild_groups()


func _rebuild_groups() -> void:
	_term = CareerProgress.semester()
	_day = CareerProgress.day_in_semester()
	_course.text = "Semester %d · Hari %d/12 · %s" % [_term, _day, Curriculum.course_title(_term)]
	_profile.tooltip_text = PlayerStats.player_name
	_profile.accessibility_name = PlayerStats.player_name
	var focused := get_viewport().gui_get_focus_owner() as Button
	var focused_id: Variant = _actions.find_key(focused) if focused != null else null
	_actions.clear()
	for cards: VBoxContainer in _cards:
		for child: Node in cards.get_children():
			cards.remove_child(child)
			child.queue_free()

	# Paruh 1 (Hari 1-6): Tugas Paruh 1, Kuis Paruh 1, UTS (Hari 6), Blueprint Midterm (15%)
	_add_assessment_card(_cards[0], _term, 1, "tugas", "Tugas Paruh 1 (5% bobot)")
	_add_assessment_card(_cards[0], _term, 1, "kuis", "Kuis Paruh 1 (7.5% bobot)")
	_add_assessment_card(_cards[0], _term, Curriculum.MIDTERM_DAY, "uts", "Ujian Tengah Semester · UTS (22.5%)")
	_add_blueprint_status_card(_cards[0], Curriculum.blueprint_for_slot(_term, "midterm"))

	# Paruh 2 (Hari 7-12): Tugas Paruh 2, Kuis Paruh 2, UAS (Hari 12), Blueprint Final (15%)
	_add_assessment_card(_cards[1], _term, 2, "tugas", "Tugas Paruh 2 (5% bobot)")
	_add_assessment_card(_cards[1], _term, 2, "kuis", "Kuis Paruh 2 (7.5% bobot)")
	_add_assessment_card(_cards[1], _term, Curriculum.FINAL_DAY, "uas", "Ujian Akhir Semester · UAS (22.5%)")
	_add_blueprint_status_card(_cards[1], Curriculum.blueprint_for_slot(_term, "final"))

	_rebuild_history(_cards[2])
	if focused_id is String and _actions.has(focused_id) and not _actions[focused_id].disabled:
		_actions[focused_id].grab_focus()


func _add_assessment_card(container: Control, term: int, slot: int, kind: String, heading_text: String) -> void:
	var card := _add_card(container)
	var id := CareerProgress.result_id(term, slot, kind)
	var submitted: bool = CareerProgress.state.results.has(id)
	var overdue := CareerProgress.is_assessment_overdue(term, slot, kind)
	var unlocked := CareerProgress.is_assessment_unlocked(term, slot, kind)
	var deadline_str := Assessment.deadline_label(term, slot, kind)

	var detail := ""
	if submitted:
		var score: float = float(CareerProgress.state.results[id])
		detail = "%s · Terkumpul: %.0f / 100 (%s)" % [heading_text, score, CareerProgress.letter_grade_for(score)]
	elif overdue:
		detail = "%s · Tenggat lewat (%s) · Nilai 0 (E)" % [heading_text, deadline_str]
	elif not unlocked:
		var open_day := 7 if slot == 2 else (Curriculum.MIDTERM_DAY if kind == "uts" else Curriculum.FINAL_DAY)
		detail = "%s · Terbuka Sem %d Hari %d · %s" % [heading_text, term, open_day, deadline_str]
	else:
		var mode := "10 soal · Tanpa timer · -5 Energi" if kind == "tugas" else ("10 soal · 10 menit · -5 Energi" if kind == "kuis" else "10 soal · 10 menit · -30 Energi")
		detail = "%s · %s · %s" % [heading_text, mode, deadline_str]

	_add_label(card, detail)
	var action := Button.new()
	if submitted:
		action.text = "Lihat nilai"
		action.disabled = false
	elif overdue:
		action.text = "Tenggat Lewat"
		action.disabled = true
	elif not unlocked:
		action.text = "Belum Terbuka"
		action.disabled = true
	else:
		action.text = "Mulai " + kind.to_upper()
		action.disabled = false
	action.theme_type_variation = &"LmsPrimaryButton"
	action.size_flags_horizontal = Control.SIZE_SHRINK_END
	action.pressed.connect(_open.bind(term, slot, kind))
	card.add_child(action)
	_actions[id] = action


func _add_blueprint_status_card(container: Control, info: Dictionary) -> void:
	if info.is_empty():
		return
	var card := _add_card(container)
	var bp_id := str(info.blueprint_id)
	var done_on_time := CareerProgress.is_blueprint_completed_on_time(bp_id)
	var overdue := CareerProgress.is_blueprint_overdue(bp_id)
	var owned := ProjectBlueprints.is_owned(bp_id)
	var status_str := ""
	if done_on_time:
		status_str = "Selesai tepat waktu (+15%)"
	elif overdue:
		status_str = "Tenggat lewat (0%)"
	elif owned:
		status_str = "Terbuka · Rakit di Bengkel (-20 Energi)"
	else:
		status_str = "Terkunci · Selesaikan kelas atau buka buku di Perpustakaan"
	_add_label(card, "%s — %s · %s · %s" % [
		str(info.slot_label),
		str(info.title),
		CareerProgress.blueprint_deadline_text(bp_id),
		status_str,
	])


func _rebuild_history(container: Control) -> void:
	# Show live current-semester estimate + any finalized KHS snapshots.
	var evaluated: Dictionary = CareerProgress.state.get("evaluated_semesters", {})
	for t: int in range(1, Curriculum.SEMESTER_COUNT + 1):
		var key := str(t)
		if evaluated.has(key) and evaluated[key] is Dictionary:
			var khs: Dictionary = evaluated[key]
			_add_label(_add_card(container), "KHS Semester %d · Nilai %.1f (%s) · IPS %.2f · IPK %.2f" % [
				t,
				float(khs.final_score),
				str(khs.letter_grade),
				float(khs.ips),
				float(khs.get("ipk", PlayerStats.get_gpa())),
			])
	var grades: Dictionary = CareerProgress.state.results
	var ids := grades.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) > 0)
	for id: String in ids:
		var score := float(grades[id])
		_add_label(_add_card(container), "%s · %.0f / 100 (%s)" % [_history_title(id), score, CareerProgress.letter_grade_for(score)])
	for id: String in Results.result_ids():
		if grades.has(id):
			continue
		var saved := Results.read_result(id)
		if not saved.is_empty():
			var title := str(saved.get("item_title", id.replace("_", " ").capitalize()))
			_add_label(_add_card(container), "Arsip · %s · %d / %d" % [title, saved.score, saved.max_score])
	if container.get_child_count() == 0:
		_add_label(container, "Belum ada nilai tercatat.")


func _add_card(container: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"LmsCard"
	container.add_child(panel)
	var card := VBoxContainer.new()
	panel.add_child(card)
	return card


func _add_label(container: Control, message: String) -> Label:
	var item := Label.new()
	item.theme_type_variation = &"LmsMeta"
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.text = message
	container.add_child(item)
	return item


func _history_title(id: String) -> String:
	var parts := id.split("_")
	if parts.size() < 3:
		return id.capitalize()
	var sem := parts[0].trim_prefix("s").to_int()
	var slot_raw := parts[1]
	var kind := "_".join(parts.slice(2))
	if kind == "blueprint_midterm":
		return "Semester %d · Blueprint Midterm (15%%)" % sem
	if kind == "blueprint_final":
		return "Semester %d · Blueprint Final (15%%)" % sem
	if slot_raw.begins_with("h"):
		return "Semester %d · Paruh %d · %s" % [sem, slot_raw.trim_prefix("h").to_int(), kind.to_upper()]
	return "Semester %d · Hari %d · %s" % [sem, slot_raw.trim_prefix("d").to_int(), kind.to_upper()]


func _open(term: int, slot: int, kind: String) -> void:
	if is_instance_valid(_assessment):
		return
	_assessment = Assessment.new()
	_assessment.term = term
	_assessment.study_week = slot
	_assessment.kind = kind
	_assessment.lock_changed.connect(_set_locked)
	_assessment.closed.connect(_on_assessment_closed.bind(CareerProgress.result_id(term, slot, kind)))
	add_child(_assessment)


func _set_locked(active: bool) -> void:
	if active != _locked:
		_locked = active
		exam_mode_changed.emit(active)


func _on_assessment_closed(id: String) -> void:
	_set_locked(false)
	var action := _actions.get(id) as Button
	if is_instance_valid(action) and not action.disabled and action.is_visible_in_tree():
		action.grab_focus.call_deferred()
