# Lorong kelas F1, F2, dan F3

Pintu utama kampus sekarang menuju lorong F1. Pintu ganda pada setiap lorong memasuki kelas di lantai tersebut; keluar kelas kembali ke lorong yang sama. Akses keluar gedung berada di sisi kiri F1.

Setelah pemain menyelesaikan kelas dan menutup catatan akhir, pemain otomatis kembali ke lorong lantai yang sama melalui fade. Popup dapat dibaca sebelum perpindahan. Membaca ulang catatan lama tetap berlangsung di kelas.

- F1 memakai Tak berjudul63_20261122144242.png. Dekati tangga kanan, lalu tekan E untuk naik ke F2.
- F2 memakai Tak berjudul63_20261122144208.png. E pada tangga naik di kanan membawa pemain ke F3. E pada akses tangga turun di sebelah kirinya membawa pemain ke F1. Kedua area terpisah dan tidak lagi membuka pilihan lantai.
- F3 memakai Tak berjudul65_20261122142712.png. Pintu hijau di kanan dipakai sebagai akses tangga turun ke F2 melalui E.

Interaksi menampilkan bubble dan memakai fade yang sudah ada. Menyentuh area tangga atau menekan W tidak memindahkan pemain. Setelah naik, pemain tiba di akses tangga turun pada lantai tujuan; setelah turun, pemain tiba di tangga naik. F1 tidak menyediakan turun dan F3 tidak menyediakan naik. Gambar disalin tanpa mengubah file asli dan ditampilkan dengan rasio yang dipertahankan. Player memakai z-index 1.

Scene lorong: scenes/movement/classroom_corridor_floor1.tscn, classroom_corridor_floor2.tscn, dan classroom_corridor_floor3.tscn. Kelas lantai 2 dan 3 memakai scene turunan untuk menyimpan lantai asal saat save/Load. Progres materi tetap memakai kurikulum global yang sama.

Validasi lorong awal: 21 pemeriksaan lulus tanpa kegagalan, termasuk perpindahan dua arah melalui E, pintu kelas tiap lantai, Load dari kelas lantai 3, dan keluar ke kampus. Log: .godot/production-validation/1795345541844139100. Pemeriksaan grafis F1/F2/F3 lulus. Preview berada di .godot/corridor-f1.png, corridor-f2.png, dan corridor-f3.png. Semua save pengujian terisolasi dari data pengguna.

Pengujian tambahan tests/classroom_exit_smoke.gd memeriksa bahwa perpindahan menunggu popup catatan ditutup, kembali ke lorong F1/F2/F3 yang benar melalui fade, mempertahankan bagian catatan kosong serta save/Load, dan tidak berpindah saat membaca ulang catatan atau membatalkan kelas. Pengujian ini juga lulus dengan renderer grafis Compatibility.

Suite terbaru setelah pemisahan tangga naik/turun, animasi jalan, dan side idle: 22 lulus, 0 gagal. Log: .godot/production-validation/1795348219441739500. Tes memastikan area naik dan turun tidak bertumpuk, batas lantai aman, dan posisi tiba sesuai arah tangga.

Perubahan ini masih lokal dan belum di-commit atau di-push. ZIP Windows sebelumnya belum diperbarui untuk lorong ini.
