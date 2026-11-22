# Build Windows

Versi dasar gameplay: commit lokal `1f06ec6`. Gunakan Godot 4.7.2 dan paket export template resmi dengan versi yang sama.

```powershell
python tools/build_windows.py --godot "C:/lokasi/Godot_v4.7.2-stable_win64_console.exe" --templates "C:/lokasi/Godot_v4.7.2-stable_export_templates.tpz"
```

Preset `Windows Desktop` menghasilkan executable x86_64 dan PCK terpisah. Tool memasang template ke cache project `.godot/windows-export`, sehingga tidak mengganti template atau save pengguna. Ekspor berjalan dari salinan sementara tanpa folder internal Git dan dengan plugin editor dinonaktifkan; konfigurasi editor project asli tetap sama. Contoh scene C# dari Dialogue Manager dikecualikan karena game menggunakan GDScript. Hasil ada di `.godot/builds/Deadline-Windows.zip`; ekstrak seluruh ZIP sebelum menjalankan `Deadline.exe`.

Folder pengembangan, tes, dokumentasi, dan addon MCP editor dikecualikan dari paket permainan. Lisensi addon ikut disertakan. Binary, template, dan log tidak masuk Git.

Preset memakai ekspor script mode 1. Tool mengekspor PCK release melalui `--export-pack`, kemudian memasangkannya dengan executable template Windows release resmi yang versinya sama. Executable tidak dimodifikasi, sehingga memakai ikon dan metadata template bawaan. Engine terpasang dapat mengalami native crash setelah ekspor pertama pada salinan baru; tool mengulang sekali hanya untuk kode crash tersebut setelah penulisan paket selesai tanpa error. Kegagalan berikutnya tetap menghentikan build. Semua log disimpan.

Validasi source menggunakan `python tools/run_production_tests.py --godot <executable>`. Jalankan juga executable hasil ekspor untuk memastikan resource yang diperlukan tersedia di PCK. Gunakan APPDATA dan LOCALAPPDATA sementara saat pengujian agar save pemain tidak berubah.

Runner menerima `--pack <Deadline.pck>` untuk menjalankan suite pada resource hasil ekspor menggunakan engine editor. `tests/windows_export_smoke.gd` juga dapat dijalankan melalui engine editor dengan `--main-pack <Deadline.pck> --script <lokasi absolut helper>`. Helper tersebut dikecualikan dari build dan tidak menjadi menu permainan.
