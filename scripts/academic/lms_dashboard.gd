extends VBoxContainer

const Assessment = preload("res://scripts/academic/assessment.gd")

var _last_week: int = -1
var _panel: CanvasLayer


func _ready() -> void:
	CareerProgress.changed.connect(_rebuild)
	GameClock.minute_changed.connect(_clock_changed)
	_rebuild()


func _clock_changed(_minutes: int) -> void:
	if _last_week != GameClock.get_day():
		_rebuild()


func _rebuild() -> void:
	_last_week = GameClock.get_day()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var term := CareerProgress.semester()
	var week := CareerProgress.week()
	_label("Universitas Redline · LMS", 28)
	_label("%s · Semester %d · Minggu %d · IPK %.2f" % [PlayerStats.player_name, term, week, PlayerStats.get_gpa()], 20)
	_label(CareerProgress.Curriculum.COURSES[term - 1][1], 20)
	var overdue := GameClock.get_absolute_minutes() % (7 * 1440) >= 6 * 1440
	for kind: String in ["tugas", "kuis"]:
		var id := CareerProgress.result_id(term, week, kind)
		var done: bool = CareerProgress.state.results.has(id)
		var action := Button.new()
		action.text = "%s · %s" % [kind.to_upper(), "Lihat nilai" if done else ("Tenggat lewat" if overdue else "10 soal · " + ("tanpa timer" if kind == "tugas" else "10 menit nyata"))]
		action.disabled = overdue and not done
		action.pressed.connect(_open.bind(term, week, kind))
		add_child(action)
	_label("Tugas dan kuis berganti setiap minggu. Batas pengumpulan 6 hari; kegiatan yang terlewat bernilai 0.", 16)
	_label("Riwayat nilai", 24)
	var keys: Array = CareerProgress.state.results.keys()
	keys.sort()
	for id: String in keys:
		_label("%s · %.0f/100" % [id.replace("_", " · "), CareerProgress.state.results[id]], 18)
	if keys.is_empty():
		_label("Belum ada nilai tersimpan.", 18)


func _label(value: String, font_size: int) -> void:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	add_child(item)


func _open(term: int, week: int, kind: String) -> void:
	if is_instance_valid(_panel):
		return
	_panel = Assessment.new()
	_panel.term = term
	_panel.study_week = week
	_panel.kind = kind
	add_child(_panel)
