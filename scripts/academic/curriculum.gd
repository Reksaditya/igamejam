extends RefCounted

const COURSES := [
	[
		"Dasar",
		"Operasi bilangan dan mesin sederhana",
		[
			[
				"Penjumlahan dan tuas",
				"Jumlahkan beban sebelum memilih tuas. Tuas berputar pada titik tumpu; lengan kuasa yang lebih panjang mengurangi gaya yang diperlukan.",
				"tuas",
				"Bagian tempat tuas berputar adalah",
				"titik tumpu",
				"roda gigi",
				"kabel",
				"katup"
			],
			[
				"Pengurangan dan roda",
				"Pengurangan menghitung sisa bahan. Roda mengurangi hambatan saat memindahkan beban dibandingkan menyeretnya.",
				"roda",
				"Mengapa troli memakai roda?",
				"Memudahkan perpindahan beban",
				"Menghasilkan listrik",
				"Mengukur suhu",
				"Menyimpan data"
			],
			[
				"Perkalian dan katrol",
				"Perkalian membantu menghitung komponen berulang. Katrol mengubah arah tarikan; beberapa katrol dapat mengurangi gaya angkat.",
				"katrol",
				"Fungsi katrol tetap adalah",
				"Mengubah arah gaya tarik",
				"Menyimpan energi listrik",
				"Memotong baja",
				"Mengukur massa"
			],
			[
				"Pembagian dan bidang miring",
				"Pembagian membagi bahan secara merata. Bidang miring memanjangkan lintasan agar gaya mengangkat beban lebih kecil.",
				"bidang miring",
				"Keuntungan bidang miring adalah",
				"Mengurangi gaya dengan lintasan lebih panjang",
				"Menghapus massa beban",
				"Membuat energi tanpa sumber",
				"Menghentikan gravitasi"
			],
			[
				"Pecahan dan lengan tuas",
				"Pecahan menyatakan bagian dari keseluruhan. Setengah meter sama dengan 1/2 meter. Pada tuas, gaya dikali panjang lengan menentukan momen.",
				"pecahan",
				"1/2 dari delapan komponen adalah",
				"4 komponen",
				"2 komponen",
				"6 komponen",
				"8 komponen"
			],
			[
				"Desimal dan pengukuran roda",
				"Desimal menyatakan bagian dengan nilai tempat. 0,5 meter sama dengan 50 sentimeter. Periksa satuan sebelum membandingkan ukuran roda.",
				"desimal",
				"0,5 meter setara dengan",
				"50 sentimeter",
				"5 sentimeter",
				"500 sentimeter",
				"0,5 sentimeter"
			],
			[
				"Persen dan pemilihan mesin",
				"Persen berarti per seratus. Efisiensi membandingkan hasil berguna terhadap masukan. Pilih alat berdasarkan beban, lintasan, dan keselamatan.",
				"persen",
				"25% dari 100 baut adalah",
				"25 baut",
				"4 baut",
				"75 baut",
				"125 baut"
			]
		]
	],
	[
		"Dasar",
		"Perbandingan, pengukuran dan gabungan mesin",
		[
			[
				"Perbandingan dan baji",
				"Perbandingan membandingkan dua besaran sejenis. Baji memiliki bidang miring untuk membelah atau memisahkan material.",
				"baji",
				"Contoh penerapan baji adalah",
				"mata kapak",
				"lampu",
				"sensor suhu",
				"baterai"
			],
			[
				"Pola bilangan dan sekrup",
				"Pola bilangan mengikuti aturan. Sekrup mengubah gerak putar menjadi perpindahan maju mengikuti ulir.",
				"sekrup",
				"Sekrup mengubah gerak putar menjadi",
				"gerak maju sepanjang ulir",
				"cahaya",
				"sinyal radio",
				"data digital"
			],
			[
				"Satuan panjang dan roda-poros",
				"Gunakan satuan yang sama: 1 m = 100 cm = 1000 mm. Roda dan poros terhubung pada sumbu yang sama.",
				"roda-poros",
				"Satu meter sama dengan",
				"1000 milimeter",
				"10 milimeter",
				"100 milimeter",
				"10000 milimeter"
			],
			[
				"Massa, waktu dan alat ukur",
				"Massa diukur dalam kilogram dan waktu dalam detik. Pilih alat sesuai besaran: penggaris untuk panjang, neraca untuk massa.",
				"pengukuran",
				"Alat yang sesuai untuk mengukur massa adalah",
				"neraca",
				"penggaris",
				"jam",
				"termometer"
			],
			[
				"Rasio dan mesin gabungan",
				"Gabungan tuas, katrol, dan roda dapat menyelesaikan pekerjaan bertahap. Rasio harus memperhatikan satuan dan fungsi tiap bagian.",
				"rasio",
				"Sebelum membandingkan panjang, kita harus",
				"menyamakan satuan",
				"menghapus angka",
				"mengabaikan skala",
				"mengganti massa"
			],
			[
				"Pola pertumbuhan dan ulir",
				"Jarak antarulir yang seragam menghasilkan perpindahan berulang yang terukur. Pola 2,4,6,8 bertambah dua tiap langkah.",
				"ulir",
				"Angka berikutnya pada pola 2,4,6,8 adalah",
				"10",
				"9",
				"12",
				"16"
			],
			[
				"Kalibrasi mesin sederhana",
				"Kalibrasi membandingkan alat dengan acuan. Ukur ulang, catat hasil, dan periksa pengikat sebelum menguji mesin gabungan.",
				"kalibrasi",
				"Tujuan kalibrasi adalah",
				"membandingkan pengukuran dengan acuan",
				"memperbesar semua beban",
				"mengganti fungsi mesin",
				"menghilangkan satuan"
			]
		]
	],
	[
		"Pengembangan",
		"Geometri, variabel dan komponen penggerak",
		[
			[
				"Luas dan roda gigi",
				"Luas persegi panjang adalah panjang kali lebar. Roda gigi yang saling berkait meneruskan putaran dengan arah berlawanan.",
				"roda gigi",
				"Dua roda gigi luar yang berkaitan berputar",
				"berlawanan arah",
				"selalu diam",
				"tanpa poros",
				"tanpa kontak"
			],
			[
				"Volume dan rantai",
				"Volume balok adalah panjang kali lebar kali tinggi. Rantai meneruskan putaran antara sproket dengan hubungan gigi yang pasti.",
				"rantai",
				"Rantai dipasangkan dengan",
				"sproket",
				"katup",
				"lampu",
				"kapasitor"
			],
			[
				"Keliling dan sabuk",
				"Keliling mengukur panjang batas. Sabuk meneruskan putaran melalui puli; ketegangan yang kurang dapat membuat sabuk selip.",
				"sabuk",
				"Sabuk yang terlalu longgar berisiko",
				"selip",
				"menghasilkan air",
				"mengubah warna",
				"menambah massa"
			],
			[
				"Variabel dan engkol",
				"Variabel mewakili nilai yang dapat berubah. Engkol dapat mengubah putaran menjadi gerak bolak-balik dengan batang penghubung.",
				"engkol",
				"Engkol dengan batang penghubung dapat menghasilkan",
				"gerak bolak-balik",
				"arus tanpa baterai",
				"data tanpa sensor",
				"cahaya tanpa lampu"
			],
			[
				"Rasio roda gigi",
				"Roda penggerak 10 gigi yang memutar roda 20 gigi menghasilkan kecepatan keluaran setengahnya pada model ideal.",
				"transmisi",
				"Penggerak 10 gigi menuju 20 gigi membuat keluaran",
				"lebih lambat",
				"dua kali lebih cepat",
				"selalu nol",
				"tanpa arah"
			],
			[
				"Luas penampang dan poros",
				"Luas penampang membantu menilai bagian yang menerima beban. Geometri komponen harus sesuai ruang dan sambungan.",
				"penampang",
				"Volume balok 2 × 3 × 4 adalah",
				"24 satuan kubik",
				"9 satuan kubik",
				"12 satuan kubik",
				"20 satuan kubik"
			],
			[
				"Model variabel penggerak",
				"Tuliskan masukan, proses, dan keluaran sebagai variabel. Periksa arah putaran dan pelindung sebelum menyalakan transmisi.",
				"variabel",
				"Jika x + 3 = 7, nilai x adalah",
				"4",
				"3",
				"7",
				"10"
			]
		]
	],
	[
		"Pengembangan",
		"Aljabar, logika dan komponen penopang",
		[
			[
				"Aljabar dan poros",
				"Persamaan menjaga kedua sisi tetap setara. Poros meneruskan putaran dan memerlukan posisi sumbu yang benar.",
				"poros",
				"Jika x + 5 = 12, x adalah",
				"7",
				"5",
				"12",
				"17"
			],
			[
				"Grafik dan bantalan",
				"Grafik menunjukkan hubungan antarbesaran. Bantalan menopang poros dan mengurangi gesekan saat berputar.",
				"bantalan",
				"Fungsi bantalan adalah",
				"menopang poros dan mengurangi gesekan",
				"menghasilkan bahan bakar",
				"memutus semua putaran",
				"menggantikan baterai"
			],
			[
				"Tabel dan pegas",
				"Tabel menyusun hasil ukur. Pegas menyimpan energi elastis ketika ditekan atau ditarik dalam batas kerjanya.",
				"pegas",
				"Pegas yang ditekan menyimpan",
				"energi elastis",
				"data digital",
				"energi nuklir",
				"air"
			],
			[
				"Logika jika-maka dan baut",
				"Jika sambungan longgar, maka hentikan mesin sebelum mengencangkan baut. Baut dan mur menyatukan komponen secara dapat dilepas.",
				"baut",
				"Tindakan aman ketika baut longgar adalah",
				"matikan mesin sebelum mengencangkan",
				"sentuh bagian bergerak",
				"naikkan kecepatan",
				"lepas pelindung"
			],
			[
				"Persamaan dan mur",
				"Baut dan mur harus memiliki ukuran ulir sesuai. Jangan memaksa pasangan ulir yang berbeda.",
				"mur",
				"Baut dan mur yang dipasangkan harus",
				"memiliki ukuran ulir sesuai",
				"selalu berbeda ukuran",
				"dipasang tanpa pemeriksaan",
				"terbuat dari kertas"
			],
			[
				"Membaca kemiringan grafik",
				"Grafik waktu dan perpindahan membantu membaca perubahan gerak. Catat nama sumbu dan satuan sebelum menyimpulkan.",
				"grafik",
				"Sebelum membaca grafik, periksa",
				"nama sumbu dan satuan",
				"warna meja saja",
				"nama pemain saja",
				"suara mesin saja"
			],
			[
				"Penopang dan aturan keselamatan",
				"Susun poros, bantalan, pegas, dan pengikat sebagai sistem. Jika pelindung terbuka, maka penggerak harus dimatikan.",
				"logika",
				"Jika pelindung terbuka, penggerak sebaiknya",
				"dimatikan",
				"dipercepat",
				"diberi beban lebih",
				"diabaikan"
			]
		]
	],
	[
		"Terapan",
		"Statistik, probabilitas dan mekanisme gerak",
		[
			[
				"Rata-rata dan cam",
				"Rata-rata adalah jumlah data dibagi banyaknya data. Cam mengubah putaran menjadi gerak pengikut sesuai profilnya.",
				"cam",
				"Rata-rata dari 2,4,6 adalah",
				"4",
				"2",
				"6",
				"12"
			],
			[
				"Diagram dan piston",
				"Diagram membantu membandingkan data. Piston bergerak bolak-balik di dalam silinder.",
				"piston",
				"Gerak utama piston dalam silinder adalah",
				"bolak-balik",
				"selalu melingkar bebas",
				"diam selamanya",
				"acak tanpa batas"
			],
			[
				"Probabilitas dan katup",
				"Peluang sederhana adalah kejadian yang diinginkan dibagi semua kejadian setara. Katup mengatur aliran fluida.",
				"katup",
				"Fungsi katup adalah",
				"mengatur aliran fluida",
				"menghitung nilai IPK",
				"menggantikan roda",
				"menyimpan catatan"
			],
			[
				"Variasi data dan tuas majemuk",
				"Tuas majemuk menggabungkan beberapa tuas. Ukur beberapa percobaan agar kesimpulan tidak hanya bergantung pada satu hasil.",
				"tuas majemuk",
				"Mengapa pengukuran perlu diulang?",
				"Menilai variasi hasil",
				"Menghapus semua data",
				"Menghindari satuan",
				"Mengubah hukum fisika"
			],
			[
				"Frekuensi dan profil cam",
				"Frekuensi menyatakan jumlah kejadian dalam satu rentang. Profil cam menentukan waktu naik dan turun pengikut.",
				"pengikut",
				"Bentuk cam memengaruhi",
				"gerak pengikut",
				"nama operator",
				"warna bahan bakar",
				"jumlah huruf"
			],
			[
				"Peluang kegagalan komponen",
				"Peluang berada antara 0 dan 1. Nilai 0 berarti mustahil pada model; nilai 1 berarti pasti pada model.",
				"peluang",
				"Peluang 1/2 setara dengan",
				"50%",
				"2%",
				"100%",
				"25%"
			],
			[
				"Menganalisis mekanisme",
				"Gunakan diagram, rata-rata, dan pengamatan untuk membandingkan mekanisme. Hentikan pengujian bila ada kebocoran atau sambungan longgar.",
				"statistik",
				"Kesimpulan eksperimen sebaiknya didukung oleh",
				"data pengamatan",
				"tebakan saja",
				"warna favorit",
				"nama komponen saja"
			]
		]
	],
	[
		"Terapan",
		"Algoritma dan elektronik konseptual",
		[
			[
				"Urutan algoritma dan baterai",
				"Algoritma adalah langkah terurut. Baterai menyediakan energi listrik; pasang dengan polaritas yang benar.",
				"baterai",
				"Fungsi baterai adalah",
				"menyediakan energi listrik",
				"membuat gaya tanpa energi",
				"menghapus program",
				"mengukur panjang"
			],
			[
				"Diagram alir dan kabel",
				"Diagram alir menggambarkan urutan dan percabangan. Kabel menghubungkan komponen agar arus memiliki lintasan.",
				"kabel",
				"Kabel pada rangkaian berfungsi sebagai",
				"penghubung lintasan listrik",
				"sumber massa",
				"buku catatan",
				"bantalan"
			],
			[
				"Percabangan dan saklar",
				"Jika saklar tertutup, lintasan terhubung; jika terbuka, lintasan terputus. Ini contoh aturan jika-maka.",
				"saklar",
				"Saklar terbuka membuat lintasan",
				"terputus",
				"selalu lebih terang",
				"menjadi poros",
				"menambah baterai"
			],
			[
				"Keluaran program dan lampu",
				"Lampu merupakan keluaran yang mengubah energi listrik menjadi cahaya. Program visual dapat mengatur kapan lampu menyala.",
				"lampu",
				"Lampu mengubah energi listrik menjadi",
				"cahaya",
				"catatan",
				"massa",
				"variabel"
			],
			[
				"Perulangan dan motor",
				"Perulangan menjalankan langkah beberapa kali. Motor mengubah energi listrik menjadi gerak dan harus dimatikan sebelum dirakit.",
				"motor",
				"Motor listrik menghasilkan",
				"gerak",
				"air tanpa sumber",
				"angka acak saja",
				"udara tanpa komponen"
			],
			[
				"Masukan program dan sensor",
				"Sensor membaca kondisi lingkungan sebagai masukan. Program mengolah masukan lalu menentukan keluaran.",
				"sensor",
				"Peran sensor dalam sistem adalah",
				"membaca kondisi sebagai masukan",
				"menggantikan seluruh program",
				"menghasilkan semua energi",
				"menjadi pengikat"
			],
			[
				"Program visual rangkaian",
				"Susun blok Mulai, Baca sensor, Jika kondisi, Aktifkan keluaran. Uji sambungan tanpa daya sebelum menyalakan rangkaian.",
				"algoritma",
				"Urutan sistem kendali yang benar adalah",
				"masukan, proses, keluaran",
				"keluaran, keluaran, keluaran",
				"energi tanpa sumber",
				"sensor tanpa proses"
			]
		]
	],
	[
		"Integrasi",
		"Optimasi dan mesin otomatis",
		[
			[
				"Menentukan masalah robot",
				"Tentukan kebutuhan dan batasan sebelum memilih komponen. Robot menggabungkan sensor, kendali, dan penggerak.",
				"robot",
				"Langkah awal merancang robot adalah",
				"menentukan kebutuhan dan batasan",
				"membeli komponen tanpa tujuan",
				"menyalakan tanpa pemeriksaan",
				"menghapus semua data"
			],
			[
				"Membandingkan solusi",
				"Bandingkan beberapa rancangan berdasarkan biaya, energi, keandalan, dan keselamatan. Solusi terbaik mengikuti kriteria yang jelas.",
				"optimasi",
				"Optimasi memerlukan",
				"kriteria dan batasan",
				"tebakan tanpa tujuan",
				"satu warna",
				"tanpa data"
			],
			[
				"Integrasi sensor mekanik",
				"Sensor mendeteksi kondisi, pengendali memilih tindakan, lalu motor menggerakkan mekanisme.",
				"otomasi",
				"Urutan kerja otomatis adalah",
				"sensor, pengendali, penggerak",
				"penggerak tanpa energi",
				"lampu menjadi mur",
				"bantalan menjadi program"
			],
			[
				"Umpan balik sederhana",
				"Umpan balik membandingkan keadaan nyata dengan sasaran dan membantu memperbaiki tindakan.",
				"umpan balik",
				"Kegunaan umpan balik adalah",
				"menyesuaikan tindakan berdasarkan keadaan",
				"menghilangkan semua sensor",
				"mengganti semua baut",
				"menambah gangguan"
			],
			[
				"Efisiensi dan transmisi",
				"Pilih rasio transmisi sesuai kebutuhan kecepatan dan torsi. Efisiensi membandingkan energi berguna dengan energi masukan.",
				"efisiensi",
				"Efisiensi menilai perbandingan",
				"hasil berguna terhadap masukan",
				"nama terhadap warna",
				"massa terhadap huruf",
				"tanggal terhadap baut"
			],
			[
				"Pengujian mesin otomatis",
				"Uji setiap subsistem sebelum sistem lengkap. Catat hasil, perbaiki satu penyebab, dan uji kembali.",
				"pengujian",
				"Mengapa subsistem diuji terpisah?",
				"Memudahkan menemukan penyebab masalah",
				"Menghapus kebutuhan keselamatan",
				"Menghindari semua data",
				"Menaikkan risiko"
			],
			[
				"Optimasi rancangan robot",
				"Perbaikan harus terukur: bandingkan hasil sebelum dan sesudah. Jangan menukar keselamatan dengan kecepatan.",
				"keandalan",
				"Perbaikan rancangan dinilai melalui",
				"hasil uji sebelum dan sesudah",
				"tebakan operator saja",
				"jumlah warna",
				"nama berkas"
			]
		]
	],
	[
		"Integrasi",
		"Proyek akhir, manajemen dan keselamatan",
		[
			[
				"Tujuan proyek akhir",
				"Tulis kebutuhan pengguna, tujuan terukur, serta batas biaya dan waktu. Rancangan akhir memakai komponen yang sudah dipelajari.",
				"kebutuhan",
				"Tujuan proyek sebaiknya",
				"jelas dan dapat diuji",
				"tidak dapat diukur",
				"berubah setiap detik",
				"tanpa batasan"
			],
			[
				"Perencanaan komponen",
				"Buat daftar komponen dan hubungan antarbagian. Pilih komponen mekanik dan elektronik sesuai fungsi.",
				"komponen",
				"Daftar komponen membantu",
				"merencanakan kebutuhan perakitan",
				"menghapus jadwal",
				"mengganti pengujian",
				"mengabaikan biaya"
			],
			[
				"Jadwal dan ketergantungan",
				"Pecah proyek menjadi tugas kecil. Pekerjaan yang bergantung pada bagian lain dijadwalkan setelah bagian itu siap.",
				"jadwal",
				"Tugas yang membutuhkan rangka selesai dikerjakan",
				"setelah rangka siap",
				"sebelum kebutuhan diketahui",
				"tanpa bahan",
				"tanpa urutan"
			],
			[
				"Identifikasi risiko",
				"Catat bahaya dan tindakan pengendalian. Matikan sumber energi sebelum merakit atau memperbaiki mesin.",
				"keselamatan",
				"Sebelum merakit mesin, sumber energi harus",
				"dimatikan",
				"ditambah dayanya",
				"diabaikan",
				"dipindah ke operator"
			],
			[
				"Perakitan dan dokumentasi",
				"Ikuti blueprint, pasang komponen sesuai urutan, dan dokumentasikan perubahan. Perubahan harus diuji ulang.",
				"dokumentasi",
				"Perubahan rancangan sebaiknya",
				"dicatat dan diuji ulang",
				"disembunyikan",
				"tidak diperiksa",
				"langsung dianggap aman"
			],
			[
				"Validasi dan presentasi",
				"Bandingkan hasil uji terhadap tujuan awal. Jelaskan cara kerja, keterbatasan, biaya, serta prosedur aman.",
				"validasi",
				"Validasi membandingkan hasil dengan",
				"kebutuhan awal",
				"warna favorit",
				"nama kelompok",
				"jumlah judul"
			],
			[
				"Penyerahan proyek akhir",
				"Periksa kelengkapan mesin, catatan uji, dan keselamatan sebelum melapor kepada dosen. Nilai akhir menentukan kelulusan.",
				"penyerahan",
				"Proyek siap dikumpulkan setelah",
				"fungsi dan keselamatannya diuji",
				"baru diberi nama",
				"bahan belum tersedia",
				"rangka belum terpasang"
			]
		]
	]
]
const WEEK_COUNT := 16
const SEMESTER_COUNT := 8


static func semester_at(absolute_week: int) -> int:
	return clampi(floori(float(maxi(1, absolute_week) - 1) / 16.0) + 1, 1, 8)


static func week_at(absolute_week: int) -> int:
	return (maxi(1, absolute_week) - 1) % 16 + 1


static func unit_index(week: int) -> int:
	return clampi(week - 1 if week < 8 else week - 2, 0, 13) % 7


static func lesson(semester: int, week: int) -> Dictionary:
	var course: Array = COURSES[clampi(semester, 1, 8) - 1]
	var unit: Array = course[2][unit_index(week)]
	return {"title": unit[0], "material": unit[1], "keyword": unit[2], "sections": [unit[1], "Penerapan: " + unit[0] + ". Catat masukan, proses, dan keluaran sebelum memilih komponen.", "Keselamatan: matikan sumber energi, periksa sambungan, lalu uji fungsi sesuai tujuan."], "year": course[0], "course": course[1]}


static func questions(semester: int, week: int, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := 7 if kind in ["uts", "uas"] else unit_index(week) + 1
	for index: int in 10:
		var unit: Array = COURSES[clampi(semester, 1, 8) - 1][2][(unit_index(week) + index) % count]
		var options: Array[String] = [unit[4], unit[5], unit[6], unit[7]]
		var correct := (semester + week + index) % 4
		var answer: String = options.pop_front()
		options.insert(correct, answer)
		result.append({"prompt": unit[3] + "?", "options": options, "correct": correct})
	for index: int in 3:
		result[index] = _calculation(semester, week, index)
	return result


static func _calculation(semester: int, week: int, index: int) -> Dictionary:
	var a := week + index + 2
	var b := index + 2
	var answer := 0
	var prompt := ""
	match semester:
		1:
			answer = a + b if index == 0 else (a * b if index == 1 else a - b)
			prompt = "%d %s %d = ?" % [a, "+" if index == 0 else ("×" if index == 1 else "−"), b]
		2:
			answer = a * 100 if index == 0 else a * b
			prompt = "%d meter = berapa sentimeter?" % a if index == 0 else "Rasio komponen 1:%d. Untuk %d kelompok diperlukan berapa komponen?" % [a, b]
		3:
			answer = a * b * (2 if index == 2 else 1)
			prompt = "Volume balok %d × %d × 2 = ?" % [a, b] if index == 2 else "Luas persegi panjang %d × %d = ?" % [a, b]
		4:
			answer = a
			prompt = "x + %d = %d. Berapa x?" % [b, a + b]
		5:
			answer = a
			prompt = "Rata-rata data %d, %d, %d = ?" % [a - 1, a, a + 1]
		6:
			answer = a * b
			prompt = "Blok ulang %d kali menjalankan %d langkah per putaran. Total langkah?" % [a, b]
		7:
			answer = a - b
			prompt = "Energi awal %d unit, setelah optimasi %d unit. Berapa penghematannya?" % [a, b]
		8:
			answer = a * b
			prompt = "%d komponen berharga %d satuan per buah. Total biaya?" % [a, b]
	var correct := (week + index) % 4
	var options: Array[String] = [str(answer + 1), str(answer + 2), str(answer + 3)]
	options.insert(correct, str(answer))
	return {"prompt": prompt, "options": options, "correct": correct}

