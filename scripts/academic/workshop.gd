extends "res://scripts/ui/activity_panel.gd"

const Qte = preload("res://scripts/interaction/classroom/focus_qte.gd")
const MachinePreview = preload("res://scripts/academic/machine_preview.gd")
const COMPONENTS := [
	["Rangka", "Titik tumpu", "Lengan tuas", "Roda", "Katrol", "Bidang miring"],
	["Landasan", "Baji", "Sekrup", "Roda", "Poros", "Pengikat"],
	["Rangka", "Roda gigi", "Poros", "Rantai", "Sabuk", "Engkol"],
	["Rangka", "Poros", "Bantalan", "Pegas", "Baut", "Mur"],
	["Rangka", "Cam", "Pengikut", "Piston", "Katup", "Tuas majemuk"],
	["Baterai", "Kabel", "Saklar", "Lampu", "Motor", "Sensor"],
	["Rangka", "Transmisi", "Sensor", "Pengendali", "Motor", "Pelindung"],
	["Rangka", "Penggerak", "Sensor", "Pengendali", "Sumber energi", "Pelindung"]
]

var term: int = 1
var _held: int = -1
var _qte: Control
var _feedback: Label
var _term_choice: OptionButton
var _design_choices: Array[OptionButton] = []


func _ready() -> void:
	super._ready()
	term = CareerProgress.semester()
	window.title = "Bengkel · Perakitan mesin"
	_refresh()


func _refresh() -> void:
	clear()
	_design_choices.clear()
	_term_choice = OptionButton.new()
	for index: int in range(1, CareerProgress.semester() + 1):
		_term_choice.add_item("Proyek semester %d" % index, index)
	_term_choice.select(term - 1)
	_term_choice.item_selected.connect(func(index: int):
		term = index + 1
		_held = -1
		_refresh()
	)
	content.add_child(_term_choice)
	label(CareerProgress.Curriculum.COURSES[term - 1][1], 24)
	if not CareerProgress.blueprint_ready(term):
		label("Blueprint belum lengkap. Pelajari materi kelas / Library dan susun sembilan potongan di aplikasi Project.")
		add_close()
		return
	if term == 8 and not CareerProgress.state.flags.has("final_design"):
		label("Rancang mesin akhir dari komponen yang sudah dipelajari. Pilih mekanisme, masukan, dan sumber energi.")
		for options: Array in [["Engkol", "Cam", "Roda gigi"], ["Sensor", "Saklar"], ["Baterai", "Baterai dan saklar"]]:
			var choice := OptionButton.new()
			for option: String in options:
				choice.add_item(option)
			content.add_child(choice)
			_design_choices.append(choice)
		button("Simpan rancangan akhir", _save_design)
		add_close()
		return
	var built: int = CareerProgress.state.assembled.get(str(term), []).size()
	label("Komponen terpasang %d/6" % built, 24)
	var preview := MachinePreview.new()
	preview.custom_minimum_size.y = 156
	preview.count = built
	preview.components = _components()
	content.add_child(preview)
	if built == 6:
		label("Mesin telah selesai. Laporkan proyek ke dosen di ruang dosen untuk memperoleh nilai.")
		add_close()
		return
	label("Objective: ambil %s, lalu pasang pada posisi %d. Tekan Space saat penanda berada di zona hijau." % [_components()[built], built + 1])
	if term == 8:
		label("Rancangan: " + ", ".join(CareerProgress.state.flags.final_design), 18)
	var stock := GridContainer.new()
	stock.columns = 2
	content.add_child(stock)
	for index: int in range(built, 6):
		var part := Button.new()
		part.text = "Ambil · " + _components()[index]
		part.pressed.connect(_pick.bind(index))
		stock.add_child(part)
	_feedback = label("Pilih komponen dari rak.", 18)
	button("Pasang pada dudukan", _fit_component)
	_qte = Qte.new()
	_qte.custom_minimum_size = Vector2(140, 140)
	_qte.focus_mode = Control.FOCUS_ALL
	_qte.hide()
	_qte.resolved.connect(_resolved)
	content.add_child(_qte)
	add_close()


func _save_design() -> void:
	var values: Array[String] = []
	for choice: OptionButton in _design_choices:
		values.append(choice.get_item_text(choice.selected))
	if CareerProgress.set_final_design(values) == OK:
		_refresh()


func _pick(index: int) -> void:
	if is_instance_valid(_qte) and _qte._active:
		return
	_held = index
	_feedback.text = "Dipegang: " + _components()[index]


func _fit_component() -> void:
	if _qte._active:
		return
	var built: int = CareerProgress.state.assembled.get(str(term), []).size()
	if _held != built:
		_feedback.text = "Komponen belum sesuai objective. Ambil " + _components()[built] + "."
		return
	if PlayerStats.get_energy() <= 0 or CareerProgress.begin_activity("project", "project_s%d" % term) != OK:
		_feedback.text = "Energi tidak cukup. Istirahat sebelum melanjutkan proyek."
		return
	_qte.show()
	_qte.start(built, 6)
	content.get_parent().call_deferred("ensure_control_visible", _qte)


func _resolved(success: bool) -> void:
	if success:
		var error := CareerProgress.assemble_component(term, _held)
		_held = -1
		if error == OK:
			_refresh()
		else:
			_feedback.text = "Pemasangan belum tersimpan. Coba kembali."
	else:
		CareerProgress.record_project_failure(term)
		_held = -1
		_qte.hide()
		_feedback.text = "Sambungan belum berhasil. Komponen kembali ke rak; ambil dan coba lagi."


func _components() -> Array:
	if term == 8 and CareerProgress.state.flags.has("final_design"):
		var design: Array = CareerProgress.state.flags.final_design
		return ["Rangka", design[0], design[1], "Pengendali", design[2], "Pelindung"]
	return COMPONENTS[term - 1]
