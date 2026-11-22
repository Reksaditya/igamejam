# Penyelesaian Deadline

Keputusan produksi: delapan semester, 16 minggu per semester, tujuh hari per minggu. Satu hari game berlangsung 12 menit nyata. Kelas menambah tepat 120 menit game. Kuis dan ujian memakai durasi nyata dan menambah durasi akses yang sebenarnya.

Bobot nilai: tugas 10%, kuis 15%, UTS 22,5%, UAS 22,5%, proyek 30%. Nilai persentase dibagi 25 menjadi IPK. Tugas dan kuis dirata-rata atas 16 minggu; tugas yang tidak dikumpulkan bernilai nol. Energi: kelas 15, tugas/kuis 5, ujian 30, proyek 20. Belajar ulang menghabiskan 5 energi.

## Tahap 1: fondasi akademik

Kurikulum memuat materi konseptual, keyword, pertanyaan pilihan ganda, dan soal hitungan untuk seluruh semester. CareerProgress menyimpan catatan per minggu, percobaan yang tidak bisa diulang di kelas, pemulihan melalui belajar, sembilan potongan blueprint per semester, perakitan bertahap, serta nilai. Progres ini termasuk dalam reset New Game dan autosave tanpa membuang progres lama.

Validasi: career_smoke memeriksa 128 kombinasi semester/minggu, masing-masing 10 soal dengan satu jawaban benar, biaya energi sekali per aktivitas, kegagalan kelas dan pemulihan, batasan blueprint, IPK maksimum 4, dan penambahan kelas tepat dua jam. Tahap ini belum mengganti alur scene kelas; penyambungan UI dilakukan pada tahap 2.

## Tahap 2: kelas dan LMS

Scene kelas memakai materi semester/minggu aktif, tiga kesempatan QTE di atas kepala, jeda awal empat detik dan jeda berikutnya acak. Materi yang dilewati tidak diulang. Kelas menghabiskan tepat dua jam. LMS di Word Explorer memakai tugas dan kuis kurikulum dengan sepuluh soal, tenggat enam hari, pergantian mingguan, dan riwayat nilai. Kuis/UTS/UAS memakai batas 600 detik nyata, draf jawaban persisten, pengumpulan otomatis, serta penambahan waktu game sesuai durasi akses. UTS dan UAS berulang pada minggu 8 dan 16 tiap semester. Tugas tidak memiliki timer pengerjaan.

Validasi: academic_flow_smoke memeriksa alur kelas, kegagalan catatan, larangan mengulang, pemulihan draf, durasi enam menit nyata, UTS, timeout, deadline, dan halaman LMS. career_smoke memeriksa data serta bobot nilai. Aplikasi desktop baru dapat diakses kembali dari komputer asrama setelah tahap 3.

## Tahap berikutnya

## Tahap 4: bengkel dan pengumpulan proyek

Meja bengkel dapat diakses dengan E di ruang laboratorium. Tiap semester memiliki enam komponen sesuai kurikulum. Pemain mengambil komponen yang diminta objective, memasangnya pada dudukan, lalu menyelesaikan QTE. Komponen yang salah ditolak; QTE gagal mengembalikan komponen ke rak. Blueprint sembilan bagian harus lengkap sebelum perakitan. Progres enam komponen dan kegagalan sambungan disimpan. Preview mesin menampilkan dudukan dan komponen yang sudah dipasang.

Pada semester delapan pemain memilih mekanisme, masukan, dan sumber energi dari komponen terdahulu. Pilihan rancangan disimpan dan memengaruhi daftar komponen proyek akhir. Ruang dosen memiliki pintu dari halaman kampus; dosen menerima mesin lengkap dan memberikan nilai 100 dikurangi lima per kegagalan QTE (pengurangan maksimum 40). Pengumpulan hanya sekali dan memperbarui IPK serta riwayat LMS.

Validasi: workshop_flow_smoke memeriksa kunci blueprint, pengambilan komponen, QTE gagal/berhasil, enam tahap perakitan, nilai 95 setelah satu kegagalan, penolakan pengumpulan ganda, rancangan semester delapan, dan persistensi proyek akhir.

## Tahap 3: asrama dan aplikasi komputer

Asrama memiliki eksterior, lantai 1, lantai 2, dan kamar 210 dengan tempat tidur serta meja komputer. Interaksi E memakai area fisik, bukan tombol desktop di HUD. Mematikan komputer kembali ke kamar melalui fade. Library menampilkan materi kelas yang selesai atau minggu yang terlewat; keyword yang benar memulihkan catatan dan memberikan potongan. Project menampilkan siluet 3×3, potongan yang dimiliki, dan penempatan yang memeriksa kecocokan. Blocks diadaptasi dari implementasi origin/main dengan penempatan, pembersihan garis, skor, dan kondisi kehabisan langkah. Waktu normal tetap berjalan pada komputer.

Tidur delapan jam memulihkan energi dengan penalti terlambat, sedangkan istirahat singkat memulihkan sebagian energi dan mencatat kekurangan tidur. Kewarasan kembali ke 50. Tidur memajukan kalender dan memperbarui IPK semester aktif.

Validasi: dorm_study_smoke menguji penalti tidur pukul 23.00, pemulihan melalui sembilan bacaan, kecocokan puzzle, empat lokasi asrama, interaksi komputer, penempatan Blocks, kembali dari desktop, dan pemuatan kembali progres.

5. Energi/kewarasan, satpam, NPC, cerita, tiga ending, dan pemeriksaan integrasi.
