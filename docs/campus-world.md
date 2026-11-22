# Map kampus dan pencahayaan

Map luar memakai main_world.png pada ukuran asli 3072 × 576 dengan kamera horizontal. Ujung kiri/kanan memiliki batas collision transparan dan tidak memindahkan pemain ke scene lain. Scene utama tetap top_down_movement.tscn; dorm_exterior.tscn hanya dipertahankan untuk kompatibilitas save lama dan dipetakan kembali ke kampus ketika Load.

Tiga gedung memiliki label di kiri pintu dan interaksi E. Gedung kiri menuju asrama; gedung tengah menuju lorong gedung kuliah; gedung kanan adalah perpustakaan dengan label dan popup “Gedung belum tersedia”. Interior tetap scene terpisah. Keluar asrama mengembalikan pemain ke pintu asrama; keluar gedung kuliah kembali ke pintu tengah. Laboratorium tetap berada di lantai 3. Pelaporan proyek tetap tersedia di area lab agar penghapusan pintu ruang dosen di map luar tidak memutus mekanik proyek.

| Waktu | Redup |
|---|---|
| 06.00–18.00 | 0% |
| 18.00–02.00 | Bertambah linear dari 0% ke 40% |
| 02.00–03.00 | 40% |
| 03.00–06.00 | Berkurang linear dari 40% ke 0% |
| Saat tidur | Total 80%, tidak dijumlahkan dengan efek malam |

WorldLighting mengikuti GameClock dan menghaluskan perubahan opacity. Overlay tidak menangkap input dan tetap diproses selama popup tidur menjeda world. Menu popup serta transisi scene tetap dapat digunakan.

Validasi fitur: campus_map_smoke, dorm_room_smoke, side_scroller_smoke, npc_placement_smoke, dan campus_identity_smoke. Pemeriksaan mencakup interaksi E gedung, batas tanpa teleport, ukuran asli, jalur interior dan spawn kembali, save/load sisi kanan kampus, migrasi kamar lama, jadwal redup, serta laptop dan tidur. Capture grafis tersedia di .godot/campus-610.png, .godot/campus-1755.png, .godot/campus-2505.png, .godot/campus-night.png, .godot/dorm-stairs-native.png, dan .godot/dorm-room-sleeping.png.

Perubahan masih lokal; tidak ada commit/push atau pembaruan build Windows pada tahap ini. Suite produksi lengkap belum dinyatakan lulus karena beberapa tes kurikulum lama masih memerlukan penyesuaian terhadap kalender hasil pull.
