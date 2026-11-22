# Pembaruan map kampus

Map luar kini satu scene tanpa portal ujung layar, asrama memakai kamar 203, dan kamar mempertahankan ukuran gambar asli. Lihat [map kampus](campus-world.md) dan [asrama](dorm-room.md) untuk perilaku terbaru. Catatan berikut mendokumentasikan tahap penyatuan laboratorium sebelumnya.

# Yohan dan gedung kuliah/laboratorium

New Game langsung memulai permainan sebagai Yohan tanpa dialog input nama. Jika ada save, konfirmasi kehidupan baru tetap tampil sebelum data diganti. ID 12 digit berawalan 607 tetap dibuat acak. Save lama dengan nama berbeda dimuat sebagai Yohan, sambil mempertahankan ID dan progresnya.

Gedung kuliah dan laboratorium kini satu lokasi. Pintu kampus menuju F1, tangga naik menghubungkan F1-F2-F3, dan pintu ganda bertanda LABORATORIUM pada F3 menuju campus_lab_room.tscn. Ruang kelas tetap dapat diakses dari F1 dan F2. Pintu laboratorium tidak memakai batas jam masuk kelas. Keluar laboratorium kembali ke F3, sedangkan keluar meja rakit kembali ke laboratorium.

Area luar sekarang menghubungkan kampus dengan asrama melalui kedua arah. campus_lab.tscn tetap tersedia sebagai alias lorong F3 untuk kompatibilitas save lama; scene itu tidak lagi menjadi gedung luar terpisah. Scene kelas F3 lama juga tetap tersedia untuk save yang sudah berada di sana.

Validasi fitur: campus_identity_smoke dan mode --reload lulus, termasuk New Game tanpa input, konfirmasi/cancel, ID acak, migrasi nama save lama, akses lab setelah jam kelas, meja rakit dan posisi kembali, serta save gedung lab lama. Pengujian grafis Compatibility juga lulus. main_menu, main_menu --reload, resolution, side_scroller, classroom_corridor, dan classroom_corridor --reload lulus pada save terisolasi.

Suite menyeluruh belum lulus: career_smoke masih mengasumsikan delapan semester, academic_flow memakai asumsi kelas lama, dan semester_loop memiliki pemeriksaan waktu awal yang terlalu tepat saat clock sudah mulai berjalan. Kalender dan kurikulum hasil pull tidak diubah oleh perubahan ini. Log fitur grafis: .godot/campus-identity-final-graphics/run.log.

Perubahan belum di-commit atau di-push. Build Windows sebelumnya belum diperbarui.
