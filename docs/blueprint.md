# Mekanik blueprint

Jalankan scene utama, dekati pintu gedung kampus, lalu tekan **E** untuk masuk kelas. Pada minggu pembelajaran biasa, dekati kursi di sebelah kanan meja dekat papan tulis, lalu tekan **E · Duduk dan Belajar**. Pemain duduk dan ruangan tetap terlihat; gerakan serta tombol desktop dikunci selama belajar. QTE pertama muncul empat detik setelah mulai, kemudian QTE berikutnya muncul setelah jeda acak 5–11 detik. Tidak ada hitung mundur menuju kemunculan QTE. Angka ini dapat diatur pada scene `class_lesson.tscn`.

Popup QTE mengikuti posisi di atas kepala pemain, termasuk ketika kamera atau ukuran viewport berubah. Tekan **Space** saat penanda berada pada zona hijau. Setiap keberhasilan mengisi satu bagian catatan; kegagalan membiarkan bagian itu kosong. Catatan akhir baru ditampilkan setelah seluruh materi selesai. Tombol **Lihat catatan akhir kelas** hanya membaca hasil dan tidak memulai ulang pembelajaran.

Kesulitan QTE meningkat setelah melewati setengah materi. Pada enam materi contoh, materi 1–3 memakai satu putaran selama 3 detik dengan zona aman 18% lingkaran. Materi 4–6 makin cepat dan zona aman makin kecil, hingga 1,8 detik dan 10% pada materi terakhir. Nilai awal dan akhir dapat diatur pada node Qte dalam scene `class_lesson.tscn`. Kesulitan mengikuti urutan asli materi, sehingga melanjutkan sesi yang terputus tidak mengembalikannya ke tingkat awal.

Materi ditandai sudah dilewati saat QTE-nya mulai dan status ini disimpan sebelum pemain menjawab. Materi yang sudah dilewati, termasuk yang QTE-nya gagal atau terputus ketika game ditutup, tidak dapat diulang di kelas. Masuk ulang hanya melanjutkan materi yang benar-benar belum dilewati. Bagian catatan kosong nantinya hanya dapat dilengkapi melalui belajar di asrama; mekanik asrama belum diimplementasikan.

Setelah seluruh catatan lengkap, kelas langsung memberikan blueprint `sediment_sorter`. Tombol **Buka blueprint** menampilkan gambar utuh. Jika pemberian gagal disimpan, tombol **Coba simpan lagi** dapat digunakan tanpa mengulang kelas.

## Integrasi kelas, Library, dan lab

`ClassroomProgress` menyimpan catatan dan indeks materi yang sudah dilewati di `user://classroom_notes.cfg` versi 2. Berkas versi 1 tetap dibaca. `begin_material()` menandai satu kesempatan QTE, sedangkan `finish_material()` hanya menerima hasil dari kesempatan yang sedang berjalan. `unlock_blueprint()` tetap memerlukan semua catatan.

Kelas dan buku blueprint di Library menggunakan `ProjectBlueprints.grant(blueprint_id)`. Project dan pembaca kartu Workshop menggunakan `ProjectBlueprints.is_owned(blueprint_id)`. Status kepemilikan memakai kunci `completed` pada bagian ID blueprint di `user://blueprint_progress.cfg`. Kepemilikan lama tetap dibaca. Progres pemasangan sebagian tetap bisa menerima blueprint utuh ketika persyaratan hadiah terpenuhi.

## Ujian kelas dan waktu

Satu minggu adalah tujuh hari game: hari 1–7 adalah minggu 1, hari 50–56 adalah minggu 8, dan hari 106–112 adalah minggu 16. Nomor minggu dibaca saat masuk kelas. Pada minggu 8 tersedia UTS dan minggu 16 tersedia UAS. Dekati komputer di sisi kanan ruang kelas, lalu tekan **E** untuk membuka ujian. Kegiatan kelas tidak dijalankan di scene ruang laboratorium.

UTS dan UAS masing-masing menggunakan sepuluh soal pilihan ganda dari resource `midterm.tres` dan `final.tres`. Durasi maksimalnya 600 detik nyata. Pemain dapat mengumpulkan lebih awal; jawaban kosong bernilai nol. Saat waktu habis, jawaban dikunci dan dikumpulkan otomatis. Hasil disimpan melalui sistem LMS yang sama. Membuka ujian yang sudah selesai menampilkan hasil, bukan memulai percobaan baru. Draf jawaban dan tenggat waktu nyata disimpan untuk melanjutkan sesi yang terputus; penghitung waktu tetap mengikuti tenggat tersebut.

Selama ujian kelas, `GameClock.begin_assessment()` menghentikan waktu game. Kuis LMS memakai token terpisah dan menambah 10 menit game saat hasil tersimpan, tanpa biaya saat dibatalkan. Tugas LMS tetap mengikuti jam normal. `end_assessment()` menambahkan durasi akses sebenarnya ke jam game, termasuk ketika sesi ditutup. Pecahan menit dibawa ke sesi berikutnya. Pengerjaan enam menit mulai 14.30 menghasilkan 14.36. Fungsi ini aman terhadap pelepasan berulang dan sesi yang saling bertumpuk. Jam dan pecahan menit kini ikut disimpan dalam autosave sesi.

## New Game, Load, dan autosave

Game dimulai dari main menu. **New Game** langsung membuka halaman kampus pada hari 1 pukul 06.00 jika belum ada progres. Bila sudah ada data, muncul pertanyaan **apakah anda yakin ingin memulai kehidupan baru?** dengan subheader **seluruh data yang anda save sebelumnya akan hilang**. **Batal** mempertahankan data; **Ya, mulai baru** menghapus catatan kelas, status materi, blueprint, hasil LMS/ujian, draf ujian, dan catatan desktop. Pengaturan volume dan resolusi tetap dipertahankan.

`GameSave` menyimpan checkpoint versi 2 ke `user://game_save.cfg` setiap dua detik selama permainan, ketika memasuki world, setelah perubahan catatan/blueprint, dan ketika jendela game ditutup. Checkpoint memuat scene, posisi dan arah karakter, kalender global, serta salinan data progres permainan. Penulisan rutin memakai file sementara lalu mengganti checkpoint sebelumnya. Pergantian scene yang sedang berjalan tidak ditangkap sebagai lokasi akhir.

**Load** langsung memulihkan checkpoint terakhir dan masuk ke lokasi tersimpan, tanpa membuka daftar save. Tombol nonaktif jika tidak ada checkpoint atau progres lama yang dapat dibaca. Posisi dibatasi di luar trigger teleport tepi world agar Load tidak langsung memindahkan pemain lagi. Scene desktop juga dapat dilanjutkan, dengan aplikasi desktop dibuka kembali melalui launcher seperti biasa.

Save sebelum adanya checkpoint sesi belum mempunyai informasi lokasi dan kalender. Progres lama tersebut tetap dapat dimuat dari titik awal halaman kampus, kemudian memperoleh checkpoint baru. Materi QTE yang sudah dilewati tetap terkunci; pemuatan scene kelas tidak mengulang QTE yang sudah terlewat. Penggantian data saat Load atau New Game memakai cadangan sementara dan mengembalikan berkas lama apabila operasi berkas gagal.

Untuk menguji minggu ujian tanpa menunggu kalender, atur `week_override` pada node **ClassActivity** di scene kelas menjadi 8 atau 16. Nilai 0 memakai kalender global. Durasi QTE, waktu membaca materi, dan durasi ujian juga merupakan properti yang dapat diatur.

## Mengubah konten

Atur ID, judul, dan tekstur utuh pada resource blueprint desktop, lalu tambahkan resource ke **Blueprints** di `project_app.tscn`. Untuk penghargaan buku, set **Reward Type** ke **Blueprint** dan isi **Blueprint ID** yang sama. Untuk Workshop, isi **Linked Blueprint ID** pada resource puzzle. Pertahankan ID yang sudah dipakai save lama. Resource `scenes/interaction/blueprint/transmission.tres` tetap menyediakan materi kelas dan gambar untuk demo blueprint lama yang terpisah.

## Pemeriksaan

Gunakan Godot 4.7.2 console. Jalankan `--headless --path <project> --script res://tests/classroom_smoke.gd` dengan APPDATA baru dan terisolasi agar tidak menyentuh progres pemain. Jalankan lagi dengan `-- --reload` untuk memeriksa pemuatan catatan, hadiah blueprint, dan nilai dari sesi baru. `tests/side_scroller_smoke.gd` memeriksa interaksi pintu, transisi, dan navigasi world. `tests/blueprint_smoke.gd` tetap menjadi pemeriksaan mandiri komponen blueprint lama.

`tests/game_save_smoke.gd` memeriksa New Game pertama, autosave lokasi, Load langsung, pemulihan progres/waktu, pembatalan konfirmasi, reset seluruh progres, dan pengaturan yang tetap tersimpan. Jalankan kembali dengan `-- --reload` untuk menguji sesi baru; gunakan APPDATA lain dengan `-- --legacy` untuk memeriksa migrasi progres lama. `tests/main_menu_smoke.gd` memeriksa Settings dan perilaku tombol menu.
