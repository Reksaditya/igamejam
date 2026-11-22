# Validasi implementasi Deadline

## Keputusan yang digunakan

- Delapan semester mengikuti kurikulum pengguna, masing-masing 16 minggu dengan tujuh hari per minggu.
- Waktu normal: 12 menit nyata per hari game. Kelas menambah tepat dua jam; kuis/ujian menambah durasi akses nyata.
- Bobot IPK: tugas 10%, kuis 15%, UTS 22,5%, UAS 22,5%, proyek 30%. Skor persentase dibagi 25.
- Biaya energi: kelas 15, tugas/kuis 5, ujian 30, proyek 20. Belajar ulang memakai 5 energi.
- Tidur delapan jam memulihkan energi; keterlambatan sesudah 22.00 mengurangi pemulihan 10 poin per jam.
- Profil, Status, dan Jurnal tetap menjalankan waktu. Settings menghentikan waktu. Lompatan tetap dinonaktifkan, sesuai perubahan pengguna sebelumnya.
- Nama diminta saat New Game; ID berawalan 607 dengan total 12 digit. Aset yang belum disediakan menggunakan dummy.

## Tahap dan hasil

| Tahap | Commit | Hasil |
|---|---|---|
| 1 | 356590b | Kurikulum delapan semester, data per minggu, energi, nilai, catatan, potongan, dan autosave |
| 2 | 3456e4c | Kelas/QTE kurikulum, LMS mingguan, draf, tenggat, UTS/UAS, riwayat, dan IPK |
| 3 | 1de5bbe | Asrama dua lantai/kamar 210, tidur, komputer, Library, Project 3×3, dan Blocks |
| 4 | 233fa7d | Bengkel, enam komponen, QTE perakitan, rancangan akhir, ruang dosen, dan penilaian |
| 5 | Commit dokumen ini | Cerita, NPC, satpam, blur, ending, pergantian minggu, dan validasi gabungan |

Satpam mencatat pelanggaran jam malam meskipun profil sedang terbuka; menunggu sampai pagi dalam popup tidak menghapus pelanggaran. Riwayat LMS menampilkan semester, minggu, dan jenis penilaian dalam label yang dapat dibaca pemain.

Penilaian proyek sementara: 100 dikurangi lima poin per QTE gagal, maksimal pengurangan 40. Aturan ini disampaikan pada laporan tahap 4. Rancangan akhir memilih mekanisme, masukan, dan sumber energi; pilihan tersebut digunakan pada daftar komponen perakitan.

## Pemeriksaan otomatis

Runner: tools/run_production_tests.py. Semua pengujian memakai APPDATA/LOCALAPPDATA/XDG_DATA_HOME terisolasi di .godot/production-validation; tidak menyentuh save permainan pengguna.

| Pemeriksaan | Cakupan | Hasil |
|---|---|---|
| career | 128 kombinasi semester/minggu; 10 soal unik dan empat pilihan; biaya energi sekali; pemulihan; blueprint; IPK; kelas +120 menit; pergantian minggu/semester | Lolos |
| academic_flow | Kelas aktif; QTE di kepala; kegagalan catatan; larangan pengulangan; draf kuis; enam menit nyata; UTS; timeout; tenggat LMS | Lolos |
| academic_flow --reload | Catatan dan nilai dari proses baru | Lolos |
| dorm_study | Tidur terlambat; Library/keyword; 3×3; pintu empat lokasi asrama; komputer; Blocks; kembali ke kamar | Lolos |
| dorm_study --reload | Lokasi kamar, catatan lengkap, blueprint | Lolos |
| workshop_flow | Blueprint wajib; komponen salah; QTE gagal/berhasil; nilai 95; pengumpulan sekali; rancangan dan proyek akhir | Lolos |
| world_life | New Game normal; empat chapter; efek sekali; satpam 22.00; asrama aman; blur; tidur di kelas; tiga kondisi ending; Load ending | Lolos |
| game_save | New Game/Load; posisi; progres; reset; pembatalan; pengaturan tetap | Lolos |
| game_save --reload | Checkpoint dari proses baru | Lolos |
| main_menu | Tombol Load; pengaturan; konfirmasi; pembatalan | Lolos |
| main_menu --reload | Pengaturan dan progres dari proses baru | Lolos |
| player_profile | Nama/ID; status; waktu profil dan Settings; jurnal/filter; migrasi save versi 1 | Lolos |
| resolution | Semua ukuran langsung diterapkan, dipertahankan, tanpa mengubah volume yang belum disimpan | Lolos |
| mc_idle | Tujuh frame sesuai urutan dan looping idle | Lolos |
| blueprint | Kompatibilitas komponen enam potongan lama | Lolos |
| blueprint --reload | Progres blueprint lama dari proses baru | Lolos |
| side_scroller | Gerakan; portal tiga world; E; pintu; interior; fade; jam HUD; tidak melompat | Lolos |

Hasil suite terakhir: 17 lulus, 0 gagal. Log tersedia di .godot/production-validation/1795324494139777000. classroom_smoke kini menjalankan pemeriksaan academic_flow, menggantikan asumsi enam materi contoh untuk seluruh permainan.

## Pemeriksaan grafis

Kelas dan QTE, kuis, desktop/Library/Project, bengkel, profil/Settings pada jendela kecil, pergantian resolusi aktual, blur kewarasan, dan Happy Ending telah dijalankan dengan renderer grafis. Alur cerita sampai ending juga lolos pada renderer bawaan Forward+ / D3D12, selain pemeriksaan Compatibility / OpenGL. HUD tetap tajam saat dunia blur. QTE bengkel memakai popup tersendiri di tengah layar agar lingkaran dan zona aman tidak terpotong; alur bengkel diuji ulang sesudah perbaikan tampilan. Happy Ending memiliki dua adegan dummy: ziarah bersama ayah dan perjalanan sesudahnya.

## Pemetaan GDD

- Simulasi sampai kelulusan: kalender delapan semester, kurikulum, nilai, proyek akhir, dan tiga ending.
- Kelas: duduk, QTE tidak menentu, kesulitan meningkat, catatan kosong, tidak mengulang materi, dan ujian minggu 8/16.
- Komputer: tugas/kuis mingguan 10 soal, tenggat enam hari, riwayat, Library/keyword, Project 3×3, Blocks, serta aplikasi desktop terdahulu.
- Bengkel dan dosen: mengambil/memasang komponen, QTE sambungan, mesin lengkap, pengumpulan dan penilaian.
- Status: energi, istirahat, kewarasan/tekanan, blur pada 80, tidur saat energi habis, dan IPK otomatis.
- Dunia: side scroller, E/bubble, fade, portal transparan, asrama dua lantai/kamar 210, ruang dosen, NPC, dan satpam malam.
- Cerita: empat chapter, kabar kehilangan di semester lima, pemulihan tekad, ending sesuai proyek akhir/IPK, serta adegan ziarah/perjalanan.
- Finishing: identitas New Game, autosave/Load, reset, jurnal, menu, Settings dalam profil, resolusi langsung, dan dokumentasi alur.

Instruksi pengguna menggantikan bagian GDD yang bertentangan: tidak ada lompatan; nama pemain dapat dipilih; kalender memakai 16 minggu per semester; kuis/ujian memakai durasi akses sebenarnya; Profil tidak menghentikan waktu kecuali Settings. Tombol Buka Desktop di HUD tetap dihapus: akses komputer melalui objek di kamar.

Panduan menjalankan seluruh alur: docs/blueprint.md. Kualitas visual lingkungan, NPC, mesin, dan cutscene masih dummy sesuai izin; dokumen ini tidak menyatakan bahwa aset final atau build distribusi telah dibuat.
