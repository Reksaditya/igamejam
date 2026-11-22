extends "res://scripts/ui/activity_panel.gd"


func _ready() -> void:
	super._ready()
	window.title = "Ruang Dosen · Pengumpulan Proyek"
	_refresh()


func _refresh() -> void:
	clear()
	label("Dosen · Penilaian proyek", 28)
	label("Kumpulkan mesin yang telah dirakit. Nilai mempertimbangkan kelengkapan enam komponen dan percobaan sambungan. Setiap kegagalan QTE mengurangi 5 poin, maksimal 40 poin.", 18)
	for term: int in range(1, CareerProgress.semester() + 1):
		var id := CareerProgress.result_id(term, 16, "project")
		if CareerProgress.state.results.has(id):
			label("Semester %d · Nilai proyek %.0f/100" % [term, CareerProgress.state.results[id]])
		else:
			var count: int = CareerProgress.state.assembled.get(str(term), []).size()
			var action := button("Kumpulkan proyek semester %d · %d/6 komponen" % [term, count], _submit.bind(term))
			action.disabled = count != 6
	label("IPK saat ini: %.2f" % PlayerStats.get_gpa())
	add_close()


func _submit(term: int) -> void:
	var error := CareerProgress.submit_project(term)
	if error == OK:
		_refresh()
	else:
		label("Proyek belum dapat dikumpulkan. Periksa kelengkapan atau coba kembali.", 16)
