extends "res://scripts/ui/activity_panel.gd"

const Vignette = preload("res://scripts/academic/story_vignette.gd")
const STORIES := {
	"intro": ["Chapter 1 · Kehidupan baru", "Tahun 2026. Kamu tiba di Bandung sebagai mahasiswa Teknik di Universitas Redline. Keluargamu telah berjuang agar kamu dapat kuliah.\n\nKamu berjanji menyelesaikan studi, memperoleh pekerjaan yang baik, dan mengajak orang tua berkeliling dunia. Ikuti kelas, pelajari mesin, dan jaga waktu istirahat."],
	"busy": ["Chapter 2 · Jadwal yang padat", "Semester tiga dimulai. Tugas, kuis, dan proyek semakin menuntut perhatian. Pesan dari rumah sering belum sempat kamu balas.\n\nKesibukan perlu diatur. Luangkan waktu untuk membaca, menyelesaikan pekerjaan, dan beristirahat. Nilai tinggi memerlukan proses yang berkelanjutan."],
	"loss": ["Chapter 3 · Kabar dari ayah", "Di pertengahan semester lima, ayah menelepon: ibu telah meninggal dunia. Kamu belum sempat memenuhi janji dan tidak dapat pulang tepat waktu untuk pemakaman.\n\nDuka membuatmu sulit berkonsentrasi. Energi menurun dan kewarasan memburuk. Kamu dapat beristirahat dan melanjutkan langkah kecil ketika siap."],
	"promise": ["Chapter 4 · Melanjutkan janji", "Semester enam datang. Kenangan tentang ibu tetap menyertai perjalananmu. Kamu memutuskan menyelesaikan kuliah dan menjaga hubungan dengan ayah.\n\nBangun kembali rutinitas yang seimbang. Rancang proyek akhir dari pengetahuan yang telah dipelajari dan laporkan hasilnya kepada dosen."]
}

var event_id: String = "intro"
var ending: bool = false


func _ready() -> void:
	super._ready()
	window.title = "Deadline · Perjalanan"
	can_close = false
	var visual := Vignette.new()
	visual.custom_minimum_size.y = 180
	visual.scene_kind = ("visit" if CareerProgress.state.ending == "happy" else CareerProgress.state.ending) if ending else event_id
	content.add_child(visual)
	if ending:
		var id: String = CareerProgress.state.ending
		label({"bad": "Bad Ending · Janji yang tertunda", "basic": "Basic Ending · Langkah pertama", "happy": "Happy Ending · Menepati janji"}[id], 28)
		label("%s · IPK akhir %.2f" % [PlayerStats.player_name, float(CareerProgress.state.flags.get("graduation_gpa", PlayerStats.get_gpa()))])
		var text := "Proyek akhir tidak berhasil diselesaikan. Perjalanan kuliah terhenti, dan janji kepada keluarga masih menunggu." if id == "bad" else ("Kamu lulus dan memperoleh pekerjaan sederhana. Bersama ayah, kamu memulai kehidupan berikutnya dengan harapan baru." if id == "basic" else "Kamu lulus dengan IPK tinggi dan memperoleh pekerjaan bergaji baik.\n\nSebelum perjalanan dimulai, kamu dan ayah berziarah ke makam ibu. Lalu kamu mengajak ayah melihat dunia, membawa kenangan tentang ibu dalam setiap langkah.")
		label(text)
		if id == "happy":
			button("Lanjutkan perjalanan bersama ayah", _happy_trip)
		else:
			button("Kembali ke Main Menu", _main_menu)
	else:
		label(STORIES[event_id][0], 28)
		label(STORIES[event_id][1])
		button("Lanjutkan", _continue)


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
	label("Janji yang kamu bawa", 28)
	label("Bersama ayah, kamu memulai perjalanan melihat dunia. Ibu tetap hadir dalam kenangan kalian.\n\nTerima kasih telah memainkan Deadline.")
	button("Kembali ke Main Menu", _main_menu)
