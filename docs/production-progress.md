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

3. Asrama, tidur, komputer, Library, puzzle blueprint 3×3, dan Blocks.
4. Bengkel, QTE perakitan, pengumpulan proyek, dan penilaian dosen.
5. Energi/kewarasan, satpam, NPC, cerita, tiga ending, dan pemeriksaan integrasi.
