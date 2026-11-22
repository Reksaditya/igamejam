extends VBoxContainer

const Book = preload("res://scripts/interaction/desktop/study/study_book.gd")
const BOOK_CARD := preload("res://scenes/interaction/desktop/study/study_book_card.tscn")

@export var books: Array[Book]

var _selected_book: Book
var _transitioning := false
var _book_focus: Control

@onready var _confirm: ConfirmationDialog = %ConfirmStudy
@onready var _black: ColorRect = %Black
@onready var _status: Label = %Status


func _ready() -> void:
	for book: Book in books:
		if book != null:
			_add_book(book)
	%Back.pressed.connect(_close_reading)
	_confirm.get_cancel_button().text = "Tidak"
	_confirm.confirmed.connect(_study)
	_confirm.canceled.connect(_clear_selection)


func _input(_event: InputEvent) -> void:
	if _transitioning:
		get_viewport().set_input_as_handled()


func _add_book(book: Book) -> void:
	var card := BOOK_CARD.instantiate()
	%Books.add_child(card)
	var title: Label = card.get_node("%BookTitle")
	var action: Button = card.get_node("%Study")
	title.text = book.title
	var type_label: Label = card.get_node("%BookType")
	type_label.text = "Ulasan" if book.reward_type == Book.Reward.REVIEW else "Blueprint"
	action.accessibility_name = "%s, buku %s" % [book.title, type_label.text]
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = book.cover_color if state == "normal" else book.cover_color.lightened(0.13)
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
		action.add_theme_stylebox_override(state, style)
	action.pressed.connect(_request_study.bind(book, action))


func _request_study(book: Book, action: Control) -> void:
	if _transitioning:
		return
	_status.hide()
	_book_focus = action
	if book.reward_type == Book.Reward.BLUEPRINT:
		var error := ProjectBlueprints.grant(book.blueprint_id)
		if error == OK:
			_open_reading(book)
			%ReadingStatus.text = "Blueprint tersedia di Proyek"
		else:
			_show_status("Gagal menyimpan blueprint. Coba buka kembali buku ini.", true)
		return
	if StudyNotes.is_book_studied(book.book_id, book.linked_note_ids):
		_open_reading(book)
		return
	_selected_book = book
	_confirm.popup_centered_clamped(Vector2i(365, 0))
	_confirm.get_cancel_button().grab_focus()


func _clear_selection() -> void:
	_selected_book = null


func _study() -> void:
	var book := _selected_book
	_clear_selection()
	if _transitioning or book == null or book.reward_type != Book.Reward.REVIEW or StudyNotes.is_book_studied(book.book_id, book.linked_note_ids):
		return
	_transitioning = true
	_black.show()
	await _fade(1.0)
	var error := StudyNotes.study_book(book.book_id, book.linked_note_ids)
	if error == OK:
		_open_reading(book)
	else:
		_show_status("Gagal menyimpan catatan. Anda dapat mencoba belajar kembali.", true)
	await _fade(0.0)
	_black.hide()
	_transitioning = false


func _open_reading(book: Book) -> void:
	%Title.hide()
	%Books.hide()
	%ReadingTitle.text = book.title
	%ReadingStatus.text = ""
	var passages: VBoxContainer = %Passages
	for child: Node in passages.get_children():
		passages.remove_child(child)
		child.queue_free()
	for line: String in book.reading_text.split("\n", false):
		var paragraph := Label.new()
		paragraph.text = line
		paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passages.add_child(paragraph)
	%Reading.show()
	%Back.grab_focus()


func _close_reading() -> void:
	%Reading.hide()
	_status.hide()
	%Title.show()
	%Books.show()
	if is_instance_valid(_book_focus):
		_book_focus.grab_focus()


func _fade(alpha: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(_black, "color:a", alpha, 0.28)
	return tween.finished


func _show_status(message: String, is_error := false) -> void:
	_status.theme_type_variation = &"LmsError" if is_error else &"LmsMeta"
	_status.text = message
	_status.show()
