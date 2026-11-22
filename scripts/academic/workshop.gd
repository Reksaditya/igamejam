extends "res://scripts/ui/activity_panel.gd"

const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _ready() -> void:
	super._ready()
	window.title = "Bengkel · Panduan Meja Rakit"
	_refresh()


func _refresh() -> void:
	clear()
	label("Bengkel · Meja Perakitan Transmisi", 26)
	label("Gunakan Meja Rakit di sebelah kanan ruangan untuk merakit Blueprint Midterm (15%) dan Blueprint Final (15%) setiap semester.", 16)
	var term := CareerProgress.semester()
	for info: Dictionary in Curriculum.blueprints_for_semester(term):
		var bp_id := str(info.blueprint_id)
		var owned := ProjectBlueprints.is_owned(bp_id)
		var done := CareerProgress.is_blueprint_completed_on_time(bp_id)
		var status := "Selesai (+15%)" if done else ("Terbuka (siap dirakit, -20 Energi)" if owned else "Terkunci (selesaikan kelas / buka Perpustakaan)")
		label("• %s — %s (%s): %s" % [str(info.slot_label), str(info.title), CareerProgress.blueprint_deadline_text(bp_id), status], 16)
	if PlayerStats.get_energy() <= 0.0:
		label("Energi habis. Istirahat dahulu di Kamar 203 sebelum merakit proyek.", 16)
	else:
		button("Buka Meja Rakit Bengkel", _open_bench)
	add_close()


func _open_bench() -> void:
	close()
	SceneTransition.change_scene("res://scenes/interaction/workshop/transmission_workshop.tscn", &"")
