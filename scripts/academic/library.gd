extends VBoxContainer

const Curriculum = preload("res://scripts/academic/curriculum.gd")
const SECTION_NAMES := ["Materi", "Penerapan", "Keselamatan"]

var _list: OptionButton
var _material: Label
var _cost: Label
var _keyword: LineEdit
var _study_button: Button
var _feedback: Label
var _books: Array[Vector2i] = []
var _week := 0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var title := _label("Lengkapi catatan kelas")
	title.theme_type_variation = &"LmsSubheading"
	_list = OptionButton.new()
	_list.fit_to_longest_item = false
	_list.item_selected.connect(_read)
	add_child(_list)
	_material = _label("")
	_cost = _label("")
	_keyword = LineEdit.new()
	_keyword.placeholder_text = "Kata kunci dari bacaan"
	_keyword.max_length = 64
	_keyword.text_submitted.connect(func(_value: String) -> void: _study())
	add_child(_keyword)
	_study_button = Button.new()
	_study_button.text = "Lengkapi catatan"
	_study_button.theme_type_variation = &"LmsPrimaryButton"
	_study_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_study_button.pressed.connect(_study)
	add_child(_study_button)
	_feedback = _label("")
	CareerProgress.changed.connect(_refresh)
	GameClock.minute_changed.connect(_on_minute_changed)
	_refresh()


func _label(value: String) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(item)
	return item


func _on_minute_changed(_minutes: int) -> void:
	if _week != GameClock.get_day():
		_refresh()


func _refresh() -> void:
	_week = GameClock.get_day()
	var previous := Vector2i.ZERO
	if _list.selected >= 0:
		previous = _books[_list.selected]
	_list.clear()
	_books.clear()
	var selection := 0
	for term: int in range(CareerProgress.semester(), 0, -1):
		for day_num: int in range(Curriculum.DAYS_PER_SEMESTER, 0, -1):
			if CareerProgress.review_details(term, day_num).is_empty():
				continue
			var entry := Vector2i(term, day_num)
			if entry == previous:
				selection = _books.size()
			_books.append(entry)
			_list.add_item("Sem %d · Hari %d · %s" % [term, day_num, Curriculum.lesson(term, day_num).title])
	_list.disabled = _books.is_empty()
	if _books.is_empty():
		_material.text = "Materi kelas tersedia setelah kelas selesai atau harinya berlalu."
		_cost.hide()
		_keyword.hide()
		_study_button.hide()
	else:
		_list.select(selection)
		_read(selection, previous != _books[selection])


func _read(index: int, reset_input := true) -> void:
	var book := _books[index]
	var lesson := Curriculum.lesson(book.x, book.y)
	var details := CareerProgress.review_details(book.x, book.y)
	var missing: PackedInt32Array = details.missing
	var sections := PackedStringArray()
	for section: int in missing:
		sections.append("%s: %s" % [SECTION_NAMES[section], lesson.sections[section]])
	if missing.is_empty():
		_material.text = "Catatan sudah lengkap.\n\n" + "\n\n".join(lesson.sections)
	else:
		_material.text = "Bagian yang belum tercatat\n\n%s\n\nKata kunci: %s" % ["\n\n".join(sections), lesson.keyword]
	_cost.text = "Waktu belajar: semalam, hingga besok pukul 06.00." if details.overnight else "Waktu belajar: %d menit dalam game." % details.minutes
	_cost.show()
	_keyword.visible = not missing.is_empty()
	_study_button.visible = not missing.is_empty()
	if reset_input:
		_keyword.clear()
		_feedback.text = ""


func _study() -> void:
	if _list.selected < 0 or not _study_button.visible:
		return
	var book := _books[_list.selected]
	var error := CareerProgress.review_class(book.x, book.y, _keyword.text)
	match error:
		OK:
			_keyword.clear()
			_feedback.text = "Catatan dilengkapi."
		ERR_UNAUTHORIZED:
			_feedback.text = "Periksa kata kunci atau selesaikan kegiatan yang sedang berjalan."
		_:
			_feedback.text = "Catatan belum tersimpan. Coba simpan kembali."
