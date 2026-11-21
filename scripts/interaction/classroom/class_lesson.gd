extends CanvasLayer

signal closed

enum Phase { WAITING, FOCUS, FEEDBACK, NOTES }

const BLUEPRINT_SCENE := preload("res://scenes/interaction/blueprint/blueprint_popup.tscn")

@export_range(2.0, 10.0, 0.5) var first_qte_delay: float = 4.0
@export_range(2.0, 30.0, 0.5) var minimum_qte_delay: float = 5.0
@export_range(2.0, 30.0, 0.5) var maximum_qte_delay: float = 11.0

var player: CharacterBody2D
var seat_position: Vector2
var notes_only: bool = false
var _phase: Phase = Phase.WAITING
var _indices := PackedInt32Array()
var _segment: int = 0
var _remaining: float = 0.0
var _was_paused: bool = false
var _owns_pause: bool = false
var _popup: Window
var _desktop_button: Button
var _desktop_was_disabled: bool = false
var _save_error: bool = false


func _ready() -> void:
	_popup = BLUEPRINT_SCENE.instantiate()
	add_child(_popup)
	%Close.pressed.connect(_close)
	%Blueprint.pressed.connect(_open_blueprint)
	%Qte.resolved.connect(_on_qte_resolved)
	%Screen.hide()
	%Qte.hide()
	%StudyHud.hide()
	if notes_only:
		_show_notes()
		return
	if not is_instance_valid(player):
		_close()
		return
	_desktop_button = player.get_parent().get_node_or_null("DesktopAccess/OpenDesktop") as Button
	if _desktop_button != null:
		_desktop_was_disabled = _desktop_button.disabled
		_desktop_button.disabled = true
	player.position = seat_position
	player.set_studying(true)
	player.get_node("Camera2D").reset_smoothing()
	_indices = ClassroomProgress.get_unattempted_indices()
	%StudyHud.show()
	_next_segment()


func _exit_tree() -> void:
	_restore_player()
	if _owns_pause:
		get_tree().paused = _was_paused


func _process(delta: float) -> void:
	_position_qte()
	if _phase != Phase.WAITING and _phase != Phase.FEEDBACK:
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	if _phase == Phase.WAITING:
		_start_qte()
	else:
		_segment += 1
		_next_segment()


func _next_segment() -> void:
	%Qte.hide()
	if _segment >= _indices.size():
		_show_notes()
		return
	var lesson := BlueprintProgress.PROJECT.lessons[_indices[_segment]]
	%Teaching.text = lesson.title + "\n" + lesson.material
	%StudyStatus.text = "Sedang belajar · Tekan Space saat penanda QTE berada di zona hijau."
	_phase = Phase.WAITING
	_remaining = first_qte_delay if _segment == 0 else randf_range(minimum_qte_delay, maxf(minimum_qte_delay, maximum_qte_delay))


func _start_qte() -> void:
	var error := ClassroomProgress.begin_material(_indices[_segment])
	if error != OK:
		_save_error = true
		_show_notes()
		return
	_phase = Phase.FOCUS
	%Qte.show()
	_position_qte()
	%Qte.start(_indices[_segment], BlueprintProgress.PROJECT.lessons.size())


func _position_qte() -> void:
	if not is_instance_valid(player):
		return
	var head := player.get_global_transform_with_canvas() * Vector2(0, -76)
	%Qte.position = head - Vector2(%Qte.size.x * 0.5, %Qte.size.y + 12.0)


func _on_qte_resolved(success: bool) -> void:
	if _phase != Phase.FOCUS:
		return
	_phase = Phase.FEEDBACK
	_remaining = 1.2
	var error := ClassroomProgress.finish_material(_indices[_segment], success)
	_save_error = _save_error or error != OK
	%StudyStatus.text = "Fokus terjaga." if success else "Fokus terputus."


func _refresh_notes() -> void:
	var lines := PackedStringArray()
	for index: int in BlueprintProgress.PROJECT.lessons.size():
		var lesson := BlueprintProgress.PROJECT.lessons[index]
		lines.append("%d. %s: %s" % [index + 1, lesson.title, lesson.material if ClassroomProgress.has_note(index) else "________________ (catatan kosong)"])
	%Notes.text = "\n\n".join(lines)


func _show_notes() -> void:
	_phase = Phase.NOTES
	%Qte.hide()
	%StudyHud.hide()
	%Screen.show()
	_was_paused = get_tree().paused
	_owns_pause = true
	get_tree().paused = true
	var finished := ClassroomProgress.is_class_finished()
	%Heading.text = "Catatan akhir kelas" if finished else "Sesi pembelajaran terhenti"
	%Week.text = "Minggu %d · Hari %d" % [GameClock.get_week(), GameClock.get_day()]
	var complete := ClassroomProgress.is_complete()
	%Material.text = "Catatan lengkap. Blueprint mesin kini dapat diakses." if complete else "Bagian catatan yang kosong hanya dapat dilengkapi dengan belajar lagi di asrama. Materi yang sudah dilewati tidak dapat diulang di kelas."
	if not finished:
		%Material.text = "Materi yang belum dilewati masih dapat dilanjutkan dari kursi. Catatan akhir baru tersedia setelah kelas selesai."
	%Status.text = "Penyimpanan catatan mengalami masalah. Materi yang belum dilewati masih dapat dilanjutkan dari kursi." if _save_error else ""
	%Blueprint.visible = complete
	_refresh_notes()
	%Notes.visible = finished
	if complete and ClassroomProgress.unlock_blueprint() != OK:
		%Status.text = "Blueprint belum tersimpan. Tekan Buka blueprint untuk mencoba kembali."
	%Close.grab_focus()


func _open_blueprint() -> void:
	var error := ClassroomProgress.unlock_blueprint()
	if error == OK:
		_popup.open()
	else:
		%Status.text = "Blueprint belum dapat dibuka. " + error_string(error)


func _restore_player() -> void:
	if is_instance_valid(player):
		player.set_studying(false)
	if is_instance_valid(_desktop_button):
		_desktop_button.disabled = _desktop_was_disabled


func _close() -> void:
	if _phase != Phase.NOTES and is_instance_valid(player):
		return
	_restore_player()
	if _owns_pause:
		get_tree().paused = _was_paused
		_owns_pause = false
	closed.emit()
	queue_free()
