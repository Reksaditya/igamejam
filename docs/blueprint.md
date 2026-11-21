# Mekanik blueprint

Jalankan scene utama lalu pilih **Project Blueprint**, atau buka aplikasi dengan nama yang sama dari desktop. Baca materi, jawab pertanyaan, lalu buka popup blueprint. Pilih potongan yang diperoleh dan klik bagian siluet yang sesuai. Tab, tombol panah, dan Enter juga dapat digunakan untuk navigasi kontrol. Escape menutup popup blueprint.

Blueprint contoh terdiri dari enam potongan rancangan transmisi. Jawaban salah dan lokasi pemasangan salah tidak memberikan atau menghabiskan potongan. Materi yang sudah selesai tidak memberi potongan tambahan. Progres tersimpan di `user://blueprint_progress.cfg`; menutup popup, aplikasi, atau game tidak menghapusnya. Kegagalan menyimpan ditampilkan dan perubahan dibatalkan agar dapat dicoba lagi.

## Integrasi kelas dan lab

Sistem kelas belum ada dalam proyek. Setelah aktivitas kelas benar-benar selesai, panggil fungsi yang sama dengan aktivitas belajar desktop:

```gdscript
var error := BlueprintProgress.complete_study("transmission_motor")
```

ID materi lain: `transmission_gear`, `transmission_shaft`, `transmission_mount`, `transmission_base`, `transmission_bearing`. Pemanggil perlu menangani nilai `Error` jika penyimpanan gagal. Pemanggilan berulang aman.

Lab dapat membaca `BlueprintProgress.is_complete()` dan mendengarkan `BlueprintProgress.project_completed(project_id)`. Sinyal hanya muncul saat pemasangan terakhir berhasil; baca status awal juga saat menghubungkan lab setelah pergantian scene. Blueprint hanya membuka kesiapan rancangan; simulasi perakitan mesin bukan bagian perubahan ini.

## Mengubah konten

`scenes/interaction/blueprint/transmission.tres` berisi gambar, grid, dan materi bertipe Resource, mengikuti pola resource LMS. Jumlah materi harus sama dengan `columns * rows`; setiap materi memetakan satu potongan menurut urutan kiri ke kanan, atas ke bawah. Pertahankan ID dan urutan materi agar progres tersimpan tetap sesuai. SVG contoh dapat diganti dengan ilustrasi blueprint produksi.

## Pemeriksaan

Gunakan Godot 4.7.2 console. Jalankan `--headless --path <project> --script res://tests/blueprint_smoke.gd` dengan APPDATA terisolasi agar tidak menyentuh progres pemain. Jalankan lagi dengan `-- --reload` untuk memeriksa pemuatan progres dari sesi baru.
