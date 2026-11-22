# Background kelas dan kursi

Background menggunakan Tak berjudul67_20261122121106.png dan kursi menggunakan Tak berjudul67_202611221310582.png dari pengguna. File disalin tanpa mengubah isi gambar ke assets/classroom. Background mempertahankan rasio asli; area tambahan di atas dan bawah memakai warna dinding dan lantai. Empat sprite kursi ditempatkan pada kursi yang sudah tampak di gambar, sehingga tidak menambah barisan kursi baru.

Posisi interaksi kursi dari kiri ke kanan: x 266, 555, 820, dan 1095 pada world kelas. Dekati kursi, kemudian tekan E atau klik bubble. Pada minggu kuliah yang materinya belum selesai, pemain duduk dan memulai belajar/QTE. Setelah materi selesai atau pada minggu ujian, E hanya untuk duduk; E berikutnya atau bubble Berdiri mengembalikan gerak. Duduk biasa tidak membuka kembali materi dan tidak memulai QTE.

Sesudah belajar selesai, catatan akhir tetap ditampilkan untuk dibaca. Tombol Kembali ke lorong atau penutupan popup memicu fade dan mengembalikan pemain ke lorong pada lantai kelas tersebut. Catatan yang masih kosong tetap tersimpan. Membaca ulang catatan melalui tombol Review tidak memicu teleport.

Skala visual karakter disesuaikan khusus di kelas; posisi QTE mengikuti bagian atas sprite. Komputer ujian memakai laptop yang sudah tergambar pada meja dosen. Ruang lab tetap memakai background dummy dan menonaktifkan kursi kelas.

Validasi khusus: tests/classroom_seating_smoke.gd menguji seluruh kursi melalui E, QTE saat duduk, penyelesaian materi satu kali, penguncian gerak, berdiri melalui bubble, duduk pada minggu ujian, dan ruang lab. Pengujian memakai save terisolasi. Opsi --capture menyimpan preview ke .godot/classroom-standing.png, .godot/classroom-seated.png, dan .godot/classroom-qte.png.

Paket Windows terbaru lolos 19/19 pemeriksaan, termasuk kursi baru dan regresi akademik, save/load, asrama, lab, cerita, serta portal. Log: .godot/production-validation/1795344499697672800. ZIP lolos CRC, executable hasil ekstrak lolos startup, dan kedua aset identik dengan file asli pengguna.

![QTE pada kursi kelas](previews/classroom-qte.png)
