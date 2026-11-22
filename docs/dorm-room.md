# Asrama dan kamar 203

Asrama diakses dengan E dari pintu gedung kiri pada map kampus. Tiap lantai memiliki delapan kamar: 101–108 dan 201–208. Kamar pemain adalah 203, setelah 202, memakai aset single_door.png dan warna yang sama dengan kamar lain. Kamar lain terkunci. Pintu keluar di lantai 1 dan pintu turun di lantai 2 memakai aset pintu yang sama. Tangga naik lantai 1 memakai aset stairs.png kiriman pengguna.

Lorong berukuran 3072 unit dengan kamera horizontal. Kamar 203 mempertahankan ukuran asli gambar 2048 × 576 tanpa memperkecil gambar atau furnitur agar masuk satu layar. Kamera mengikuti MC secara horizontal. Background dan lapisan kasur memakai skala 1:1. Ukuran NPC teman, Randomash, Random kid, dan petugas disesuaikan dengan tinggi MC pada map masing-masing.

Kamar memiliki pintu keluar di ujung kiri, kasur bawah yang dapat digunakan untuk tidur, laptop yang membuka desktop melalui E, dan NPC teman di sudut kanan. Kursi pada gambar tidak memiliki interaksi duduk. Pilihan tidur serta pemulihan energi/kewarasan tetap memakai CareerProgress. Selama pose tidur, MC berada di belakang lapisan kasur dan redup layar menjadi total 80%. Setelah bangun, pose dan pencahayaan kembali seperti keadaan world.

Scene aktif adalah dorm_room203.tscn. File dorm_room210.tscn tetap menjadi alias kompatibilitas. GameSave versi 4 menerima save versi 1, 2, dan 3, serta mengarahkan referensi kamar 210 ke kamar 203, termasuk world tujuan kembali dari desktop. Identitas dan progress tetap dipertahankan. Posisi save kamar dan lorong dinormalisasi agar tetap valid pada resolusi berbeda.

Uji terkait: dorm_room_smoke (batas gerak, tiga resolusi, skala asli, tidur, pemulihan energi, redup 80%, laptop, save/load), campus_map_smoke (delapan kamar, jalur masuk/keluar, migrasi save versi 3), dan npc_placement_smoke (penempatan dan ukuran NPC). Pengujian memakai direktori save terisolasi. Build Windows belum diperbarui dan perubahan belum di-commit/push.
