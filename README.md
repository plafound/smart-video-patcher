# Smart Video Patcher

Smart Video Patcher adalah tool berbasis **PowerShell + FFmpeg** untuk melakukan preprocessing video sebelum diunggah ke platform seperti **TikTok** dan **Instagram**.

Tool ini dirancang untuk menangani:

- Video HDR HLG / PQ
- Konversi HDR → SDR
- Mempertahankan HDR
- Smart resolution
- Landscape / portrait / square
- Tidak melakukan crop
- Tidak melakukan upscale
- VFR → CFR
- Konversi codec ke H.264
- Konversi audio ke AAC 48 kHz
- MP4 Fast Start
- Analisis video menggunakan FFprobe
- Pembuatan report hasil processing

> **Catatan:** Smart Video Patcher tidak dapat menjamin bahwa TikTok, Instagram, atau platform lain tidak akan melakukan kompresi/transcoding setelah video diunggah. Tool ini bertujuan menyiapkan file video dengan parameter yang lebih konsisten sebelum proses upload.

---

## Features

### 1. Smart HDR Processing

Saat program dijalankan, pengguna dapat memilih bagaimana video HDR akan diproses:

```text
[1] Pertahankan HDR
[2] Konversi HDR -> SDR
```

### Keep HDR

Jika memilih **Pertahankan HDR**, video HDR tidak akan melalui proses tone mapping.

HDR source dipertahankan dan output menggunakan:

- H.264 High 10
- 10-bit
- `yuv420p10le`
- Metadata warna HDR dipertahankan

### HDR → SDR

Jika memilih **Konversi HDR → SDR**, Smart Video Patcher mendeteksi jenis HDR secara otomatis.

| HDR Type | Tone Mapping |
|----------|--------------|
| HLG | BT.2446A |
| PQ | BT.2390 |
| Generic HDR | BT.2390 |

Engine HDR menggunakan **libplacebo** dengan:

- Peak Detection
- Gamut Mapping
- Output Rec.709 SDR

---

## 2. Smart Resolution

Smart Video Patcher menyesuaikan resolusi berdasarkan orientasi video.

Tool **tidak melakukan crop** dan **tidak melakukan upscale**.

Aspect ratio sumber tetap dipertahankan.

### Landscape

Target maksimum:

```text
1920 × 1080
```

### Portrait

Target maksimum:

```text
1080 × 1920
```

### Square

Target maksimum:

```text
1080 × 1080
```

### Downscale Only

Video hanya akan di-downscale jika melebihi target. Video tidak akan di-upscale.

---

## 3. No Crop

Smart Video Patcher tidak melakukan cropping.

Video tetap mempertahankan:

- Aspect ratio
- Komposisi gambar
- Seluruh area frame

---

## 4. Smart Orientation

Tool menganalisis dimensi display video dan metadata rotasi.

Orientasi yang didukung:

```text
LANDSCAPE
PORTRAIT
SQUARE
```

Metadata rotasi juga diperiksa untuk menentukan display orientation.

---

## 5. Smart FPS

Frame rate dianalisis menggunakan FFprobe.

| Source FPS | Target FPS |
|------------|------------|
| ≥ 59 FPS | 60 FPS |
| ≥ 49 FPS | 50 FPS |
| ≥ 29 FPS | 30 FPS |
| ≥ 23 FPS | 24 FPS |
| < 23 FPS | Dibulatkan |

Jika video terdeteksi sebagai **VFR (Variable Frame Rate)**, video akan dikonversi menjadi **CFR (Constant Frame Rate)**.

---

## 6. Video Encoding

Untuk output SDR:

```text
Codec        : H.264 High
Pixel Format : yuv420p
CRF          : 17
Preset       : slow
```

Untuk output HDR:

```text
Codec        : H.264 High 10
Pixel Format : yuv420p10le
CRF          : 17
Preset       : slow
```

### CRF

Smart Video Patcher menggunakan **CRF 17** sebagai kompromi antara kualitas visual tinggi dan ukuran file.

### Preset

Preset `slow` digunakan untuk mendapatkan efisiensi kompresi yang lebih baik dibanding preset yang lebih cepat, dengan konsekuensi waktu encoding lebih lama.

---

## 7. GOP

GOP ditentukan berdasarkan target FPS:

```text
GOP = Target FPS × 2
```

Contoh:

```text
30 FPS → GOP 60
60 FPS → GOP 120
```

---

## 8. Video Bitrate Control

Untuk video 60 FPS:

```text
Maxrate : 25M
Buffer  : 50M
```

Untuk video di bawah 60 FPS:

```text
Maxrate : 20M
Buffer  : 40M
```

Parameter tersebut digunakan sebagai bagian dari kontrol bitrate/VBV selama encoding.

---

## 9. Audio

Audio output:

```text
Codec       : AAC
Bitrate     : 256 kbps
Sample Rate : 48 kHz
Channels    : Stereo
```

---

## 10. MP4 Fast Start

Output menggunakan:

```text
-movflags +faststart
```

Fast Start memindahkan metadata MP4 yang diperlukan ke bagian awal file sehingga file lebih sesuai untuk penggunaan berbasis web/streaming.

---

## 11. Smart Processing

Smart Video Patcher tidak selalu melakukan transcoding.

Tool terlebih dahulu menganalisis video menggunakan FFprobe.

Jika video sudah kompatibel, tool dapat melakukan:

```text
SMART REMUX
```

Jika terdapat parameter yang perlu diperbaiki, tool melakukan:

```text
SMART TRANSCODE
```

Contoh alasan transcoding:

```text
- Codec
- Pixel format
- HDR -> SDR
- FPS
- VFR
- Resolution
- Display rotation
- Audio
```

---

# Processing Flow

```text
                    INPUT VIDEO
                         │
                         ▼
                      FFPROBE
                         │
                         ▼
                  ANALYZE VIDEO
                         │
          ┌──────────────┴──────────────┐
          │                             │
          ▼                             ▼
      HDR DETECTION                RESOLUTION
          │                             │
          ▼                             ▼
    USER HDR CHOICE               SMART SCALE
          │                             │
          └──────────────┬──────────────┘
                         ▼
                  SMART DECISION
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        SMART REMUX           SMART TRANSCODE
                                    │
                           ┌────────┴────────┐
                           │                 │
                           ▼                 ▼
                       KEEP HDR          HDR -> SDR
                           │                 │
                           │            libplacebo
                           │                 │
                           │        BT.2446A / BT.2390
                           │                 │
                           └────────┬────────┘
                                    ▼
                              H.264 / AAC
                                    │
                                    ▼
                                   MP4
                                    │
                                    ▼
                                  OUTPUT
```

---

# Supported Input Formats

Format yang didukung:

```text
MP4
MOV
MKV
M4V
AVI
WEBM
WMV
```

Contoh video iPhone:

```text
input/IMG_6998.MOV
```

Output:

```text
output/IMG_6998_READY.mp4
```

---

# Requirements

Smart Video Patcher membutuhkan:

- Windows
- PowerShell
- FFmpeg
- FFprobe

---

# Installation

## 1. Clone Repository

```bash
git clone https://github.com/plafound/smart-video-patcher.git
cd smart-video-patcher
```


## 2. Install FFmpeg

Smart Video Patcher menggunakan FFmpeg sebagai engine utama untuk processing video.

Download FFmpeg dari website resminya:

https://ffmpeg.org/download.html

Untuk Windows, gunakan build FFmpeg yang menyediakan:

```text
ffmpeg.exe
ffprobe.exe
```

---

## 3. Masukkan FFmpeg ke Folder `bin`

Repository menyediakan folder:

```text
bin/
```

tetapi file binary FFmpeg **tidak disertakan**.

Masukkan: Semua file di dalam folder bin FFMPEG

ke:

```text
bin/
```

Struktur minimal:

```text
SmartVideoPatcher/
├── bin/
│   ├── ffmpeg.exe
│   ├── ffprobe.exe
│   ├── avcodec-*.dll
│   ├── avdevice-*.dll
│   ├── avfilter-*.dll
│   ├── avformat-*.dll
│   ├── avutil-*.dll
│   ├── swresample-*.dll
│   └── swscale-*.dll
├── input/
├── output/
├── patcher.ps1
├── patcher.bat
└── README.md
```

## 4. Masukkan Video

Masukkan video ke:

```text
input/
```

Contoh:

```text
input/
└── video.MOV
```

---

## 5. Output

Hasil processing disimpan ke:

```text
output/
```

Contoh:

```text
output/
├── video_READY.mp4
└── video_REPORT.txt
```

---

# Running

Jalankan file patch.bat dari folder project

---

# HDR Selection

Saat program dimulai, pengguna dapat memilih:

```text
==================================================
                  HDR MODE
==================================================

[1] Pertahankan HDR
    HDR source akan dipertahankan.

[2] Konversi HDR -> SDR
    HLG -> BT.2446A
    PQ  -> BT.2390
    Output menjadi Rec.709 SDR.

Pilih mode HDR [1/2]:
```

## Pilih `1` — Pertahankan HDR

Gunakan jika:

- Ingin mempertahankan HDR
- Ingin mempertahankan 10-bit HDR
- File digunakan sebagai master HDR
- Tidak ingin tone mapping dilakukan

Pipeline:

```text
HDR Source
    ↓
No Tone Mapping
    ↓
10-bit
    ↓
H.264 High 10
    ↓
HDR MP4
```

## Pilih `2` — Konversi HDR → SDR

Gunakan jika:

- Ingin menghasilkan video SDR
- Ingin melakukan tone mapping HDR
- Ingin output Rec.709
- Ingin workflow yang lebih umum untuk upload

Pipeline:

```text
HDR Source
    ↓
HDR Detection
    ↓
libplacebo
    ↓
BT.2446A / BT.2390
    ↓
Rec.709 SDR
    ↓
H.264 High
    ↓
MP4
```

---

# Example: iPhone HDR

Video iPhone modern dapat menggunakan:

```text
Codec           : HEVC
Profile         : Main 10
Pixel Format    : yuv420p10le
Color Space     : bt2020nc
Color Transfer  : arib-std-b67
Color Primaries : bt2020
HDR Type        : HLG
```

Jika pengguna memilih:

```text
[2] Konversi HDR -> SDR
```

maka HLG diproses menggunakan:

```text
libplacebo
+
BT.2446A
+
Peak Detection
+
Gamut Mapping
```

dan menghasilkan:

```text
Rec.709 SDR
```

---

# Output Report

Setiap video yang berhasil diproses menghasilkan report:

```text
output/
├── video_READY.mp4
└── video_REPORT.txt
```

Report berisi:

- Informasi source
- Resolusi
- Display resolution
- Rotation
- Orientation
- FPS
- Codec
- Pixel format
- Color space
- HDR type
- VFR
- Audio
- Smart resolution
- HDR processing
- Encoding
- Output size
- Alasan transcoding

---

# Project Structure

Struktur repository:

```text
SmartVideoPatcher/
│
├── bin/
│   └── .gitkeep
│
├── input/
│   └── .gitkeep
│
├── output/
│   └── .gitkeep
│
├── patcher.ps1
├── patcher.bat
├── README.md
└── .gitignore
```

Setelah instalasi FFmpeg secara lokal:

```text
SmartVideoPatcher/
│
├── bin/
│   ├── ffmpeg.exe
│   ├── ffprobe.exe
│   └── dan FFmpeg DLL files
│
├── input/
│   └── video.MOV
│
├── output/
│
├── patcher.ps1
├── patcher.bat
├── README.md
└── .gitignore
```

---

# Why FFmpeg Is Not Included?

FFmpeg merupakan software terpisah yang digunakan sebagai processing engine.

Repository ini tidak menyertakan:

```text
ffmpeg.exe
ffprobe.exe
```

agar repository tetap ringan.

Pengguna harus mengunduh FFmpeg sendiri dan menempatkan binary yang diperlukan di:

```text
bin/
```
# Recommended Workflow

Untuk video HDR dari smartphone seperti iPhone atau perangkat Android modern:

```text
                 VIDEO HDR
                     │
                     ▼
             SMART VIDEO PATCHER
                     │
                     ▼
                  FFPROBE
                     │
                     ▼
              ANALYZE SOURCE
                     │
                     ▼
              HDR USER CHOICE
                     │
            ┌────────┴────────┐
            │                 │
            ▼                 ▼
        KEEP HDR          HDR -> SDR
            │                 │
            │             libplacebo
            │                 │
            │        BT.2446A / BT.2390
            │                 │
            └────────┬────────┘
                     ▼
               SMART SCALE
                     │
                     ▼
                VFR -> CFR
                     │
                     ▼
                H.264 / AAC
                     │
                     ▼
                 MP4
                     │
                     ▼
              READY FOR UPLOAD
```

---

# Important Notes About HDR

Tone mapping tidak menjamin hasil visual yang identik dengan source HDR.

Hasil konversi HDR → SDR dapat dipengaruhi oleh:

- HDR format
- Color metadata
- Peak brightness
- Mastering metadata
- Source gamut
- Karakteristik kamera
- Karakteristik display

Karena itu Smart Video Patcher menyediakan dua pilihan:

```text
KEEP HDR
```

dan:

```text
HDR -> SDR
```

Pengguna dapat memilih workflow sesuai kebutuhan.

---

# Important Notes About Social Media

Smart Video Patcher ditujukan sebagai **pre-upload processing tool**.

Platform seperti TikTok dan Instagram tetap dapat melakukan:

- Re-encoding
- Compression
- Resolution adaptation
- Bitrate adaptation
- Color processing
- Platform-specific optimization

setelah video diunggah.

Tidak ada jaminan bahwa output Smart Video Patcher akan tetap identik dengan file lokal setelah diproses oleh platform.

Tujuan tool ini adalah memberikan source video yang lebih terkontrol sebelum upload.

---

# Limitations

Smart Video Patcher saat ini memiliki beberapa batasan:

- Membutuhkan Windows
- Membutuhkan PowerShell
- Membutuhkan FFmpeg
- Membutuhkan FFprobe
- Tidak menjamin hasil akhir setelah platform melakukan transcoding
- Tone mapping HDR → SDR tetap bergantung pada karakteristik source HDR
- Tidak melakukan editing kreatif seperti color grading, crop manual, atau stabilization

---

# Troubleshooting

## `ffmpeg.exe tidak ditemukan`

Pastikan:

```text
bin/ffmpeg.exe
bin/ffprobe.exe
```

tersedia.

---

## `avformat-*.dll was not found`

Pastikan DLL yang disertakan bersama FFmpeg berada bersama executable FFmpeg.

Contoh:

```text
bin/
├── ffmpeg.exe
├── ffprobe.exe
├── avcodec-*.dll
├── avformat-*.dll
├── avfilter-*.dll
├── avutil-*.dll
├── swresample-*.dll
└── swscale-*.dll
```

Jangan hanya mengambil `ffmpeg.exe` dan `ffprobe.exe` jika build tersebut membutuhkan DLL.

---

## Tidak ada video ditemukan

Pastikan video berada di:

```text
input/
```

Format yang didukung:

```text
.mp4
.mov
.mkv
.m4v
.avi
.webm
.wmv
```

---


# Credits

Smart Video Patcher menggunakan teknologi open-source berikut:

- [FFmpeg](https://ffmpeg.org/)
- FFprobe
- libplacebo

FFmpeg dan komponen terkait tetap merupakan proyek terpisah dari Smart Video Patcher.

---

# License

Tambahkan lisensi sesuai kebutuhan project.

Contoh:

```text
MIT License
```

Jika menggunakan atau mendistribusikan komponen pihak ketiga, pastikan ketentuan lisensi masing-masing komponen tetap dipatuhi.

---

# Author

**Smart Video Patcher**

A lightweight local video preprocessing tool designed for preparing videos before upload to social media platforms.

---

# Quick Start

### 1. Clone repository

```bash
git clone https://github.com/plafound/smart-video-patcher.git
cd smart-video-patcher
```

### 2. Download FFmpeg

Download FFmpeg dari:

https://ffmpeg.org/download.html

### 3. Masukkan FFmpeg ke `bin`

```text
bin/
├── ffmpeg.exe
├── ffprobe.exe
└── [DLL FFmpeg jika diperlukan]
```

### 4. Masukkan video

```text
input/
└── video.MOV
```

### 5. Jalankan

klik 2x pada file patch.bat

### 6. Pilih HDR mode

```text
[1] Pertahankan HDR
[2] Konversi HDR -> SDR
```

### 7. Ambil hasil

```text
output/
├── video_READY.mp4
└── video_REPORT.txt
```

**Selesai.**
