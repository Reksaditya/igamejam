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

## 2 Semesters x 10 lesson units (Hari 1-5 Paruh 1 / UTS prep, Hari 7-11 Paruh 2 / UAS prep).
const COURSES := [
	[
		"Semester 1",
		"Dasar-Dasar: Operasi Bilangan & Mesin Sederhana",
		[
			# Hari 1..5 (Paruh 1 — Midterm / UTS prep)
			[
				"Penjumlahan, Pengurangan & Pengenal Alat",
				"Operasi tambah dan kurang menghitung kebutuhan dan sisa komponen. Mesin sederhana membantu mempermudah serta mempercepat pekerjaan manusia.",
				"tuas",
			],
			[
				"Perkalian & Prinsip Tuas (Pengungkit)",
				"Perkalian membantu menghitung komponen berulang. Tuas berputar pada titik tumpu; lengan kuasa yang lebih panjang mengurangi gaya yang dibutuhkan.",
				"titik tumpu",
			],
			[
				"Pembagian & Prinsip Roda",
				"Pembagian membagi material secara merata. Roda berbentuk bulat mengurangi gesekan agar memindahkan beban berat jauh lebih ringan daripada menyeretnya.",
				"roda",
			],
			[
				"Operasi Campuran & Prinsip Katrol",
				"Hitung kebutuhan gaya secara bertahap. Katrol berupa roda beralur dengan tali atau rantai untuk mengubah arah tarikan dan meringankan beban angkat.",
				"katrol",
			],
			[
				"Bidang Miring & Persiapan UTS",
				"Bidang miring seperti papan miring, tangga, dan jalan berkelok memanjangkan lintasan agar gaya mengangkat beban menjadi lebih kecil.",
				"bidang miring",
			],
			# Hari 7..11 (Paruh 2 — Final / UAS prep)
			[
				"Pecahan & Bagian Lengan Tuas",
				"Pecahan (1/2, 1/4, 3/4) menyatakan bagian dari keseluruhan. Memahami proporsi panjang lengan kuasa dan lengan beban membuat tuas lebih efisien.",
				"pecahan",
			],
			[
				"Desimal & Ukuran Komponen Roda",
				"Desimal menyatakan ukuran presisi seperti 0,5 meter = 50 sentimeter. Ketepatan diameter roda dan poros menjaga putaran tetap stabil.",
				"desimal",
			],
			[
				"Persen & Efisiensi Kerja Mesin",
				"Persen berarti per seratus (25% = 1/4, 50% = 1/2). Persentase membantu menilai efisiensi dan porsi komponen yang siap dirakit.",
				"persen",
			],
			[
				"Pemilihan Alat & Mesin Terpadu",
				"Kenali fungsi tiap mesin: gunting dan linggis memakai tuas, kapak dan pisau memakai bidang miring, derek memakai katrol, troli memakai roda.",
				"efisiensi",
			],
			[
				"Evaluasi Terpadu & Persiapan UAS Sem 1",
				"Gabungkan hitungan operasi bilangan, pecahan, desimal, dan persen untuk memilih kombinasi tuas, roda, katrol, dan bidang miring yang paling aman.",
				"mesin sederhana",
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
				"Pola bilangan mengikuti aturan tetap seperti loncat +2, +5, atau +10. Mengamati selisih antarangka membantu memprediksi langkah berikutnya.",
				"pola",
			],
			[
				"Pola Berulang, Mengecil & Baji",
				"Pola dapat mengecil atau berulang secara periodik. Baji adalah dua bidang miring menyatu yang berfungsi membelah, memotong, atau mengganjal benda.",
				"baji",
			],
			[
				"Pola Deret & Prinsip Sekrup",
				"Sekrup adalah bidang miring yang melingkar mengelilingi silinder. Jarak ulir yang teratur mengubah gerak putar menjadi gerak maju untuk mengikat kuat.",
				"sekrup",
			],
			[
				"Pola Bertingkat & Sistem Roda-Poros",
				"Roda-poros menghubungkan roda besar dengan poros di tengahnya agar berputar bersama, seperti setir mobil, gagang pintu putar, dan obeng.",
				"roda-poros",
			],
			[
				"Analisis Mesin Lanjutan & Persiapan UTS",
				"Bandingkan fungsi baji (memotong/membelah), sekrup (mengikat dengan ulir), dan roda-poros (memperbesar gaya putar) sebelum menghadapi UTS.",
				"ulir",
			],
			# Hari 7..11 (Paruh 2 — Final / UAS prep)
			[
				"Perbandingan & Rasio Komponen",
				"Perbandingan (rasio) membandingkan dua besaran sejenis. Sebelum membandingkan ukuran komponen, samakan dulu satuannya.",
				"perbandingan",
			],
			[
				"Satuan Panjang, Massa & Waktu",
				"Gunakan satuan baku: 1 m = 100 cm = 1000 mm, 1 kg = 1000 g, 1 jam = 60 menit. Pengukuran akurat mencegah kesalahan sambungan mesin.",
				"satuan",
			],
			[
				"Alat Ukur & Kalibrasi Bengkel",
				"Pilih alat ukur sesuai besaran: penggaris/meteran untuk panjang, neraca untuk massa, stopwatch untuk waktu. Kalibrasi memastikan keakuratan acuan.",
				"pengukuran",
			],
			[
				"Penggabungan Mesin Sederhana Lanjutan",
				"Banyak alat modern menggabungkan beberapa mesin: gunting (tuas + baji), keran air (roda-poros + sekrup), gerobak dorong (tuas + roda-poros).",
				"gabungan",
			],
			[
				"Integrasi Proyek Akhir & Persiapan UAS Sem 2",
				"Satukan pola bilangan, perbandingan, pengukuran, dan gabungan baji, sekrup, serta roda-poros untuk merakit proyek akhir dengan aman dan teruji.",
				"kalibrasi",
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
			"Penerapan: %s (Semester %d · Paruh %d). Catat prinsip kerja dan contohnya untuk Tugas, Kuis, serta Ujian." % [str(unit[0]), sem, half],
			"Keselamatan & Praktik: periksa satuan, fungsi tiap bagian, dan pastikan penggerak aman sebelum menguji mesin di Bengkel.",
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
