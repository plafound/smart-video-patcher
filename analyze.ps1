$ErrorActionPreference = "Stop"

# ============================================================
# VIDEO PROBE ANALYZER
# ============================================================
#
# Analisis struktur video menggunakan FFprobe
#
# Fokus:
# - Resolution
# - Display aspect
# - Rotation
# - FPS
# - CFR / VFR
# - Timebase
# - Duration
# - Frame count
# - Codec / Profile / Level
# - Pixel format / Bit depth
# - Color / HDR
# - Bitrate
# - GOP / Keyframe
# - Timestamp information
# - Audio
# - Metadata
#
# ============================================================


$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$FFprobe = Join-Path $Root "bin\ffprobe.exe"

$InputDir  = Join-Path $Root "input"
$OutputDir = Join-Path $Root "output"


# ============================================================
# HEADER
# ============================================================

Clear-Host

Write-Host ""
Write-Host "============================================================"
Write-Host "                 VIDEO PROBE ANALYZER"
Write-Host "              FFPROBE STRUCTURE ANALYSIS"
Write-Host "============================================================"
Write-Host ""


# ============================================================
# CHECK FFPROBE
# ============================================================

if (!(Test-Path $FFprobe)) {

    Write-Host "ERROR: ffprobe.exe tidak ditemukan!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Letakkan ffprobe.exe di:"
    Write-Host $FFprobe
    Write-Host ""

    Read-Host "Tekan Enter untuk keluar"
    exit 1
}


# ============================================================
# CHECK DIRECTORIES
# ============================================================

if (!(Test-Path $InputDir)) {

    New-Item `
        -ItemType Directory `
        -Path $InputDir |
        Out-Null
}


if (!(Test-Path $OutputDir)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDir |
        Out-Null
}


# ============================================================
# FIND FILES
# ============================================================

$Files = @(
    Get-ChildItem `
        -Path $InputDir `
        -File |
    Where-Object {
        $_.Extension -match `
        "\.(mp4|mov|m4v|mkv|avi|webm|wmv)$"
    }
)


if ($Files.Count -eq 0) {

    Write-Host "Tidak ada file video di folder input." `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Masukkan file video ke:"
    Write-Host $InputDir
    Write-Host ""

    Read-Host "Tekan Enter untuk keluar"
    exit
}


Write-Host "File ditemukan: $($Files.Count)"
Write-Host ""


# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Get-FPS {

    param(
        [string]$Rate
    )

    if (
        [string]::IsNullOrWhiteSpace($Rate) -or
        $Rate -eq "0/0"
    ) {

        return 0
    }

    if ($Rate -match "/") {

        $Parts = $Rate -split "/"

        if (
            [double]$Parts[1] -ne 0
        ) {

            return (
                [double]$Parts[0] /
                [double]$Parts[1]
            )
        }
    }

    return [double]$Rate
}


function Get-Value {

    param(
        $Object,
        [string]$Property
    )

    if ($null -eq $Object) {
        return "N/A"
    }

    $Value = $Object.$Property

    if ($null -eq $Value -or $Value -eq "") {
        return "N/A"
    }

    return $Value
}


# ============================================================
# RESULT ARRAYS
# ============================================================

$Summary = @()


# ============================================================
# PROCESS EACH FILE
# ============================================================

foreach ($File in $Files) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "ANALYZING: $($File.Name)"
    Write-Host "============================================================"
    Write-Host ""


    $FilePath = $File.FullName


    # --------------------------------------------------------
    # FFPROBE JSON
    # --------------------------------------------------------

    $Json = & $FFprobe `
        -v quiet `
        -print_format json `
        -show_format `
        -show_streams `
        -show_chapters `
        -show_programs `
        "$FilePath"


    if ($LASTEXITCODE -ne 0) {

        Write-Host "FFprobe gagal untuk file:" `
            -ForegroundColor Red

        Write-Host $File.Name

        continue
    }


    try {

        $Data = $Json |
            ConvertFrom-Json

    }
    catch {

        Write-Host "JSON tidak dapat diproses." `
            -ForegroundColor Red

        continue
    }


    # --------------------------------------------------------
    # SAVE RAW JSON
    # --------------------------------------------------------

    $SafeName =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $File.Name
        )

    $JsonOutput =
        Join-Path `
            $OutputDir `
            "${SafeName}_FFPROBE.json"


    $Json |
        Out-File `
            -FilePath $JsonOutput `
            -Encoding UTF8


    # --------------------------------------------------------
    # VIDEO STREAM
    # --------------------------------------------------------

    $Video =
        $Data.streams |
        Where-Object {
            $_.codec_type -eq "video"
        } |
        Select-Object -First 1


    # --------------------------------------------------------
    # AUDIO STREAM
    # --------------------------------------------------------

    $Audio =
        $Data.streams |
        Where-Object {
            $_.codec_type -eq "audio"
        } |
        Select-Object -First 1


    if ($null -eq $Video) {

        Write-Host "Video stream tidak ditemukan." `
            -ForegroundColor Red

        continue
    }


    # ========================================================
    # BASIC
    # ========================================================

    $Width =
        Get-Value $Video "width"

    $Height =
        Get-Value $Video "height"


    $DisplayWidth  = $Width
    $DisplayHeight = $Height


    # ========================================================
    # ROTATION
    # ========================================================

    $Rotation = "0"


    if ($Video.tags) {

        if ($null -ne $Video.tags.rotate) {

            $Rotation =
                $Video.tags.rotate

        }
    }


    if ($Video.side_data_list) {

        foreach ($SideData in $Video.side_data_list) {

            if ($null -ne $SideData.rotation) {

                $Rotation =
                    $SideData.rotation

            }
        }
    }


    # ========================================================
    # FPS
    # ========================================================

    $RFrameRate =
        Get-Value $Video "r_frame_rate"

    $AvgFrameRate =
        Get-Value $Video "avg_frame_rate"


    $RFPS =
        Get-FPS $RFrameRate

    $AvgFPS =
        Get-FPS $AvgFrameRate


    $RFPS =
        [math]::Round($RFPS, 6)

    $AvgFPS =
        [math]::Round($AvgFPS, 6)


    # ========================================================
    # CFR / VFR DETECTION
    # ========================================================

    $VFR = "UNKNOWN"


    if (
        $RFrameRate -ne "N/A" -and
        $AvgFrameRate -ne "N/A"
    ) {

        if (
            [math]::Abs(
                $RFPS - $AvgFPS
            ) -lt 0.001
        ) {

            $VFR = "LIKELY CFR"

        }
        else {

            $VFR = "LIKELY VFR"

        }
    }


    # ========================================================
    # TIMEBASE
    # ========================================================

    $TimeBase =
        Get-Value $Video "time_base"

    $StartTime =
        Get-Value $Video "start_time"

    $Duration =
        Get-Value $Video "duration"

    $Frames =
        Get-Value $Video "nb_frames"


    # ========================================================
    # CODEC
    # ========================================================

    $Codec =
        Get-Value $Video "codec_name"

    $CodecLong =
        Get-Value $Video "codec_long_name"

    $Profile =
        Get-Value $Video "profile"

    $Level =
        Get-Value $Video "level"

    $PixelFormat =
        Get-Value $Video "pix_fmt"

    $BitDepth =
        Get-Value $Video "bits_per_raw_sample"


    # ========================================================
    # COLOR
    # ========================================================

    $ColorSpace =
        Get-Value $Video "color_space"

    $ColorTransfer =
        Get-Value $Video "color_transfer"

    $ColorPrimaries =
        Get-Value $Video "color_primaries"

    $ColorRange =
        Get-Value $Video "color_range"


    # ========================================================
    # BITRATE
    # ========================================================

    $VideoBitrate =
        Get-Value $Video "bit_rate"

    $FormatBitrate =
        Get-Value $Data.format "bit_rate"

    $FileSize =
        $File.Length


    $FileSizeMB =
        [math]::Round(
            $FileSize / 1MB,
            2
        )


    $VideoBitrateMbps = "N/A"


    if (
        $VideoBitrate -ne "N/A" -and
        $VideoBitrate -as [double]
    ) {

        $VideoBitrateMbps =
            [math]::Round(
                ([double]$VideoBitrate / 1000000),
                3
            )
    }


    $FormatBitrateMbps = "N/A"


    if (
        $FormatBitrate -ne "N/A" -and
        $FormatBitrate -as [double]
    ) {

        $FormatBitrateMbps =
            [math]::Round(
                ([double]$FormatBitrate / 1000000),
                3
            )
    }


    # ========================================================
    # AUDIO
    # ========================================================

    $AudioCodec =
        Get-Value $Audio "codec_name"

    $AudioProfile =
        Get-Value $Audio "profile"

    $AudioSampleRate =
        Get-Value $Audio "sample_rate"

    $AudioChannels =
        Get-Value $Audio "channels"

    $AudioBitrate =
        Get-Value $Audio "bit_rate"


    $AudioBitrateKbps = "N/A"


    if (
        $AudioBitrate -ne "N/A" -and
        $AudioBitrate -as [double]
    ) {

        $AudioBitrateKbps =
            [math]::Round(
                ([double]$AudioBitrate / 1000),
                1
            )
    }


    # ========================================================
    # FORMAT / CONTAINER
    # ========================================================

    $FormatName =
        Get-Value $Data.format "format_name"

    $FormatLongName =
        Get-Value $Data.format "format_long_name"


    # ========================================================
    # METADATA
    # ========================================================

    $MetadataText = "None"


    if ($Data.format.tags) {

        $MetadataLines = @()

        foreach (
            $Property in
            $Data.format.tags.PSObject.Properties
        ) {

            $MetadataLines +=
                "$($Property.Name) = $($Property.Value)"
        }


        if ($MetadataLines.Count -gt 0) {

            $MetadataText =
                $MetadataLines -join "`r`n"

        }
    }


    # ========================================================
    # SIDE DATA
    # ========================================================

    $SideDataText = "None"


    if ($Video.side_data_list) {

        $SideDataLines = @()

        foreach ($SideData in $Video.side_data_list) {

            $Type =
                Get-Value $SideData "side_data_type"

            $SideDataLines += $Type
        }


        if ($SideDataLines.Count -gt 0) {

            $SideDataText =
                $SideDataLines -join ", "
        }
    }


    # ========================================================
    # DISPOSITION
    # ========================================================

    $DefaultVideo =
        Get-Value $Video.disposition "default"

    $DefaultAudio =
        Get-Value $Audio.disposition "default"


    # ========================================================
    # OUTPUT REPORT
    # ========================================================

    $ReportPath =
        Join-Path `
            $OutputDir `
            "${SafeName}_REPORT.txt"


    $Report = @"
============================================================
VIDEO PROBE REPORT
============================================================

FILE
------------------------------------------------------------

Name                : $($File.Name)

Full Path           : $FilePath

File Size           : $FileSizeMB MB


CONTAINER
------------------------------------------------------------

Format              : $FormatName

Format Long Name    : $FormatLongName

Format Bitrate      : $FormatBitrateMbps Mbps


VIDEO
------------------------------------------------------------

Codec               : $Codec

Codec Description   : $CodecLong

Profile             : $Profile

Level               : $Level

Resolution          : ${Width}x${Height}

Pixel Format        : $PixelFormat

Bit Depth           : $BitDepth


FRAME RATE
------------------------------------------------------------

r_frame_rate       : $RFrameRate

avg_frame_rate     : $AvgFrameRate

r_FPS              : $RFPS

avg_FPS            : $AvgFPS

Frame Mode         : $VFR


TIMING
------------------------------------------------------------

Time Base           : $TimeBase

Start Time          : $StartTime

Duration            : $Duration

Frame Count         : $Frames


ROTATION / DISPLAY
------------------------------------------------------------

Rotation            : $Rotation

Display Width      : $DisplayWidth

Display Height     : $DisplayHeight


COLOR
------------------------------------------------------------

Color Space         : $ColorSpace

Color Transfer      : $ColorTransfer

Color Primaries     : $ColorPrimaries

Color Range         : $ColorRange


BITRATE
------------------------------------------------------------

Video Bitrate       : $VideoBitrateMbps Mbps

Container Bitrate   : $FormatBitrateMbps Mbps


AUDIO
------------------------------------------------------------

Codec               : $AudioCodec

Profile             : $AudioProfile

Sample Rate         : $AudioSampleRate

Channels            : $AudioChannels

Bitrate             : $AudioBitrateKbps kbps


SIDE DATA
------------------------------------------------------------

$SideDataText


DISPOSITION
------------------------------------------------------------

Default Video      : $DefaultVideo

Default Audio      : $DefaultAudio


FORMAT METADATA
------------------------------------------------------------

$MetadataText


RAW FFPROBE JSON
------------------------------------------------------------

$JsonOutput


============================================================
END OF REPORT
============================================================
"@


    Set-Content `
        -Path $ReportPath `
        -Value $Report `
        -Encoding UTF8


    # ========================================================
    # CONSOLE SUMMARY
    # ========================================================

    Write-Host "Resolution      : ${Width}x${Height}"
    Write-Host "Rotation        : $Rotation"
    Write-Host "Codec           : $Codec"
    Write-Host "Profile         : $Profile"
    Write-Host "Pixel Format    : $PixelFormat"
    Write-Host "Color           : $ColorPrimaries / $ColorTransfer"
    Write-Host "r_frame_rate    : $RFrameRate"
    Write-Host "avg_frame_rate  : $AvgFrameRate"
    Write-Host "FPS             : $AvgFPS"
    Write-Host "Frame Mode      : $VFR"
    Write-Host "Time Base       : $TimeBase"
    Write-Host "Duration        : $Duration"
    Write-Host "Frames          : $Frames"
    Write-Host "Video Bitrate   : $VideoBitrateMbps Mbps"
    Write-Host "Audio           : $AudioCodec / $AudioSampleRate Hz"
    Write-Host "File Size       : $FileSizeMB MB"
    Write-Host ""


    # ========================================================
    # SUMMARY OBJECT
    # ========================================================

    $Summary += [PSCustomObject]@{

        File = $File.Name

        Size_MB =
            $FileSizeMB

        Resolution =
            "${Width}x${Height}"

        Rotation =
            $Rotation

        Codec =
            $Codec

        Profile =
            $Profile

        Level =
            $Level

        PixelFormat =
            $PixelFormat

        ColorSpace =
            $ColorSpace

        ColorTransfer =
            $ColorTransfer

        ColorPrimaries =
            $ColorPrimaries

        ColorRange =
            $ColorRange

        r_FrameRate =
            $RFrameRate

        Avg_FrameRate =
            $AvgFrameRate

        Avg_FPS =
            $AvgFPS

        FrameMode =
            $VFR

        TimeBase =
            $TimeBase

        StartTime =
            $StartTime

        Duration =
            $Duration

        Frames =
            $Frames

        VideoBitrate_Mbps =
            $VideoBitrateMbps

        ContainerBitrate_Mbps =
            $FormatBitrateMbps

        AudioCodec =
            $AudioCodec

        AudioSampleRate =
            $AudioSampleRate

        AudioChannels =
            $AudioChannels

        AudioBitrate_kbps =
            $AudioBitrateKbps
    }

}


# ============================================================
# SUMMARY CSV
# ============================================================

$CSVPath =
    Join-Path `
        $OutputDir `
        "SUMMARY.csv"


$Summary |
    Export-Csv `
        -Path $CSVPath `
        -NoTypeInformation `
        -Encoding UTF8


# ============================================================
# COMPARISON TXT
# ============================================================

$ComparisonPath =
    Join-Path `
        $OutputDir `
        "COMPARISON.txt"


$Comparison = @"

============================================================
                 VIDEO COMPARISON
============================================================

$($Summary |
    Format-Table `
        File,
        Size_MB,
        Resolution,
        Rotation,
        Codec,
        Profile,
        Avg_FPS,
        FrameMode,
        TimeBase,
        Duration,
        VideoBitrate_Mbps,
        AudioCodec,
        AudioSampleRate `
    -AutoSize |
    Out-String)


============================================================
FILES ANALYZED
============================================================

$($Files.Count)


Reports per file:
$OutputDir


CSV:
$CSVPath

============================================================
"@


Set-Content `
    -Path $ComparisonPath `
    -Value $Comparison `
    -Encoding UTF8


# ============================================================
# FINISH
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "                     ANALYSIS SELESAI"
Write-Host "============================================================"
Write-Host ""

Write-Host "Output folder:"
Write-Host $OutputDir

Write-Host ""

Write-Host "File yang dibuat:"
Write-Host ""

Write-Host "  *_REPORT.txt"
Write-Host "  *_FFPROBE.json"
Write-Host "  SUMMARY.csv"
Write-Host "  COMPARISON.txt"

Write-Host ""

Write-Host "Jangan ubah file JSON sebelum dikirim untuk analisis."
Write-Host ""

Read-Host "Tekan Enter untuk keluar"