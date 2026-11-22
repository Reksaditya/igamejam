extends VBoxContainer

const Curriculum = preload("res://scripts/academic/curriculum.gd")

var _list: OptionButton
var _material: Label
var _keyword: LineEdit
var _feedback: Label
var _books: Array[Vector2i] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Library · Buku dan catatan perkuliahan"
	add_child(title)
	_list = OptionButton.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	for term: int in range(1, CareerProgress.semester() + 1):
		for week: int in range(1, 17):
			var absolute_week := (term - 1) * 16 + week
			if week in [8, 16] or absolute_week > GameClock.get_week():
				continue
			if absolute_week == GameClock.get_week() and not CareerProgress.class_data(term, week).finished:
				continue
			_books.append(Vector2i(term, week))
			_list.add_item("S%d · M%d · %s" % [term, week, Curriculum.lesson(term, week).title])
	_material = Label.new()
	_material.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_material)
	_keyword = LineEdit.new()
	_keyword.placeholder_text = "Tuliskan keyword dari bacaan"
	_keyword.max_length = 64
	add_child(_keyword)
	var study := Button.new()
	study.text = "Lengkapi catatan dan pelajari potongan blueprint"
	study.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	study.pressed.connect(_study)
	add_child(study)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)
	_list.item_selected.connect(_read)
	study.disabled = _books.is_empty()
	_keyword.editable = not _books.is_empty()
	if _books.is_empty():
		_material.text = "Belum ada materi terdahulu. Ikuti kelas terlebih dahulu. Buku minggu yang terlewat tersedia di sini."
	else:
		_read(0)


func _read(index: int) -> void:
	var book := _books[index]
	var lesson := Curriculum.lesson(book.x, book.y)
	_material.text = "%s\n\n%s\n\nKeyword: %s\n\nBaca materi, lalu tuliskan keyword untuk melengkapi catatan. Belajar memerlukan 5 energi." % [lesson.title, "\n\n".join(lesson.sections), lesson.keyword]
	_keyword.clear()
	_feedback.text = ""


func _study() -> void:
	if _books.is_empty():
		return
	var book := _books[_list.selected]
	var error := CareerProgress.review_class(book.x, book.y, _keyword.text)
	_feedback.text = "Catatan telah lengkap. Potongan tersedia di aplikasi Project." if error == OK else "Periksa keyword dan energi. Belajar belum berhasil disimpan."
