#Requires -Version 5.1
<#
    KDPÜ BİDB BULK Araci
    -------------------------------
    Toplu program kurulumu, ince ayar ve Windows aktivasyonu için basit CLI araç.
#>

# ----------
#  AYARLAR
# ----------

$WingetApps = [ordered]@{
    "Google.Chrome"                       = "Google Chrome"
    "RARLab.WinRAR"                       = "WinRAR"
    "Oracle.JavaRuntimeEnvironment"       = "Java Runtime Environment (64-bit)"
    "Adobe.Acrobat.Reader.64-bit"         = "Adobe Acrobat Reader"
}

$KamuSMTools = @(
    @{
        Ad   = "AkisKart Sürücüsü"
        Url  = "https://kamusm.bilgem.tubitak.gov.tr/islemler/surucu_yukleme_servisi/suruculer/AkisKart/windows/64/Akia_windows-x64_6_5_4_exe.zip"
        Zip  = "AkisKart.zip"
    },
    @{
        Ad   = "ACS Unified Reader"
        Url  = "https://kamusm.bilgem.tubitak.gov.tr/islemler/surucu_yukleme_servisi/suruculer/AcsReader/64bit/Hepsi/ACS-Unified-MSI-Win-4290(ACS38T-WindowsAll).zip"
        Zip  = "ACSReader.zip"
    }
)

$DownloadFolder = "$env:TEMP\KDPU_BIDB_BULK"

function Test-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (-not (Test-Admin)) {
        Write-Host "Bu araç yönetici izni gerektiriyor. Yeniden başlatılıyor..." -ForegroundColor Yellow
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Host "Yönetici izni alınamadı. Program kapatılıyor." -ForegroundColor Red
        }
        exit
    }
}

function Test-WingetAvailable {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "HATA: winget bulunamadı. App Installer güncel değil veya kurulu değil." -ForegroundColor Red
        Write-Host "Microsoft Store üzerinden 'App Installer' güncellemesi yapıp tekrar deneyin." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Install-WingetApps {
    if (-not (Test-WingetAvailable)) { return }

    foreach ($id in $WingetApps.Keys) {
        $name = $WingetApps[$id]
        Write-Host "`n>> $name kuruluyor ($id)..." -ForegroundColor Cyan
        try {
            winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        } catch {
            Write-Host "HATA: $name kurulamadı: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n>> Java Runtime Environment (32-bit) deneniyor..." -ForegroundColor Cyan
    try {
        winget install --id Oracle.JavaRuntimeEnvironment -e --architecture x86 --silent --accept-package-agreements --accept-source-agreements
    } catch {
        Write-Host "HATA: Java 32-bit otomatik kurulamadı. Gerekirse manuel indirin: https://www.java.com/download/" -ForegroundColor Red
    }
}

function Install-KamuSMTools {
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }
    foreach ($tool in $KamuSMTools) {
        $zipPath = Join-Path $DownloadFolder $tool.Zip
        $extractPath = Join-Path $DownloadFolder ([System.IO.Path]::GetFileNameWithoutExtension($tool.Zip))

        Write-Host "`n>> $($tool.Ad) indiriliyor..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $tool.Url -OutFile $zipPath -UseBasicParsing
        } catch {
            Write-Host "HATA: $($tool.Ad) indirilemedi: $_" -ForegroundColor Red
            continue
        }

        Write-Host ">> $($tool.Ad) arşivden çıkarılıyor..." -ForegroundColor Cyan
        try {
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        } catch {
            Write-Host "HATA: $($tool.Ad) arşivi açılamadı: $_" -ForegroundColor Red
            continue
        }

        $installer = Get-ChildItem -Path $extractPath -Recurse -Include *.exe, *.msi | Select-Object -First 1
        if ($installer) {
            Write-Host ">> $($tool.Ad) kurulumu başlatılıyor (manuel adımları tamamlayın): $($installer.Name)" -ForegroundColor Green
            Start-Process -FilePath $installer.FullName
            Write-Host "   Kurulum penceresi açıldı. Devam etmeden önce sihirbazı tamamlayın." -ForegroundColor Yellow
            Read-Host "   Kurulum bittiğinde devam etmek için ENTER'a basın"
        } else {
            Write-Host "UYARI: $($tool.Ad) içinde çalıştırılabilir kurulum dosyası bulunamadı. Klasörü kontrol edin: $extractPath" -ForegroundColor Yellow
            Start-Process explorer.exe $extractPath
        }
    }
}

function Invoke-InstallApps {
    Write-Host "`n===== PROGRAMLARI KUR =====" -ForegroundColor Magenta
    Install-WingetApps
    Install-KamuSMTools
    Write-Host "`nProgram kurulumu tamamlandı." -ForegroundColor Green
}

function Invoke-Tweaks {
    Write-Host "`n===== İNCE AYAR =====" -ForegroundColor Magenta
    Write-Host "Masaüstüne 'Bilgisayar' ve 'Denetim Masası' ikonları ekleniyor..." -ForegroundColor Cyan

    $basePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }

    # {20D04FE0-3AEA-1069-A2D8-08002B30309D} = Bilgisayar (Bu PC)
    # {5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0} = Denetim Masası
    New-ItemProperty -Path $basePath -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $basePath -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -PropertyType DWord -Force | Out-Null

    Write-Host "Masaüstü yenileniyor (explorer.exe yeniden başlatılacak)..." -ForegroundColor Cyan
    Stop-Process -ProcessName explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe

    Write-Host "İnce ayar tamamlandı." -ForegroundColor Green
}

function Invoke-WinActivation {
    Write-Host "`n===== WINDOWS AKTİFLEŞTİR =====" -ForegroundColor Magenta

    $productKey = (Read-Host "Windows ürün anahtarını girin (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)").Trim().ToUpperInvariant()

    if ([string]::IsNullOrWhiteSpace($productKey)) {
        Write-Host "Aktivasyon iptal edildi: Ürün anahtarı girilmedi." -ForegroundColor Yellow
        return
    }

    if ($productKey -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') {
        Write-Host "HATA: Ürün anahtarı XXXXX-XXXXX-XXXXX-XXXXX-XXXXX biçiminde olmalıdır." -ForegroundColor Red
        return
    }

    Write-Host "Lisans anahtarı giriliyor..." -ForegroundColor Cyan
    try {
        cscript.exe //Nologo "$env:windir\System32\slmgr.vbs" /ipk $productKey
    } catch {
        Write-Host "HATA: Anahtar girilemedi: $_" -ForegroundColor Red
        return
    }

    Write-Host "Windows aktifleştiriliyor..." -ForegroundColor Cyan
    try {
        cscript.exe //Nologo "$env:windir\System32\slmgr.vbs" /ato
    } catch {
        Write-Host "HATA: Aktivasyon başarısız: $_" -ForegroundColor Red
        return
    }

    Write-Host "Aktivasyon işlemi tamamlandı." -ForegroundColor Green
}

function Invoke-AllActions {
    Write-Host "`n===== HEPSİNİ UYGULA =====" -ForegroundColor Magenta
    Invoke-InstallApps
    Invoke-Tweaks
    Invoke-WinActivation
    Write-Host "`nTüm işlemler tamamlandı." -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "KDPÜ BİDB Windows Format Aracı" -ForegroundColor Yellow
    Write-Host "--------------------------------"
    Write-Host "1.) Hepsini uygula."
    Write-Host "2.) Programları kur."
    Write-Host "3.) İnce Ayar yap."
    Write-Host "4.) Windows Aktifleştir."
    Write-Host "0.) Çıkış"
    Write-Host ""
}

function Start-Toolkit {
    Ensure-Admin
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    do {
        Show-Menu
        $secim = Read-Host "Seçimini gir"

        switch ($secim) {
            "1" { Invoke-AllActions; Read-Host "`nDevam etmek için ENTER'a basın" }
            "2" { Invoke-InstallApps; Read-Host "`nDevam etmek için ENTER'a basın" }
            "3" { Invoke-Tweaks; Read-Host "`nDevam etmek için ENTER'a basın" }
            "4" { Invoke-WinActivation; Read-Host "`nDevam etmek için ENTER'a basın" }
            "0" { Write-Host "Çıkılıyor..." -ForegroundColor Yellow }
            default { Write-Host "Geçersiz seçim, tekrar deneyin." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($secim -ne "0")
}

Start-Toolkit
