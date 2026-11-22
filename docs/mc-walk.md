# Animasi jalan MC

Enam PNG pengguna dari MCJalanIcikiwir disalin tanpa perubahan ke assets/characters/mc/walk, mengikuti nama 1.png sampai 6.png. SpriteFrames yang sudah dipakai player kini menyediakan animasi walk looping pada 8 FPS, serta mempertahankan tujuh frame idle sebelumnya.

Berjalan atau berlari memainkan walk. Setelah berhenti, MC memainkan side_idle tujuh frame berurutan 1.png sampai 7.png dari SideIdleMC, looping pada 7 FPS. Sesudah tiga detik tanpa berjalan, animasi berganti ke idle depan melalui crossfade 0,2 detik. Berjalan lagi memulai ulang waktu tunggu dan membatalkan crossfade. Durasi side_idle_seconds dan idle_blend_seconds dapat diatur di Inspector.

Saat duduk/belajar, animasi memakai pose sit dari Tak berjudul16_20261122191014.png dengan gerak napas ringan. Waktu side idle dan crossfade dibersihkan. Setelah berdiri, posisi sprite serta skala dipulihkan. Kecepatan gerak, collision, dan penyimpanan arah tetap menggunakan mekanik sebelumnya.

Aset jalan dan side idle aslinya menghadap kiri. Flip pada sprite walk/side_idle dipadukan dengan arah Visual yang sudah dipakai gerakan dan save/Load; hasilnya menghadap kanan setelah bergerak kanan, dan kiri setelah bergerak kiri. Idle depan memakai orientasi sebelumnya. Profil tetap menggunakan animasi idle depan.

tests/mc_idle_smoke.gd memeriksa urutan frame, looping, kedua arah, side idle sebelum tiga detik, idle depan sesudah tiga detik, pengulangan waktu tunggu saat berjalan lagi, duduk, dan collision. Opsi --capture menghasilkan preview jalan kiri/kanan, side idle kiri/kanan, dan idle depan di .godot dengan kamera diperbesar khusus pengujian.

Pemeriksaan grafis crossfade idle, pose duduk, serta susunan kelas lulus. Suite penuh: 22 lulus, 0 gagal, termasuk jeda tiga detik, crossfade bertahap, restart jeda saat berjalan lagi, save/Load, duduk/QTE, teleport setelah catatan akhir, serta tangga naik/turun terpisah. Log: .godot/production-validation/1795350343963675100. PNG asli pengguna dipertahankan tanpa perubahan.

Perubahan animasi dan pemisahan tangga tetap lokal, belum di-commit atau di-push. Build Windows sebelumnya belum diperbarui untuk perubahan ini.
