extends "res://scripts/ui/activity_panel.gd"

const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _ready() -> void:
	super._ready()
	window.title = "Ruang Dosen · Evaluasi Proyek & KHS"
	_refresh()


func _refresh() -> void:
	clear()
	label("Dosen Teknik · Ringkasan Proyek & Nilai", 26)
	label("Setiap semester memiliki dua Blueprint di Bengkel: Blueprint Midterm (15%, tenggat Hari 6) dan Blueprint Final (15%, tenggat Hari 12).", 16)
	for term: int in range(1, Curriculum.SEMESTER_COUNT + 1):
		var breakdown := CareerProgress.semester_breakdown(term)
		label("Semester %d · %s" % [term, Curriculum.course_title(term)], 20)
		for info: Dictionary in Curriculum.blueprints_for_semester(term):
			var bp_id := str(info.blueprint_id)
			var status := (
				"Selesai tepat waktu (+15%)"
				if CareerProgress.is_blueprint_completed_on_time(bp_id)
				else ("Tenggat lewat (0%)" if CareerProgress.is_blueprint_overdue(bp_id) else "Belum selesai di Bengkel")
			)
			label("  • %s — %s (%s): %s" % [str(info.slot_label), str(info.title), CareerProgress.blueprint_deadline_text(bp_id), status], 16)
		label("  Estimasi Nilai Sem %d: %.1f / 100 (%s · IPS %.2f)" % [term, breakdown.final_score, breakdown.letter_grade, breakdown.ips], 16)
	label("IPK Resmi Saat Ini: %.2f" % PlayerStats.get_gpa(), 20)
	add_close()
