extends VBoxContainer

const POPUP_SCENE := preload("res://scenes/interaction/blueprint/blueprint_popup.tscn")

var _lesson_index: int = 0
var _answers: Array[Button] = []
var _popup: Window


func _ready() -> void:
	_popup = POPUP_SCENE.instantiate()
	add_child(_popup)
	%OpenBlueprint.pressed.connect(_popup.open)
	_popup.visibility_changed.connect(_restore_focus)
	%Lessons.item_selected.connect(_show_lesson)
	BlueprintProgress.changed.connect(_refresh)
	for lesson: Resource in BlueprintProgress.PROJECT.lessons:
		%Lessons.add_item(lesson.title)
	_show_lesson(0)
	_refresh()


func _restore_focus() -> void:
	if not _popup.visible and is_visible_in_tree():
		%OpenBlueprint.grab_focus()


func _show_lesson(index: int) -> void:
	_lesson_index = index
	var lesson := BlueprintProgress.PROJECT.lessons[index]
	%Material.text = lesson.material
	%Question.text = lesson.question
	for answer: Button in _answers:
		%Answers.remove_child(answer)
		answer.queue_free()
	_answers.clear()
	for option: int in lesson.options.size():
		var answer := Button.new()
		answer.text = lesson.options[option]
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.pressed.connect(_answer.bind(option))
		%Answers.add_child(answer)
		_answers.append(answer)
	_refresh()


func _answer(option: int) -> void:
	var lesson := BlueprintProgress.PROJECT.lessons[_lesson_index]
	if option != lesson.correct_option:
		%Feedback.text = "Belum tepat. Baca kembali materi, lalu coba lagi."
		return
	var error := BlueprintProgress.complete_study(lesson.id)
	if error != OK:
		%Feedback.text = "Progres belum tersimpan. Coba lagi. " + error_string(error)


func _refresh() -> void:
	var learned := BlueprintProgress.has_piece(_lesson_index)
	%Feedback.text = "Materi selesai. Potongan tersedia di popup blueprint." if learned else "Jawab pertanyaan untuk mendapatkan satu potongan."
	for answer: Button in _answers:
		answer.disabled = learned
	%Summary.text = "%s · %d / %d terpasang" % [BlueprintProgress.PROJECT.title, BlueprintProgress.get_placed_count(), BlueprintProgress.PROJECT.lessons.size()]
