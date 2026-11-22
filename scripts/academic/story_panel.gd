extends "res://scripts/ui/activity_panel.gd"

const Vignette = preload("res://scripts/academic/story_vignette.gd")
const STORIES := {
	"intro": [
		"Bab 1 · Semester 1 Dimulai",
		"Tahun 2026. Kamu tiba di Bandung sebagai mahasiswa Teknik di Universitas Redline dan menempati Kamar 210.\n\nSetiap semester berlangsung 12 hari: Paruh 1 (Hari 1–6, UTS & Blueprint Midterm 15%) dan Paruh 2 (Hari 7–12, UAS & Blueprint Final 15%). Jaga Energi dan Kewarasanmu, lalu raih IPK tinggi untuk menepati janji kepada keluarga.",
	],
	"busy": [
		"Bab 2 · Paruh Kedua Semester 1",
		"UTS Semester 1 telah terlewati. Sekarang saatnya mendalami pecahan, desimal, persen, serta mesin sederhana terpadu dan menyelesaikan Blueprint Final sebelum Hari 12.\n\nAtur waktu belajar di kelas, LMS, Perpustakaan, Bengkel, dan jangan tidur melewati pukul 22.00.",
	],
	"loss": [
		"Bab 3 · Kabar dari Ayah",
		"Di pertengahan Semester 2, ayah menelepon membawa kabar duka: ibu telah tiada. Rasa kehilangan membuat konsentrasi dan tenagamu terguncang.\n\nEnergi menurun dan kewarasan meningkat. Beristirahatlah di Kamar 210 dan terus melangkah sedikit demi sedikit.",
	],
	"promise": [
		"Bab 4 · Menuntaskan Janji",
		"Paruh terakhir Semester 2 dimulai. Kenangan tentang ibu menjadi penguat untuk menyelesaikan Blueprint Final dan UAS dengan sebaik-baiknya.\n\nTuntaskan seluruh rangkaian kuliah 2 semester ini dan wujudkan janji kepada keluarga.",
	],
}

var event_id: String = "intro"
var ending: bool = false
var khs_summary: Dictionary = {}


func _ready() -> void:
	super._ready()
	window.title = "Deadline · Ringkasan Semester (KHS)" if not khs_summary.is_empty() else "Deadline · Perjalanan"
	can_close = false

	if not khs_summary.is_empty():
		_build_khs()
		return

	var visual := Vignette.new()
	visual.custom_minimum_size.y = 180
	visual.scene_kind = ("visit" if CareerProgress.state.ending == "happy" else CareerProgress.state.ending) if ending else event_id
	content.add_child(visual)
	if ending:
		var id: String = CareerProgress.state.ending
		var titles := {
			"bad": "Bad Ending · Janji yang Tertunda",
			"basic": "Basic Ending · Langkah Pertama",
			"happy": "Happy Ending · Menepati Janji",
		}
		label(titles.get(id, "Akhir Perjalanan"), 28)
		label("%s · IPK Akhir %.2f" % [PlayerStats.player_name, float(CareerProgress.state.flags.get("graduation_gpa", PlayerStats.get_gpa()))], 20)
		var text := (
			"Nilai akhir belum memenuhi syarat kelulusan (Huruf Mutu E). Perjalanan kuliah terhenti, dan janji kepada keluarga masih menunggu."
			if id == "bad"
			else (
				"Kamu lulus dengan baik dan memulai karier pertamamu bersama ayah dengan harapan baru."
				if id == "basic"
				else "Kamu lulus dengan IPK tinggi (>= 3.50) dan memperoleh pekerjaan impian.\n\nSebelum perjalanan dimulai, kamu dan ayah berziarah ke makam ibu, lalu mengajaknya melihat dunia dengan kenangan tentang ibu di setiap langkah."
			)
		)
		label(text)
		if id == "happy":
			button("Lanjutkan perjalanan bersama ayah", _happy_trip)
		else:
			button("Kembali ke Main Menu", _main_menu)
	else:
		label(STORIES[event_id][0], 28)
		label(STORIES[event_id][1])
		button("Lanjutkan", _continue)


func _build_khs() -> void:
	var term := int(khs_summary.get("semester", 1))
	var tugas := float(khs_summary.get("tugas", 0.0))
	var kuis := float(khs_summary.get("kuis", 0.0))
	var uts := float(khs_summary.get("uts", 0.0))
	var uas := float(khs_summary.get("uas", 0.0))
	var bp_mid := float(khs_summary.get("blueprint_midterm", 0.0))
	var bp_fin := float(khs_summary.get("blueprint_final", 0.0))
	var final_score := float(khs_summary.get("final_score", 0.0))
	var letter := str(khs_summary.get("letter_grade", "E"))
	var ips := float(khs_summary.get("ips", 0.0))
	var ipk := float(khs_summary.get("ipk", PlayerStats.get_gpa()))

	label("Kartu Hasil Studi (KHS) · Semester %d" % term, 26)
	label("%s · NIM %s" % [PlayerStats.player_name, PlayerStats.student_id], 16)
	label("Tugas (10%):  %.1f / 100  (+%.2f)" % [tugas, tugas * 0.10], 17)
	label("Kuis (15%):   %.1f / 100  (+%.2f)" % [kuis, kuis * 0.15], 17)
	label("UTS (22.5%):  %.1f / 100  (+%.2f)" % [uts, uts * 0.225], 17)
	label("UAS (22.5%):  %.1f / 100  (+%.2f)" % [uas, uas * 0.225], 17)
	label("Blueprint Midterm (15%):  %.0f / 100  (+%.1f)" % [bp_mid, bp_mid * 0.15], 17)
	label("Blueprint Final (15%):    %.0f / 100  (+%.1f)" % [bp_fin, bp_fin * 0.15], 17)
	label("Nilai Akhir: %.1f / 100  ·  Huruf Mutu: %s" % [final_score, letter], 22)
	label("IPS Semester %d: %.2f   |   IPK Kumulatif: %.2f" % [term, ips, ipk], 20)
	var next_caption := "Lanjut ke Semester 2 · Hari 1" if term < CareerProgress.Curriculum.SEMESTER_COUNT else "Lihat Hasil Kelulusan"
	button(next_caption, _ack_khs)


func _ack_khs() -> void:
	CareerProgress.acknowledge_khs()
	can_close = true
	close()


func open() -> void:
	super.open()
	GameClock.process_mode = Node.PROCESS_MODE_PAUSABLE


func _continue() -> void:
	var error := CareerProgress.acknowledge_story(event_id)
	if error != OK and error != ERR_ALREADY_EXISTS:
		label("Progres cerita belum tersimpan. Coba kembali.", 16)
		return
	can_close = true
	close()


func _main_menu() -> void:
	GameSave.save_now()
	GameSave._enabled = false
	_restore()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _happy_trip() -> void:
	clear()
	var visual := Vignette.new()
	visual.scene_kind = "happy"
	visual.custom_minimum_size.y = 200
	content.add_child(visual)
	label("Janji yang Kamu Bawa", 28)
	label("Bersama ayah, kamu memulai perjalanan melihat dunia. Ibu tetap hadir dalam kenangan kalian.\n\nTerima kasih telah memainkan Deadline.")
	button("Kembali ke Main Menu", _main_menu)
