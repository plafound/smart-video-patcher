$ErrorActionPreference = "Stop"

# ============================================================
# SMART VIDEO PATCHER
# ============================================================
#
# Universal HDR -> SDR
# Optional HDR KEEP
# libplacebo HDR Engine
# Smart Display Orientation
# Smart Resolution
# No Crop
# No Upscale
# VFR -> CFR
# H.264 High / High 10
# AAC 48 kHz
# Optimized for Instagram / TikTok
# ============================================================


$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$FFmpeg  = Join-Path $Root "bin\ffmpeg.exe"
$FFprobe = Join-Path $Root "bin\ffprobe.exe"

$InputDir  = Join-Path $Root "input"
$OutputDir = Join-Path $Root "output"


# ============================================================
# HEADER
# ============================================================

Clear-Host

Write-Host ""
Write-Host "=================================================="
Write-Host "           SMART VIDEO PATCHER"
Write-Host "      HDR + ORIENTATION + ENCODING"
Write-Host "        TikTok + Instagram Ready"
Write-Host "=================================================="
Write-Host ""


# ============================================================
# CHECK ENVIRONMENT
# ============================================================

Write-Host "[1/9] Checking environment..."
Write-Host ""

if (!(Test-Path $FFmpeg)) {

    Write-Host "ERROR: ffmpeg.exe tidak ditemukan!" -ForegroundColor Red
    Write-Host $FFmpeg

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}

if (!(Test-Path $FFprobe)) {

    Write-Host "ERROR: ffprobe.exe tidak ditemukan!" -ForegroundColor Red
    Write-Host $FFprobe

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}

Write-Host "FFmpeg  : OK" -ForegroundColor Green
Write-Host "FFprobe : OK" -ForegroundColor Green
Write-Host ""


# ============================================================
# DIRECTORY
# ============================================================

if (!(Test-Path $InputDir)) {
    New-Item -ItemType Directory -Path $InputDir | Out-Null
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}


# ============================================================
# HDR MODE SELECTION
# ============================================================

Write-Host "=================================================="
Write-Host "                  HDR MODE"
Write-Host "=================================================="
Write-Host ""

Write-Host "[1] Pertahankan HDR"
Write-Host "    HDR source akan dipertahankan."
Write-Host ""

Write-Host "[2] Konversi HDR -> SDR"
Write-Host "    HLG -> BT.2446A"
Write-Host "    PQ  -> BT.2390"
Write-Host "    Output menjadi Rec.709 SDR."
Write-Host ""

do {

    $HDRChoice = Read-Host "Pilih mode HDR [1/2]"

} while ($HDRChoice -notin @("1","2"))


if ($HDRChoice -eq "1") {

    $HDRMode = "KEEP"

    Write-Host ""
    Write-Host "Mode HDR: PERTAHANKAN HDR" -ForegroundColor Cyan
    Write-Host ""

}
else {

    $HDRMode = "SDR"

    Write-Host ""
    Write-Host "Mode HDR: KONVERSI HDR -> SDR" -ForegroundColor Yellow
    Write-Host ""

}


# ============================================================
# FIND INPUT VIDEO
# ============================================================

Write-Host "[2/9] Mencari video..."
Write-Host ""

$Videos = @(
    Get-ChildItem -Path $InputDir -File |
    Where-Object {
        $_.Extension -match "\.(mp4|mov|mkv|m4v|avi|webm|wmv)$"
    }
)


if ($Videos.Count -eq 0) {

    Write-Host "Tidak ada video di folder input." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Masukkan video ke:"
    Write-Host $InputDir

    Read-Host "Tekan Enter untuk keluar"
    exit
}


# ============================================================
# SELECT INPUT
# ============================================================

if ($Videos.Count -gt 1) {

    Write-Host "Video ditemukan:"
    Write-Host ""

    for ($i = 0; $i -lt $Videos.Count; $i++) {

        Write-Host ("[{0}] {1}" -f `
            ($i + 1),
            $Videos[$i].Name)

    }

    Write-Host ""

    $Selection = Read-Host "Pilih nomor video"

    if (
        !($Selection -match "^\d+$") -or
        [int]$Selection -lt 1 -or
        [int]$Selection -gt $Videos.Count
    ) {

        Write-Host "Pilihan tidak valid." -ForegroundColor Red

        Read-Host "Tekan Enter untuk keluar"
        exit 1
    }

    $InputVideo = $Videos[[int]$Selection - 1]

}
else {

    $InputVideo = $Videos[0]

}


$InputPath = $InputVideo.FullName

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension(
    $InputVideo.Name
)


Write-Host ""
Write-Host "Input:"
Write-Host $InputVideo.Name
Write-Host ""


# ============================================================
# FFPROBE
# ============================================================

Write-Host "[3/9] Menganalisis metadata..."
Write-Host ""


$ProbeJson = & $FFprobe `
    -v quiet `
    -print_format json `
    -show_streams `
    -show_format `
    "$InputPath"


if ($LASTEXITCODE -ne 0) {

    Write-Host "FFprobe gagal." -ForegroundColor Red

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}


try {

    $Probe = $ProbeJson | ConvertFrom-Json

}
catch {

    Write-Host "JSON FFprobe tidak dapat dibaca." -ForegroundColor Red
    Write-Host $_.Exception.Message

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}


$Video = $Probe.streams |
    Where-Object {
        $_.codec_type -eq "video"
    } |
    Select-Object -First 1


$Audio = $Probe.streams |
    Where-Object {
        $_.codec_type -eq "audio"
    } |
    Select-Object -First 1


if ($null -eq $Video) {

    Write-Host "Video stream tidak ditemukan." -ForegroundColor Red

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}


# ============================================================
# BASIC VIDEO INFO
# ============================================================

$Width  = [int]$Video.width
$Height = [int]$Video.height

$Codec       = $Video.codec_name
$Profile     = $Video.profile
$PixelFormat = $Video.pix_fmt

$ColorSpace     = $Video.color_space
$ColorTransfer  = $Video.color_transfer
$ColorPrimaries = $Video.color_primaries

$BitDepth = $Video.bits_per_raw_sample


# ============================================================
# FPS
# ============================================================

$FPSRaw = $Video.avg_frame_rate

if (
    [string]::IsNullOrWhiteSpace($FPSRaw) -or
    $FPSRaw -eq "0/0"
) {

    $FPSRaw = $Video.r_frame_rate

}


if ($FPSRaw -match "/") {

    $Parts = $FPSRaw -split "/"

    $FPS =
        [double]$Parts[0] /
        [double]$Parts[1]

}
else {

    $FPS = [double]$FPSRaw

}


$FPS = [math]::Round($FPS, 3)


# ============================================================
# HDR DETECTION
# ============================================================

$HDRType = "SDR"


if ($ColorTransfer -eq "arib-std-b67") {

    $HDRType = "HLG"

}
elseif ($ColorTransfer -eq "smpte2084") {

    $HDRType = "PQ"

}
elseif (
    $ColorPrimaries -eq "bt2020" -and
    $PixelFormat -match "10|12"
) {

    $HDRType = "HDR-WIDE-GAMUT"

}


$HDR = ($HDRType -ne "SDR")


# ============================================================
# ROTATION DETECTION
# ============================================================

$Rotation = 0


if ($Video.side_data_list) {

    foreach ($SideData in $Video.side_data_list) {

        if ($null -ne $SideData.rotation) {

            $Rotation =
                [double]$SideData.rotation

            break
        }

    }

}


if (
    $Rotation -eq 0 -and
    $Video.tags -and
    $Video.tags.rotate
) {

    $Rotation =
        [double]$Video.tags.rotate

}


$Rotation =
    (($Rotation % 360) + 360) % 360


if ($Rotation -gt 180) {

    $DisplayRotation = $Rotation - 360

}
else {

    $DisplayRotation = $Rotation

}


# ============================================================
# DISPLAY DIMENSIONS
# ============================================================

$DisplayWidth  = $Width
$DisplayHeight = $Height


if (
    [math]::Abs($DisplayRotation) -eq 90
) {

    $DisplayWidth  = $Height
    $DisplayHeight = $Width

}


$DisplayAspect =
    $DisplayWidth / $DisplayHeight


# ============================================================
# ORIENTATION
# ============================================================

if ($DisplayAspect -gt 1.05) {

    $Orientation = "LANDSCAPE"

}
elseif ($DisplayAspect -lt 0.95) {

    $Orientation = "PORTRAIT"

}
else {

    $Orientation = "SQUARE"

}


# ============================================================
# VFR
# ============================================================

$VFR = $false


if (
    $Video.r_frame_rate -ne
    $Video.avg_frame_rate
) {

    $VFR = $true

}


# ============================================================
# AUDIO
# ============================================================

$AudioCodec = "NONE"
$SampleRate = "NONE"
$Channels   = "NONE"


if ($null -ne $Audio) {

    $AudioCodec = $Audio.codec_name
    $SampleRate = $Audio.sample_rate
    $Channels   = $Audio.channels

}


# ============================================================
# TARGET FPS
# ============================================================

if ($FPS -ge 59) {

    $TargetFPS = 60

}
elseif ($FPS -ge 49) {

    $TargetFPS = 50

}
elseif ($FPS -ge 29) {

    $TargetFPS = 30

}
elseif ($FPS -ge 23) {

    $TargetFPS = 24

}
else {

    $TargetFPS =
        [math]::Round($FPS)

}


# ============================================================
# SMART RESOLUTION
# ============================================================

$ScaleFilter = ""
$ScaleAction = "No resize"


switch ($Orientation) {

    "LANDSCAPE" {

        $TargetWidth  = 1920
        $TargetHeight = 1080

    }

    "PORTRAIT" {

        $TargetWidth  = 1080
        $TargetHeight = 1920

    }

    "SQUARE" {

        $TargetWidth  = 1080
        $TargetHeight = 1080

    }

}


# Downscale only
# Never upscale

if (
    $DisplayWidth -gt $TargetWidth -or
    $DisplayHeight -gt $TargetHeight
) {

    $ScaleFilter =
        "scale=" +
        "min($TargetWidth\,iw):" +
        "min($TargetHeight\,ih):" +
        "force_original_aspect_ratio=decrease:" +
        "force_divisible_by=2"

    $ScaleAction =
        "Downscale -> max ${TargetWidth}x${TargetHeight}"

}


# ============================================================
# SOURCE REPORT
# ============================================================

Write-Host ""
Write-Host "=================================================="
Write-Host "                 SOURCE ANALYSIS"
Write-Host "=================================================="
Write-Host ""

Write-Host ("Stream Resolution : {0} x {1}" -f `
    $Width,
    $Height)

Write-Host ("Display Resolution: {0} x {1}" -f `
    $DisplayWidth,
    $DisplayHeight)

Write-Host ("Rotation          : {0} deg" -f `
    $DisplayRotation)

Write-Host ("Orientation       : {0}" -f `
    $Orientation)

Write-Host ("Display Aspect    : {0:N3}" -f `
    $DisplayAspect)

Write-Host ""

Write-Host ("FPS               : {0}" -f $FPS)
Write-Host ("Codec             : {0}" -f $Codec)
Write-Host ("Profile           : {0}" -f $Profile)
Write-Host ("Pixel Format      : {0}" -f $PixelFormat)
Write-Host ("Bit Depth         : {0}" -f $BitDepth)

Write-Host ""

Write-Host ("Color Space       : {0}" -f $ColorSpace)
Write-Host ("Color Transfer    : {0}" -f $ColorTransfer)
Write-Host ("Color Primaries   : {0}" -f $ColorPrimaries)

Write-Host ""

Write-Host ("HDR Type          : {0}" -f $HDRType)
Write-Host ("VFR               : {0}" -f $VFR)

Write-Host ""

Write-Host "SMART RESOLUTION"
Write-Host "----------------"

Write-Host ("Target Class      : {0} x {1}" -f `
    $TargetWidth,
    $TargetHeight)

Write-Host ("Action            : {0}" -f `
    $ScaleAction)

Write-Host ""


# ============================================================
# COMPATIBILITY
# ============================================================

$Reasons = @()


if ($Codec -ne "h264") {
    $Reasons += "Codec"
}


# ------------------------------------------------------------
# Pixel format
# ------------------------------------------------------------

if ($HDRMode -eq "SDR") {

    if ($PixelFormat -ne "yuv420p") {

        $Reasons += "Pixel format"

    }

}
else {

    # KEEP HDR
    # HDR 10-bit source should remain 10-bit.
    # SDR sources still use normal yuv420p.

    if (
        $HDR -and
        $PixelFormat -notmatch "10|12"
    ) {

        $Reasons += "HDR bit depth"

    }

}


# ------------------------------------------------------------
# HDR
# ------------------------------------------------------------

if (
    $HDR -and
    $HDRMode -eq "SDR"
) {

    $Reasons += "HDR -> SDR"

}


# ------------------------------------------------------------
# FPS
# ------------------------------------------------------------

if (
    [math]::Abs($FPS - $TargetFPS) -gt 0.1
) {

    $Reasons += "FPS"

}


if ($VFR) {

    $Reasons += "VFR"

}


# ------------------------------------------------------------
# Resolution
# ------------------------------------------------------------

if ($ScaleFilter -ne "") {

    $Reasons += "Resolution"

}


# ------------------------------------------------------------
# Rotation
# ------------------------------------------------------------

if ($DisplayRotation -ne 0) {

    $Reasons += "Display rotation"

}


# ------------------------------------------------------------
# Audio
# ------------------------------------------------------------

if ($null -ne $Audio) {

    if (
        $AudioCodec -ne "aac" -or
        $SampleRate -ne "48000" -or
        $Channels -ne 2
    ) {

        $Reasons += "Audio"

    }

}


$NeedsEncode =
    ($Reasons.Count -gt 0)


# ============================================================
# DECISION
# ============================================================

Write-Host ""
Write-Host "=================================================="
Write-Host "                   DECISION"
Write-Host "=================================================="
Write-Host ""


if ($NeedsEncode) {

    Write-Host "MODE : SMART TRANSCODE" `
        -ForegroundColor Yellow

    Write-Host ""

    foreach ($Reason in $Reasons) {

        Write-Host " - $Reason"

    }

}
else {

    Write-Host "MODE : SMART REMUX" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "Source sudah kompatibel."

}


Write-Host ""


# ============================================================
# OUTPUT
# ============================================================

$OutputPath = Join-Path `
    $OutputDir `
    "${BaseName}_READY.mp4"


# ============================================================
# SMART REMUX
# ============================================================

if (!$NeedsEncode) {

    Write-Host "=================================================="
    Write-Host "                  SMART REMUX"
    Write-Host "=================================================="
    Write-Host ""

    & $FFmpeg `
        -hide_banner `
        -y `
        -i "$InputPath" `
        -map 0 `
        -c copy `
        -map_metadata -1 `
        -movflags +faststart `
        "$OutputPath"


    if ($LASTEXITCODE -ne 0) {

        Write-Host "REMUX GAGAL." `
            -ForegroundColor Red

        Read-Host "Tekan Enter untuk keluar"
        exit 1
    }

}


# ============================================================
# SMART TRANSCODE
# ============================================================

else {

    Write-Host "=================================================="
    Write-Host "                SMART TRANSCODE"
    Write-Host "=================================================="
    Write-Host ""


    # --------------------------------------------------------
    # GOP
    # --------------------------------------------------------

    $GOP = $TargetFPS * 2


    # --------------------------------------------------------
    # VIDEO VBV
    # --------------------------------------------------------

    if ($TargetFPS -ge 60) {

        $MaxRate = "25M"
        $Buffer  = "50M"

    }
    else {

        $MaxRate = "20M"
        $Buffer  = "40M"

    }


    # --------------------------------------------------------
    # FILTER CHAIN
    # --------------------------------------------------------

    $Filters = @()


    # ========================================================
    # HDR ENGINE
    # ========================================================

    if (
        $HDR -and
        $HDRMode -eq "SDR"
    ) {

        if ($HDRType -eq "HLG") {

            Write-Host "HDR ENGINE       : libplacebo"
            Write-Host "HDR TYPE         : HLG"
            Write-Host "Tone Mapping     : BT.2446A"
            Write-Host "Peak Detection   : Enabled"
            Write-Host "Gamut Mapping    : Perceptual"
            Write-Host ""

            $Filters +=
                "libplacebo=" +
                "colorspace=bt709:" +
                "color_primaries=bt709:" +
                "color_trc=bt709:" +
                "range=tv:" +
                "tonemapping=bt.2446a:" +
                "peak_detect=true:" +
                "gamut_mode=perceptual"

        }
        elseif ($HDRType -eq "PQ") {

            Write-Host "HDR ENGINE       : libplacebo"
            Write-Host "HDR TYPE         : PQ"
            Write-Host "Tone Mapping     : BT.2390"
            Write-Host "Peak Detection   : Enabled"
            Write-Host "Gamut Mapping    : Perceptual"
            Write-Host ""

            $Filters +=
                "libplacebo=" +
                "colorspace=bt709:" +
                "color_primaries=bt709:" +
                "color_trc=bt709:" +
                "range=tv:" +
                "tonemapping=bt.2390:" +
                "peak_detect=true:" +
                "gamut_mode=perceptual"

        }
        elseif ($HDRType -eq "HDR-WIDE-GAMUT") {

            Write-Host "HDR ENGINE       : libplacebo"
            Write-Host "HDR TYPE         : Generic HDR"
            Write-Host "Tone Mapping     : BT.2390"
            Write-Host "Peak Detection   : Enabled"
            Write-Host "Gamut Mapping    : Perceptual"
            Write-Host ""

            $Filters +=
                "libplacebo=" +
                "colorspace=bt709:" +
                "color_primaries=bt709:" +
                "color_trc=bt709:" +
                "range=tv:" +
                "tonemapping=bt.2390:" +
                "peak_detect=true:" +
                "gamut_mode=perceptual"

        }

    }
    elseif (
        $HDR -and
        $HDRMode -eq "KEEP"
    ) {

        Write-Host "HDR ENGINE       : DISABLED"
        Write-Host "HDR ACTION       : KEEP HDR"
        Write-Host "Tone Mapping     : NONE"
        Write-Host "HDR Metadata     : PRESERVED"
        Write-Host ""

    }
    else {

        Write-Host "HDR ENGINE       : Disabled"
        Write-Host ""

    }


    # ========================================================
    # SMART SCALE
    # ========================================================

    if ($ScaleFilter -ne "") {

        Write-Host "SCALING          : $ScaleAction"

        $Filters += $ScaleFilter

    }
    else {

        Write-Host "SCALING          : None"

    }


    # ========================================================
    # OUTPUT PIXEL FORMAT
    # ========================================================

    if (
        $HDR -and
        $HDRMode -eq "KEEP"
    ) {

        $Filters += "format=yuv420p10le"

    }
    else {

        $Filters += "format=yuv420p"

    }


    $Filter = $Filters -join ","


    Write-Host ""
    Write-Host "Target FPS       : $TargetFPS"
    Write-Host "GOP              : $GOP"
    Write-Host "CRF              : 17"
    Write-Host "Preset           : slow"
    Write-Host "Maxrate          : $MaxRate"
    Write-Host "Buffer           : $Buffer"
    Write-Host ""


    # ========================================================
    # TRANSCODE
    # ========================================================

    if (
        $HDR -and
        $HDRMode -eq "KEEP"
    ) {

        # ----------------------------------------------------
        # KEEP HDR
        # ----------------------------------------------------

        & $FFmpeg `
            -hide_banner `
            -y `
            -autorotate `
            -i "$InputPath" `
            -map 0:v:0 `
            -map 0:a? `
            -vf "$Filter" `
            -r $TargetFPS `
            -fps_mode cfr `
            -c:v libx264 `
            -profile:v high10 `
            -level:v 5.1 `
            -preset slow `
            -crf 17 `
            -maxrate $MaxRate `
            -bufsize $Buffer `
            -g $GOP `
            -keyint_min $GOP `
            -sc_threshold 0 `
            -color_primaries $ColorPrimaries `
            -color_trc $ColorTransfer `
            -colorspace $ColorSpace `
            -color_range tv `
            -c:a aac `
            -b:a 256k `
            -ar 48000 `
            -ac 2 `
            -map_metadata 0 `
            -movflags +faststart `
            "$OutputPath"

    }
    else {

        # ----------------------------------------------------
        # HDR -> SDR / NORMAL SDR
        # ----------------------------------------------------

        & $FFmpeg `
            -hide_banner `
            -y `
            -autorotate `
            -i "$InputPath" `
            -map 0:v:0 `
            -map 0:a? `
            -vf "$Filter" `
            -r $TargetFPS `
            -fps_mode cfr `
            -c:v libx264 `
            -profile:v high `
            -level:v 4.2 `
            -preset slow `
            -crf 17 `
            -maxrate $MaxRate `
            -bufsize $Buffer `
            -g $GOP `
            -keyint_min $GOP `
            -sc_threshold 0 `
            -color_primaries bt709 `
            -color_trc bt709 `
            -colorspace bt709 `
            -color_range tv `
            -c:a aac `
            -b:a 256k `
            -ar 48000 `
            -ac 2 `
            -map_metadata -1 `
            -movflags +faststart `
            "$OutputPath"

    }


    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "TRANSCODE GAGAL." `
            -ForegroundColor Red

        Read-Host "Tekan Enter untuk keluar"
        exit 1
    }

}


# ============================================================
# VERIFY
# ============================================================

Write-Host ""
Write-Host "[8/9] Memverifikasi output..."
Write-Host ""


if (!(Test-Path $OutputPath)) {

    Write-Host "Output tidak ditemukan." `
        -ForegroundColor Red

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}


$OutputSizeMB =
    (Get-Item $OutputPath).Length / 1MB


# ============================================================
# REPORT
# ============================================================

$ReportPath = Join-Path `
    $OutputDir `
    "${BaseName}_REPORT.txt"


$ModeText = if ($NeedsEncode) {
    "SMART TRANSCODE"
}
else {
    "SMART REMUX"
}


if (
    $HDR -and
    $HDRMode -eq "KEEP"
) {

    $HDRActionReport = "KEEP HDR"
    $ToneMapReport   = "NONE"
    $OutputColor     = "HDR / SOURCE COLOR"
    $OutputPixel     = "yuv420p10le"
    $OutputProfile   = "H.264 High 10"

}
elseif (
    $HDR -and
    $HDRMode -eq "SDR"
) {

    $HDRActionReport = "HDR -> SDR"
    $ToneMapReport   = $HDRType
    $OutputColor     = "Rec.709 SDR"
    $OutputPixel     = "yuv420p"
    $OutputProfile   = "H.264 High"

}
else {

    $HDRActionReport = "SDR / NO HDR"
    $ToneMapReport   = "NONE"
    $OutputColor     = "Rec.709 SDR"
    $OutputPixel     = "yuv420p"
    $OutputProfile   = "H.264 High"

}


$Report = @"
SMART VIDEO PATCHER
==================================================

SOURCE
--------------------------------------------------

File                : $($InputVideo.Name)

Stream Resolution   : ${Width}x${Height}

Display Resolution  : ${DisplayWidth}x${DisplayHeight}

Rotation            : ${DisplayRotation} degrees

Orientation         : $Orientation

Display Aspect      : $([math]::Round($DisplayAspect,3))

FPS                 : $FPS

Codec               : $Codec

Profile             : $Profile

Pixel Format        : $PixelFormat

Bit Depth           : $BitDepth

Color Space         : $ColorSpace

Color Transfer      : $ColorTransfer

Color Primaries     : $ColorPrimaries

HDR Type            : $HDRType

VFR                 : $VFR

Audio Codec         : $AudioCodec

Sample Rate         : $SampleRate

Channels            : $Channels


SMART RESOLUTION
--------------------------------------------------

Target Class        : ${TargetWidth}x${TargetHeight}

Action              : $ScaleAction

Crop                : DISABLED

Upscale             : DISABLED

Aspect Ratio        : PRESERVED

Display Rotation    : RESPECTED


HDR PROCESSING
--------------------------------------------------

User Selection      : $HDRActionReport

Tone Mapping        : $ToneMapReport

HLG                 : BT.2446A

PQ                  : BT.2390

Peak Detection      : ENABLED

Gamut Mapping       : Perceptual

Output Color        : $OutputColor


ENCODING
--------------------------------------------------

Video Codec         : $OutputProfile

CRF                 : 17

Preset              : slow

Target FPS          : $TargetFPS

GOP                 : $GOP

Maxrate             : $MaxRate

VBV Buffer          : $Buffer

Pixel Format        : $OutputPixel

Color               : $OutputColor

Color Range         : TV / Limited


AUDIO
--------------------------------------------------

Codec               : AAC

Bitrate             : 256 kbps

Sample Rate         : 48 kHz

Channels            : Stereo


PROCESSING
--------------------------------------------------

Mode                : $ModeText

Reasons:
$(
    if ($Reasons.Count -gt 0) {

        ($Reasons | ForEach-Object {
            "- $_"
        }) -join "`r`n"

    }
    else {

        "Tidak ada."

    }
)


OUTPUT
--------------------------------------------------

File                : $($BaseName)_READY.mp4

Crop                : None

Upscale             : None

Fast Start          : Enabled

Metadata            : $(if ($HDR -and $HDRMode -eq "KEEP") { "HDR metadata preserved" } else { "Cleaned" })

Output Size         : $([math]::Round($OutputSizeMB,2)) MB


==================================================
READY FOR TIKTOK / INSTAGRAM
==================================================
"@


Set-Content `
    -Path $ReportPath `
    -Value $Report `
    -Encoding UTF8


# ============================================================
# FINISH
# ============================================================

Write-Host ""
Write-Host "=================================================="
Write-Host "                    SELESAI"
Write-Host "=================================================="
Write-Host ""

Write-Host "Output:"
Write-Host $OutputPath

Write-Host ""

Write-Host ("Ukuran : {0:N2} MB" -f `
    $OutputSizeMB)

Write-Host ""

Write-Host "Report:"
Write-Host $ReportPath

Write-Host ""

Write-Host "Video siap untuk TikTok / Instagram."

Write-Host ""

Read-Host "Tekan Enter untuk keluar"