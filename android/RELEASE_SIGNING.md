# Android Release Signing Documentation - RenChat

## Release Keystore Information
- **Keystore File**: `android/app/upload-keystore.jks`
- **Alias**: `upload`
- **Store Password**: `RenChatRelease2026!`
- **Key Password**: `RenChatRelease2026!`
- **Validity**: 10,000 days (until March 18, 2054)

## Certificate Fingerprints (for Firebase & Google Cloud Console)
- **SHA-1**:
  `A7:B7:14:BF:A2:6F:EF:5D:A4:EA:E4:FC:6A:94:6A:4F:5C:D1:71:14`
- **SHA-256**:
  `50:6E:6B:FA:F1:E1:45:E9:3A:39:FB:D7:E0:6F:E9:FC:7B:4B:DF:C7:93:F2:0B:45:D4:24:4D:8F:79:9F:2A:06`

> **PENTING**:
> Daftarkan kedua fingerprint di atas ke **Firebase Console > Project Settings > General > Your Apps > Android (com.chat.messenger) > Add Fingerprint** agar fitur **Google Sign-In** dan **Firebase Phone Auth / App Check** dapat berjalan tanpa kendala pada build APK Release resmi ini.

---

## Konfigurasi GitHub Actions CI/CD (Otomatisasi Rilis)

Workflow [.github/workflows/release.yml](.github/workflows/release.yml) telah dikonfigurasi untuk mengompilasi APK dan mempublikasikannya otomatis ke GitHub Releases setiap kali Anda membuat Git Tag baru (misalnya `v1.2.0`).

### Repository Secrets yang Perlu Didaftarkan di GitHub:
Buka **GitHub Repository > Settings > Secrets and variables > Actions > New repository secret**:

1. **`KEYSTORE_BASE64`**:
   String Base64 dari file `android/app/upload-keystore.jks`. Anda bisa mendapatkannya dengan perintah:
   ```bash
   base64 -w 0 android/app/upload-keystore.jks
   ```
   *(Atau di PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/upload-keystore.jks"))`)*

2. **`STORE_PASSWORD`**:
   `RenChatRelease2026!`

3. **`KEY_PASSWORD`**:
   `RenChatRelease2026!`

4. **`KEY_ALIAS`**:
   `upload`

*Catatan: Jika secrets di atas belum didaftarkan, workflow tetap dilengkapi fallback otomatis sehingga build rilis tidak akan gagal.*

---

## Cara Membuat Rilis Baru dengan Tag Git

Cukup buat tag baru dan push ke GitHub:
```bash
git tag v1.2.0
git push origin v1.2.0
```
GitHub Actions akan secara otomatis menjalankan proses kompilasi, penandatanganan APK dengan keystore resmi, pembuatan checksum SHA-256, dan pembuatan rilis di GitHub dengan file `RenChat.apk` siap unduh.

