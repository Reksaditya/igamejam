# Deadline: panduan permainan dan integrasi

## Mulai bermain

New Game meminta nama pemain, membuat ID 12 digit berawalan 607, lalu memulai hari pertama pukul 06.00. Jika save sudah ada, konfirmasi dan input nama harus diselesaikan sebelum data lama diganti. Load melanjutkan autosave, termasuk lokasi, waktu, identitas, catatan, nilai, rancangan, dan perakitan. Pengaturan tidak dihapus oleh New Game.

Berjalan dengan A/D atau panah kiri/kanan; Shift untuk berlari. MC memakai animasi jalan enam frame, beralih ke side idle tujuh frame ketika berhenti, lalu idle depan setelah tiga detik tanpa berjalan. Arah side idle mengikuti arah jalan terakhir. Interaksi memakai E atau bubble yang muncul ketika mendekati objek. Lompatan tetap dinonaktifkan sesuai permintaan. Batas tepi world transparan. Interaksi pintu dan komputer menggunakan fade.

## Lokasi dan alur

<<<<<<<<< Temporary merge branch 1
Setelah seluruh catatan lengkap, kelas langsung memberikan blueprint `sediment_sorter`. Tombol **Buka blueprint** menampilkan gambar utuh. Jika pemberian gagal disimpan, tombol **Coba simpan lagi** dapat digunakan tanpa mengulang kelas.
=========
Kamar 210 kini memakai furniture kiriman pengguna, kursi interaktif, dan area gerak berukuran 60% lebar serta tinggi viewport. Detail aset dan perilaku resize/save tersedia di [panduan kamar](dorm-room.md).

- Halaman kampus: pintu tengah menuju lorong kelas F1; pintu di sisi kanan bangunan menuju ruang dosen. Tepi kanan menuju gedung lab; tepi kiri menuju asrama.
- Lorong kelas: tangga dengan E menghubungkan F1, F2, dan F3. Area tangga naik khusus untuk naik, dan akses tangga turun khusus untuk turun; tidak ada popup pilihan lantai. Pintu ganda menuju kelas di lantai tersebut. Keluar gedung dari sisi kiri F1. Detail: docs/classroom-corridor.md.
- Gedung lab: pintu menuju bengkel. Meja perakitan dapat diakses dengan E.
- Asrama: pintu masuk menuju lantai 1. Tangga di kanan menuju lantai 2. Pintu kamar 210 berada di sisi kiri lantai 2.
- Kamar 210: tempat tidur di kiri dan meja komputer di kanan. Komputer menyediakan Word Explorer/LMS, Library, Project, Blocks, Notepad, dan aplikasi desktop sebelumnya. Sandi awal komputer 123. Matikan komputer untuk kembali ke kamar.
- Ruang dosen: laporkan mesin yang selesai untuk memperoleh nilai proyek.
>>>>>>>>> Temporary merge branch 2

## Integrasi kelas, Library, dan lab

`ClassroomProgress` menyimpan catatan dan indeks materi yang sudah dilewati di `user://classroom_notes.cfg` versi 2. Berkas versi 1 tetap dibaca. `begin_material()` menandai satu kesempatan QTE, sedangkan `finish_material()` hanya menerima hasil dari kesempatan yang sedang berjalan. `unlock_blueprint()` tetap memerlukan semua catatan.

Kelas dan buku blueprint di Library menggunakan `ProjectBlueprints.grant(blueprint_id)`. Project dan pembaca kartu Workshop menggunakan `ProjectBlueprints.is_owned(blueprint_id)`. Status kepemilikan memakai kunci `completed` pada bagian ID blueprint di `user://blueprint_progress.cfg`. Kepemilikan lama tetap dibaca. Progres pemasangan sebagian tetap bisa menerima blueprint utuh ketika persyaratan hadiah terpenuhi.

Catatan akhir baru tersedia setelah kelas selesai. Kegagalan menyisakan bagian kosong. Buka Library pada komputer asrama, baca materi yang selesai atau minggu yang terlewat, lalu tuliskan keyword bacaan. Keyword benar melengkapi catatan dan memberikan satu potongan blueprint. Materi masa depan tidak tersedia. Jurnal profil mengelompokkan catatan dan proyek per semester/minggu; data terdahulu tanpa tanggal masuk Arsip Lama.

Minggu 8 dan 16 digunakan untuk UTS/UAS melalui komputer kelas. Tugas dan kuis tetap tersedia pada minggu tersebut.

## LMS, nilai, dan IPK

Word Explorer membuka LMS Universitas Redline. Tiap minggu ada tugas dan kuis, masing-masing sepuluh soal pilihan ganda. Tugas tidak memiliki timer pengerjaan; kuis, UTS, dan UAS dibatasi sepuluh menit nyata. Tugas/kuis ditutup setelah enam hari. Jawaban kosong bernilai nol. Timer habis mengumpulkan jawaban otomatis. Draf mempertahankan jawaban dan tenggat waktu nyata ketika aplikasi ditutup.

Nilai tersimpan hanya sekali dan dapat dilihat di riwayat. Tugas/kuis dirata-rata atas 16 minggu; nilai yang belum dikumpulkan bernilai nol. Bobot semester: tugas 10%, kuis 15%, UTS 22,5%, UAS 22,5%, proyek 30%. Total persentase dibagi 25 menghasilkan IPK 0–4. IPK kumulatif merata-ratakan semester yang sedang berlangsung dan semester sebelumnya.

## Blueprint dan proyek

Setiap semester memiliki sembilan potongan. Aplikasi Project menampilkan siluet 3×3. Pilih potongan milik pemain, lalu tempatkan di posisi yang sesuai. Potongan yang salah tidak dikonsumsi. Blueprint lengkap membuka perakitan di bengkel.

Bengkel memiliki enam komponen sesuai semester. Ambil komponen yang diminta objective, pilih Pasang, lalu selesaikan QTE. Komponen salah ditolak dan kegagalan QTE mengembalikan komponen ke rak. Preview menampilkan dudukan yang sudah terisi. Progres perakitan bertahan saat keluar atau Load.

Proyek semester delapan terlebih dahulu meminta rancangan mekanisme, masukan, dan sumber energi dari komponen yang sudah dipelajari. Pilihan memengaruhi daftar komponen dan tidak dapat diganti setelah disimpan.

Laporkan mesin lengkap kepada dosen. Nilai awal proyek 100, dikurangi lima per kegagalan QTE sampai pengurangan maksimum 40. Pengumpulan hanya sekali. Nilai masuk ke LMS dan IPK. Ketentuan penalti ini adalah aturan implementasi sementara yang dilaporkan pada validasi tahap 4.

## Energi, kewarasan, dan istirahat

Energi awal 100. Kelas menghabiskan 15, tugas/kuis 5, ujian 30, proyek 20, dan belajar ulang 5. Biaya tidak dipotong berulang untuk kegiatan yang sama ketika dilanjutkan. Energi nol membuat pemain tertidur di kelas dan semua catatan sesi tersebut kosong; perakitan memerlukan energi.

Aktivitas menambah tingkat kewarasan/tekanan sebesar 10, mengikuti arah angka GDD: nilai 80 atau lebih menimbulkan blur pada dunia, sementara HUD tetap terbaca. Istirahat mengembalikannya ke 50. Tidur delapan jam memulihkan energi dengan penalti 10 poin per jam setelah pukul 22.00. Istirahat singkat hanya memulihkan sebagian energi dan menambah kekurangan tidur; tidur cukup mengurangi kekurangan tersebut.

Satpam mengejar pemain yang berada di luar asrama sejak pukul 22.00 sampai sebelum 06.00. Ketika tertangkap, pemain diantar ke lantai 1 asrama. Asrama merupakan lokasi aman.

## Cerita dan ending

Empat chapter mengikuti awal kuliah, kesibukan semester tiga, kabar meninggalnya ibu pada pertengahan semester lima, dan pemulihan tekad pada semester enam. Perubahan energi/kewarasan cerita hanya diterapkan sekali. Nama pemain mengikuti nama saat New Game.

Perjalanan berakhir setelah UAS dan proyek akhir dikumpulkan pada minggu terakhir, atau kalender melewati delapan semester. Proyek akhir tidak lulus menghasilkan Bad Ending. Proyek lulus dengan IPK di bawah 3,5 menghasilkan Basic Ending; IPK setidaknya 3,5 menghasilkan Happy Ending, termasuk adegan dummy ziarah bersama ayah dan perjalanan berikutnya. Ending ikut disimpan dan dapat dimuat kembali.

## Profil, pengaturan, dan penyimpanan

HUD kanan atas membuka profil. Nama, ID, energi, status, dan jurnal membaca data pemain. Waktu tetap berjalan pada Profil/Status/Jurnal dan berhenti pada Settings. Pengaturan resolusi langsung diterapkan serta disimpan ketika dipilih; volume menyediakan preview dan tombol Terapkan. Pilihan juga tersedia di main menu.

GameSave menyimpan snapshot versi 2 setiap dua detik, saat progres berubah, dan ketika game ditutup. Berkas career_progress.cfg memuat kelas per minggu, blueprint, perakitan, nilai, cerita, dan ending; draf berada di career_drafts. Semua termasuk penggantian data transaksional untuk New Game/Load. Save versi 1 tetap dibaca; catatan/blueprint contoh lama dipertahankan sebagai arsip tanpa dianggap sebagai kelulusan kurikulum baru.

## Validasi

Jalankan tools/run_production_tests.py dengan --godot menunjuk executable Godot 4.7.2. Runner membuat direktori APPDATA/LOCALAPPDATA terisolasi di .godot/production-validation, menyimpan log, menguji 12 kelompok fitur dan lima pengujian ulang dari proses baru, lalu mengembalikan kode gagal jika ada runtime error atau hasil uji tidak lengkap.

Pengujian grafis tambahan memakai opsi --capture pada academic_flow_smoke, dorm_study_smoke, workshop_flow_smoke, world_life_smoke, dan player_profile_smoke. Tangkapan layar berada di .godot. Aset lingkungan, NPC, mesin, dan cutscene masih dummy sesuai persetujuan pengguna; karakter memakai tujuh frame idle yang telah diberikan.
