# RenChat (RendChat) 💬

A modern, high-performance messaging and calling application inspired by WhatsApp, built with Flutter, Firebase, and real-time cloud sync.

---

## ✨ Fitur Unggulan

- 🔐 **Autentikasi Bersih & Google Sign-In**: Masuk dengan Google 1-klik atau Email/Password dengan verifikasi token Play Services.
- 💬 **Real-time Messaging**: Obrolan instan dengan dukungan teks, gambar, video, dokumen, emoji, dan audio.
- 🚫 **Block & Unblock Kontak**: Blokir kontak yang tidak diinginkan langsung dari obrolan, info kontak, atau pengaturan privasi.
- 🔒 **Kunci Chat (Chat Lock & PIN)**: Lindungi obrolan rahasia dengan PIN 4 digit dan folder obrolan terkunci.
- 📞 **Panggilan Suara & Video**: Panggilan berkualitas tinggi dengan antarmuka WhatsApp modern.
- 🔄 **Sistem Pembaruan Otomatis (Auto-Update APK)**: Aplikasi otomatis mendeteksi rilis versi baru dari repository GitHub ini (`version.json` & Releases) dan menampilkan dialog pembaruan 1-klik langsung di HP Android.
- 🎨 **Tampilan Modern WhatsApp / RenChat**: Desain dark mode elegan, responsive di Web dan Android.

---

## 🚀 Struktur Pembaruan Otomatis (Auto-Update)

Aplikasi memeriksa versi terbaru melalui berkas [`version.json`](version.json) di repository ini:

```json
{
  "version": "1.0.0",
  "version_code": 1,
  "title": "RenChat Update",
  "release_notes": "• Fitur baru: Block & Unblock kontak\n• Pembaruan keamanan & performa lebih cepat\n• Perbaikan antarmuka RenChat",
  "apk_url": "https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk",
  "fallback_url": "https://github.com/rendihomeofficial-sudo/RendChat"
}
```

Ketika Anda mengunggah versi baru (misal `1.0.1` / `version_code: 2`), seluruh HP pengguna yang telah menginstal RenChat akan otomatis menampilkan pop-up dialog pembaruan untuk mengunduh APK terbaru!

---

## 🛠️ Cara Menjalankan & Build

```bash
# Pasang dependensi
flutter pub get

# Jalankan di Web
flutter run -d chrome

# Kompilasi APK Android
flutter build apk --debug
# atau release
flutter build apk --release
```

---

*Dikembangkan untuk RenChat Messenger.*
