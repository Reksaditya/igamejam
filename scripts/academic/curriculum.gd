extends RefCounted

const PROGRESSION = preload("res://scenes/interaction/classroom/progression_rules.tres")

const SEMESTER_COUNT := 2
const DAYS_PER_SEMESTER := 12
const MIDTERM_DAY := 6
const FINAL_DAY := 12
const TOTAL_DAYS := SEMESTER_COUNT * DAYS_PER_SEMESTER

const QUESTION_BANK_PATHS := {
	1: "res://resources/questions/semester_1_questions.json",
	2: "res://resources/questions/semester_2_questions.json",
}

## 4 Workshop Blueprints mapped 1-to-1 across the 2 semesters (15% Midterm + 15% Final = 30%/sem).
const BLUEPRINTS: Array[Dictionary] = [
	{
		"blueprint_id": "core_drive",
		"puzzle_id": "starter_drive",
		"title": "Penggerak Inti",
		"difficulty": "Mudah",
		"semester": 1,
		"half": 1,
		"slot": "midterm",
		"slot_label": "Blueprint Midterm (15%)",
		"weight": 0.15,
		"unlock_day_in_semester": 1,
		"deadline_day_in_semester": 6,
		"absolute_unlock_day": 1,
		"absolute_deadline_day": 6,
		"topic": "Dasar Mesin Sederhana (Tuas, Roda, Katrol, Bidang Miring)",
	},
	{
		"blueprint_id": "sediment_sorter",
		"puzzle_id": "transmission_bench",
		"title": "Pemilah Sedimen",
		"difficulty": "Sedang",
		"semester": 1,
		"half": 2,
		"slot": "final",
		"slot_label": "Blueprint Final (15%)",
		"weight": 0.15,
		"unlock_day_in_semester": 7,
		"deadline_day_in_semester": 12,
		"absolute_unlock_day": 7,
		"absolute_deadline_day": 12,
		"topic": "Operasi Bilangan & Mesin Sederhana Terpadu",
	},
	{
		"blueprint_id": "sieve_shaker",
		"puzzle_id": "slider_relay",
		"title": "Pengayak Getar",
		"difficulty": "Sulit",
		"semester": 2,
		"half": 1,
		"slot": "midterm",
		"slot_label": "Blueprint Midterm (15%)",
		"weight": 0.15,
		"unlock_day_in_semester": 1,
		"deadline_day_in_semester": 6,
		"absolute_unlock_day": 13,
		"absolute_deadline_day": 18,
		"topic": "Mesin Sederhana Lanjutan (Baji, Sekrup, Roda-Poros)",
	},
	{
		"blueprint_id": "core_centrifuge",
		"puzzle_id": "centrifuge_drive",
		"title": "Sentrifuga Inti",
		"difficulty": "Ahli",
		"semester": 2,
		"half": 2,
		"slot": "final",
		"slot_label": "Blueprint Final (15%)",
		"weight": 0.15,
		"unlock_day_in_semester": 7,
		"deadline_day_in_semester": 12,
		"absolute_unlock_day": 19,
		"absolute_deadline_day": 24,
		"topic": "Penggabungan Mesin Sederhana Lanjutan",
	},
]

## 2 Semesters x 10 concise answer-matched lesson units (Hari 1-5 Paruh 1 / UTS, Hari 7-11 Paruh 2 / UAS).
## Format per unit: [title, concise_section_1, keyword, concise_section_2, concise_section_3]
const COURSES := [
	[
		"Semester 1",
		"Dasar-Dasar: Operasi Bilangan & Mesin Sederhana",
		[
			# Hari 1..5 (Paruh 1 — Midterm / UTS prep)
			[
				"Penjumlahan, Pengurangan & Pesawat Sederhana",
				"• Pesawat sederhana (mesin sederhana): alat yang memudahkan pekerjaan manusia (Tuas, Roda, Katrol, Bidang Miring).",
				"tuas",
				"• Operasi + / −: jumlahkan puluhan & satuan berurutan; pengurangan menghitung sisa komponen.",
				"• Mesin sederhana memperkecil gaya atau mengubah arah gaya agar kerja lebih ringan.",
			],
			[
				"Perkalian & Prinsip Tuas (Pengungkit)",
				"• Tuas berputar pada titik tumpu (tengah); gagang/lengan kuasa lebih panjang = mengangkat lebih ringan.",
				"titik tumpu",
				"• Jungkat-jungkit seimbang: anak/beban lebih berat duduk lebih dekat ke titik tumpu.",
				"• Contoh tuas: jungkat-jungkit, gunting, tang, linggis, sapu, penjepit gorengan, sumpit, centong, sendi siku.",
			],
			[
				"Pembagian & Prinsip Roda",
				"• Roda berbentuk bulat mengurangi gesekan; memudahkan memindahkan, menarik, mendorong, atau menggeser beban.",
				"roda",
				"• Contoh roda: sepeda, koper, troli, gerobak dorong, stroller, pintu pagar geser, setir mobil, mikser/whisk, kincir air (didorong aliran air).",
				"• Ban karet mencegah licin di jalan; pembagian (:) membagi jumlah komponen sama rata ke tiap kelompok.",
			],
			[
				"Operasi Campuran & Prinsip Katrol",
				"• Katrol: roda beralur + tali atau rantai; bagian yang berputar saat tali ditarik adalah rodanya.",
				"katrol",
				"• Katrol tetap: sumur timba, tiang bendera, tirai/gorden. Derek (crane): angkat beban berat/mobil mogok.",
				"• Penggulung pancing (reel) memakai prinsip roda/katrol; hitung perkalian/pembagian dulu sebelum tambah/kurang.",
			],
			[
				"Bidang Miring & Persiapan UTS",
				"• Bidang miring (papan miring, tangga, jalan gunung berkelok): makin landai = mendorong makin ringan.",
				"bidang miring",
				"• Contoh bidang miring tajam: pisau, kapak, pahat, ketam/serut kayu. Tangga bertingkat agar kaki tidak terpeleset.",
				"• Benda bulat menggelinding di lantai miring karena bidang miring; cangkul & pemotong kerupuk = tuas + bidang miring.",
			],
			# Hari 7..11 (Paruh 2 — Final / UAS prep)
			[
				"Pecahan & Bagian Lengan Tuas",
				"• Pecahan: 1/2 = setengah (bagi 2), 1/4 = seperempat (bagi 4), 3/4 = tiga perempat.",
				"pecahan",
				"• Contoh cepat: 1/2 dari 24 = 12; 1/4 dari 20 = 5; 3/4 dari 12 = 9.",
				"• Lengan kuasa lebih panjang dari lengan beban memperkecil gaya yang dibutuhkan pada tuas.",
			],
			[
				"Desimal & Ukuran Komponen",
				"• Desimal: 0,5 = 1/2; 0,25 = 1/4; 0,75 = 3/4; 0,5 + 0,5 = 1,0.",
				"desimal",
				"• Konversi cepat: 0,5 m = 50 cm; sejajarkan tanda koma saat menjumlahkan atau mengurangkan desimal.",
				"• Poros & bantalan: poros meneruskan putaran/torsi sejajar sumbu; bantalan mengurangi gesekan.",
			],
			[
				"Persen & Efisiensi Kerja Mesin",
				"• Persen = per seratus: 25% = 1/4, 50% = 1/2, 75% = 3/4, 100% = utuh.",
				"persen",
				"• Contoh cepat: 50% dari 80 = 40; 25% dari 40 = 10; 10% = bagi 10.",
				"• Motor mengubah energi listrik → gerak putar; roda gigi mengubah perbandingan putaran & torsi lewat gigi berkaitan.",
			],
			[
				"Pemilihan Alat & Mesin Terpadu",
				"• Ringkas fungsi: Tuas (ungkit/jepit), Roda (kurangi gesekan), Katrol (tarik/angkat dengan tali), Bidang Miring (naik/belah).",
				"efisiensi",
				"• Dudukan motor kokoh menjaga motor stabil; pelat dasar menjadi landasan seluruh komponen.",
				"• Ketidaksejajaran poros menimbulkan getaran berlebih; siapkan Blueprint lengkap sebelum merakit di lab.",
			],
			[
				"Evaluasi Terpadu & Persiapan UAS Sem 1",
				"• Hitung cepat Sem 1: +/−/×/:, pecahan (1/2, 1/4, 3/4), desimal (0,5), persen (25%, 50%).",
				"mesin sederhana",
				"• Tuas = jungkat-jungkit/gunting/tang; Roda = sepeda/koper/troli; Katrol = sumur/derek; Bidang Miring = papan/tangga/pisau/kapak.",
				"• Transmisi: Motor (listrik→putar), Poros (terus torsi), Bantalan (rendah gesekan), Roda gigi (ubah putaran/torsi).",
			],
		],
	],
	[
		"Semester 2",
		"Dasar Lanjutan: Pola Bilangan, Pengukuran & Mesin Lanjutan",
		[
			# Hari 1..5 (Paruh 1 — Midterm / UTS prep)
			[
				"Pola Bilangan Loncat & Membesar",
				"• Pola bilangan: cek selisih antarangka (loncat +1, +2, +3, +5, +7, +10, +15, +20, +25).",
				"pola",
				"• Contoh: 2, 4, 6, 8 → +2 (10); 5, 10, 15, 20 → +5 (25); 7, 14, 21, 28 → +7 (35).",
				"• Jika angka di tengah hilang (3, 6, ..., 12, 15), pakai selisih tetap (+3 → 9).",
			],
			[
				"Pola Mengecil, Berulang & Prinsip Baji",
				"• Pola mengecil (kurangi tetap, mis. −2 / −3) & berulang (1, 1, 2, 2, 3 → 3); pola bertingkat (+1, +2, +3, +4).",
				"baji",
				"• Baji: dua sisi miring bertemu di ujung tajam; bergerak masuk untuk membelah, memotong, atau memisahkan benda (tumpul = sangat sulit).",
				"• Contoh baji: kapak, pisau, pahat, gigi gergaji, ritsleting, kuku, moncong pesawat (membelah udara). Bola basket BUKAN baji.",
			],
			[
				"Pola Deret & Prinsip Sekrup",
				"• Sekrup (paku ulir): bidang miring melingkar mengelilingi silinder untuk mengikat/menyatukan kuat.",
				"sekrup",
				"• Sekrup dipasang diputar dengan obeng (paku biasa dipukul palu); putar kiri (CCW) → sekrup keluar/lepas.",
				"• Contoh sekrup: sekrup kayu, tutup botol ulir, bohlam/fitting, dongkrak ulir, lipstik/lem stik, kursi putar salon.",
			],
			[
				"Pola Bertingkat & Sistem Roda-Poros",
				"• Roda-poros: roda besar terhubung batang tengah (poros / as roda / hub) yang berputar bersama.",
				"roda-poros",
				"• Gagang obeng = roda; jika kenop pintu bulat dilepas, memutar batang besi kecil terasa sangat berat.",
				"• Contoh roda-poros: setir mobil, gagang pintu putar, kunci pas/inggris, stempel tanggal, penggiling kopi, bianglala, baling-baling, pemutar CD, kipas lipat (poros/engsel).",
			],
			[
				"Analisis Mesin Lanjutan & Persiapan UTS",
				"• Baji = membelah/memotong (ujung tajam); Sekrup = mengikat dengan ulir; Roda-poros = memperbesar gaya putar.",
				"ulir",
				"• Batang tengah penghubung dua roda/baling-baling/bianglala disebut poros (as roda / hub).",
				"• Cek pola bilangan: tentukan aturan tambah, kurang, bertingkat, atau berulang sebelum menjawab.",
			],
			# Hari 7..11 (Paruh 2 — Final / UAS prep)
			[
				"Perbandingan & Rasio Komponen",
				"• Perbandingan (rasio a : b): samakan satuan dulu, lalu kalikan kedua sisi dengan faktor yang sama.",
				"perbandingan",
				"• Contoh cepat: rasio 3 : 2, jika bagian pertama = 9 (×3), bagian kedua = 2 × 3 = 6.",
				"• Sederhanakan rasio dengan membagi kedua bilangan menggunakan FPB.",
			],
			[
				"Satuan Panjang, Massa & Waktu",
				"• Panjang: 1 m = 100 cm = 1000 mm; 1 km = 1000 m.",
				"satuan",
				"• Massa: 1 kg = 1000 g. Waktu: 1 jam = 60 menit; 1 menit = 60 detik.",
				"• Samakan satuan (cm, g, atau menit) sebelum menjumlahkan atau membandingkan.",
			],
			[
				"Alat Ukur & Kalibrasi Bengkel",
				"• Alat ukur baku: penggaris/meteran (panjang), neraca/timbangan (massa), stopwatch/jam (waktu).",
				"pengukuran",
				"• Kalibrasi: memastikan titik nol dan skala alat ukur tepat agar perakitan presisi.",
				"• Pembacaan ukuran tepat mencegah komponen longgar atau macet saat uji crank.",
			],
			[
				"Mesin Majemuk (Gabungan Mesin Sederhana)",
				"• Mesin majemuk (kompleks): alat yang menggabungkan ≥ 2 mesin sederhana sekaligus.",
				"gabungan",
				"• Tuas + Baji: gunting, pemotong kuku. Roda-poros + Baji: peraut pensil putar, blender, rotary cutter, pemeras jeruk.",
				"• Roda-poros + Sekrup: tuning peg gitar, keran air, kursi putar. Tuas + Roda-poros + Baji: pemotong pizza.",
			],
			[
				"Integrasi Proyek Akhir & Persiapan UAS Sem 2",
				"• Ringkas Sem 2: Pola bilangan (+/−/bertingkat), Rasio (a:b), Satuan (1 m=100 cm, 1 kg=1000 g, 1 jam=60 mnt).",
				"kalibrasi",
				"• Mesin lanjutan: Baji (kapak/pisau/ritsleting/gigi gergaji), Sekrup (ulir/bohlam/dongkrak/lipstik), Roda-poros (setir/kenop/obeng/bianglala).",
				"• Mesin majemuk: gunting/pemotong kuku (tuas+baji), blender/peraut (roda-poros+baji), pizza cutter (tuas+roda-poros+baji).",
			],
		],
	],
]

static var _bank_cache: Dictionary[int, Array] = {}


static func semester_for_day(absolute_day: int) -> int:
	@warning_ignore("integer_division")
	return clampi((maxi(1, absolute_day) - 1) / DAYS_PER_SEMESTER + 1, 1, SEMESTER_COUNT)


static func day_in_semester(absolute_day: int) -> int:
	return (maxi(1, absolute_day) - 1) % DAYS_PER_SEMESTER + 1


static func half_for_day(day_in_sem: int) -> int:
	return 1 if clampi(day_in_sem, 1, DAYS_PER_SEMESTER) <= MIDTERM_DAY else 2


static func is_exam_day(day_in_sem: int) -> bool:
	return day_in_sem == MIDTERM_DAY or day_in_sem == FINAL_DAY


static func is_lesson_day(day_in_sem: int) -> bool:
	return day_in_sem >= 1 and day_in_sem <= DAYS_PER_SEMESTER and not is_exam_day(day_in_sem)


static func absolute_day_for(semester: int, day_in_sem: int) -> int:
	return (clampi(semester, 1, SEMESTER_COUNT) - 1) * DAYS_PER_SEMESTER + clampi(day_in_sem, 1, DAYS_PER_SEMESTER)


static func deadline_day_for_half(semester: int, half: int) -> int:
	return absolute_day_for(semester, MIDTERM_DAY if half == 1 else FINAL_DAY)


## Backwards-compatible aliases kept for legacy callers.
static func semester_at(absolute_day: int) -> int:
	return semester_for_day(absolute_day)


static func week_at(absolute_day: int) -> int:
	return day_in_semester(absolute_day)


static func unit_index(day_in_sem: int) -> int:
	var clamped := clampi(day_in_sem, 1, DAYS_PER_SEMESTER)
	if clamped <= 5:
		return clamped - 1
	if clamped == MIDTERM_DAY:
		return 4
	if clamped <= 11:
		return clamped - 2
	return 9


static func course_title(semester: int) -> String:
	var course: Array = COURSES[clampi(semester, 1, SEMESTER_COUNT) - 1]
	return str(course[1])


static func lesson(semester: int, day_in_sem: int) -> Dictionary:
	var sem := clampi(semester, 1, SEMESTER_COUNT)
	var course: Array = COURSES[sem - 1]
	var unit: Array = course[2][unit_index(day_in_sem)]
	var bp_id := blueprint_for_lesson(sem, day_in_sem)
	var half := half_for_day(day_in_sem)
	return {
		"title": str(unit[0]),
		"material": str(unit[1]),
		"keyword": str(unit[2]),
		"sections": [
			str(unit[1]),
			str(unit[3]),
			str(unit[4]),
		],
		"year": str(course[0]),
		"course": str(course[1]),
		"blueprint_id": bp_id,
		"half": half,
	}


static func blueprint_for_lesson(semester: int, day_in_sem: int) -> String:
	if not is_lesson_day(day_in_sem):
		return ""
	return PROGRESSION.blueprint_for_half(semester, half_for_day(day_in_sem))


static func blueprint_info(blueprint_id: String) -> Dictionary:
	for entry: Dictionary in BLUEPRINTS:
		if str(entry.blueprint_id) == blueprint_id:
			return entry
	return {}


static func blueprint_for_slot(semester: int, slot: String) -> Dictionary:
	for entry: Dictionary in BLUEPRINTS:
		if int(entry.semester) == semester and str(entry.slot) == slot:
			return entry
	return {}


static func blueprints_for_semester(semester: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in BLUEPRINTS:
		if int(entry.semester) == semester:
			result.append(entry)
	return result


static func load_question_bank(semester: int) -> Array[Dictionary]:
	var sem := clampi(semester, 1, SEMESTER_COUNT)
	if _bank_cache.has(sem):
		var cached: Array[Dictionary] = []
		for item: Dictionary in _bank_cache[sem]:
			cached.append(item)
		return cached
	var path: String = QUESTION_BANK_PATHS.get(sem, "")
	var loaded: Array[Dictionary] = []
	if not path.is_empty() and FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary and parsed.get("questions") is Array:
				for raw: Variant in parsed.get("questions"):
					if raw is Dictionary:
						var choices_raw: Variant = raw.get("choices", [])
						if choices_raw is Array and choices_raw.size() == 4:
							var opts: Array[String] = []
							for c: Variant in choices_raw:
								opts.append(str(c))
							loaded.append({
								"id": str(raw.get("id", "")),
								"semester": int(raw.get("semester", sem)),
								"topic": str(raw.get("topic", "math")),
								"prompt": str(raw.get("prompt", "")),
								"choices": opts,
								"options": opts,
								"correct_index": clampi(int(raw.get("correct_index", 0)), 0, 3),
								"correct": clampi(int(raw.get("correct_index", 0)), 0, 3),
							})
	_bank_cache[sem] = loaded
	return loaded


## Draws a balanced, randomized, non-repeating set of 10 questions (5 math + 5 machine)
## from the validated in-repo Semester 1 or Semester 2 Bank Soal.
static func questions(semester: int, slot: int, kind: String, count: int = 10, seed_override: int = -1) -> Array[Dictionary]:
	var sem := clampi(semester, 1, SEMESTER_COUNT)
	var bank := load_question_bank(sem)
	var math_pool: Array[Dictionary] = []
	var machine_pool: Array[Dictionary] = []
	for q: Dictionary in bank:
		if str(q.get("topic", "")) == "math":
			math_pool.append(q)
		else:
			machine_pool.append(q)

	var rng := RandomNumberGenerator.new()
	if seed_override >= 0:
		rng.seed = seed_override
	else:
		# Deterministic-per-assessment-slot seed mixed with current time if needed;
		# using a stable per-(semester, slot, kind) seed guarantees draft resume matches the exact same 10 questions!
		var kind_hash := kind.hash()
		rng.seed = abs(sem * 100003 + slot * 1009 + kind_hash)

	_shuffle_pool(math_pool, rng)
	_shuffle_pool(machine_pool, rng)

	var math_target := mini(count / 2, math_pool.size())
	var machine_target := mini(count - math_target, machine_pool.size())
	var selected: Array[Dictionary] = []
	var used_ids: Dictionary[String, bool] = {}

	for i: int in range(math_target):
		var q := math_pool[i]
		used_ids[str(q.id)] = true
		selected.append(q)
	for i: int in range(machine_target):
		var q := machine_pool[i]
		if not used_ids.has(str(q.id)):
			used_ids[str(q.id)] = true
			selected.append(q)

	# Fill any remainder if one pool was smaller than target.
	for pool: Array[Dictionary] in [math_pool, machine_pool]:
		for q: Dictionary in pool:
			if selected.size() >= count:
				break
			if not used_ids.has(str(q.id)):
				used_ids[str(q.id)] = true
				selected.append(q)

	_shuffle_pool(selected, rng)
	return selected


static func _shuffle_pool(pool: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for i: int in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
