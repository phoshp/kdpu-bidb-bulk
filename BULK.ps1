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

$ManualPrograms = @(
    @{
        Ad     = "ACS Unified Reader"
        Url    = "https://kamusm.bilgem.tubitak.gov.tr/islemler/surucu_yukleme_servisi/suruculer/AcsReader/64bit/Hepsi/ACS-Unified-MSI-Win-4290(ACS38T-WindowsAll).zip"
        Dosya  = "ACSReader.zip"
        SetupPath = "ACS-Unified-MSI-Win-4290\\Setup.exe"
    },
    @{
        Ad     = "AkisKart Sürücüsü"
        Url    = "https://kamusm.bilgem.tubitak.gov.tr/islemler/surucu_yukleme_servisi/suruculer/AkisKart/windows/64/Akia_windows-x64_6_5_4_exe.zip"
        Dosya  = "AkisKart.zip"
        SetupPath = "Akia_windows-x64_6_5_4.exe"
    },
)

$DownloadFolder = "$env:TEMP\BIDB_BULK"

function Test-WingetAvailable {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        return $true
    }

    $windowsAppsPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    $wingetAlias = Join-Path $windowsAppsPath "winget.exe"
    if (Test-Path $wingetAlias) {
        if (($env:Path -split ";") -notcontains $windowsAppsPath) {
            $env:Path = "$env:Path;$windowsAppsPath"
        }
        return $true
    }

    return $false
}

function Install-Winget {
    Write-Host "winget bulunamadı. GitHub üzerinden Windows Package Manager kuruluyor..." -ForegroundColor Yellow
    
    $wingetUrl = "https://github.com/microsoft/winget-cli/releases/download/v1.8.1911/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $wingetPath = "$env:TEMP\winget.msixbundle"

    try {
        Write-Host ">> İndiriliyor: WinGet (AppInstaller)..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath -UseBasicParsing
        
        Write-Host ">> Paket yükleniyor..." -ForegroundColor Cyan
        Add-AppxPackage -Path $wingetPath -ErrorAction Stop
    } catch {
        Write-Host "HATA: winget kurulamadı: $_" -ForegroundColor Red
    }

    if (Test-Path $wingetPath) { Remove-Item $wingetPath -Force -ErrorAction SilentlyContinue }

    if (Test-WingetAvailable) {
        Write-Host "winget başarıyla kuruldu." -ForegroundColor Green
        return $true
    }

    Write-Host "HATA: winget kurulumdan sonra bulunamadı." -ForegroundColor Red
    Write-Host "Microsoft Store üzerinden 'App Installer' kurup veya güncelleyip tekrar deneyin." -ForegroundColor Yellow
    return $false
}

function Install-WingetApps {
    if (-not (Test-WingetAvailable)) {
        if (-not (Install-Winget)) { return }
        winget upgrade Microsoft.AppInstaller
    }

    foreach ($id in $WingetApps.Keys) {
        $name = $WingetApps[$id]
        Write-Host "`n>> $name kuruluyor ($id)..." -ForegroundColor Cyan
        try {
            winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --source winget
        } catch {
            Write-Host "HATA: $name kurulamadı: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n>> Java Runtime Environment (32-bit) deneniyor..." -ForegroundColor Cyan
    try {
        winget install --id Oracle.JavaRuntimeEnvironment -e --architecture x86 --silent --accept-package-agreements --accept-source-agreements --source winget
    } catch {
        Write-Host "HATA: Java 32-bit otomatik kurulamadı. Gerekirse manuel indirin: https://www.java.com/download/" -ForegroundColor Red
    }
}

function Install-ManualPrograms {
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    foreach ($program in $ManualPrograms) {
        $downloadPath = Join-Path $DownloadFolder $program.Dosya

        Write-Host "`n>> $($program.Ad) indiriliyor..." -ForegroundColor Cyan
        try {
            curl.exe -L -o "$downloadPath" "$($program.Url)" 
        } catch {
            Write-Host "HATA: $($program.Ad) indirilemedi: $_" -ForegroundColor Red
            continue
        }

        $installerPath = $downloadPath
        if ([System.IO.Path]::GetExtension($installerPath) -eq ".zip") {
            $extractPath = Join-Path $DownloadFolder ([System.IO.Path]::GetFileNameWithoutExtension($program.Dosya))
            Write-Host ">> $($program.Ad) arşivden çıkarılıyor..." -ForegroundColor Cyan
            try {
                if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
                Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
            } catch {
                Write-Host "HATA: $($program.Ad) arşivi açılamadı: $_" -ForegroundColor Red
                continue
            }

            if ($program.SetupPath -ne "NONE") {
                $installer = Get-Item -Path (Join-Path $extractPath $program.SetupPath)
                if (-not $installer) {
                    Write-Host "UYARI: $($program.Ad) içinde çalıştırılabilir kurulum dosyası bulunamadı. Klasörü kontrol edin: $extractPath" -ForegroundColor Yellow
                    Start-Process explorer.exe $extractPath -Wait
                    continue
                }
                $installerPath = $installer.FullName
                Write-Host ">> $($installerPath) kurulumu başlatılıyor..." -ForegroundColor Green
                Start-Sleep -Seconds 1
                Start-Process -FilePath $installerPath -Wait
            }
        } else {
            $desktopFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
            $desktopPath = Join-Path $desktopFolder $program.Dosya
            Move-Item -Path $installerPath -Destination $desktopPath -Force
            Write-Host ">> $($program.Ad) masaüstüne eklendi: $desktopPath" -ForegroundColor Green
        } 
    }
}

function Invoke-InstallApps {
    Clear-Host
    Write-Host "`n===== PROGRAMLARI KUR =====" -ForegroundColor Magenta
    Install-WingetApps
    Install-ManualPrograms
    Write-Host "`nProgram kurulumu tamamlandı." -ForegroundColor Green
    Start-Sleep -Seconds 0.5
}



$AppAssocXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <!-- Browser Mappings -->
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  
  <!-- PDF Mappings -->
  <Association Identifier=".pdf" ProgId="Acrobat.Document.DC" ApplicationName="Adobe Acrobat Reader" />
</DefaultAssociations>
"@

function Invoke-Tweaks {
    Clear-Host
    Write-Host "`n===== İNCE AYAR =====" -ForegroundColor Magenta
    
    $TempXmlPath =Join-Path $env:TEMP "AppAssoc.xml"
    try {
        Set-Content -Path $TempXmlPath -Value $AppAssocXml -Encoding UTF8
        Import-Module DISM
        Dism.exe /Online /Import-DefaultAppAssociations:$TempXmlPath
        Write-Host "Varsayılan uygulamalar değiştirildi" -ForegroundColor Cyan
    }
    catch {
        Write-Error "HATA: $_"
    }

    $basePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }
    # {20D04FE0-3AEA-1069-A2D8-08002B30309D} = Bilgisayar (Bu PC)
    # {5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0} = Denetim Masası
    # {59031a47-3f72-44a7-89c5-5595fe6b30ee} = Kullanıcı Dosyaları
    New-ItemProperty -Path $basePath -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $basePath -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $basePath -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Host "Masaüstü ikonları eklendi" -ForegroundColor Cyan

    Stop-Process -ProcessName explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe

    Write-Host "İnce ayar tamamlandı." -ForegroundColor Green
    Start-Sleep -Seconds 0.5
}

function Invoke-WinActivation {
    Clear-Host
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
    Start-Sleep -Seconds 0.5
}

function Invoke-AllActions {
    Invoke-InstallApps
    Invoke-Tweaks
    Invoke-WinActivation
    Write-Host "`nTüm işlemler tamamlandı." -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "KDPÜ BİDB Windows Bulk Aracı v0.1.0" -ForegroundColor Yellow
    Write-Host "--------------------------------"
    Write-Host "1.) Hepsini uygula"
    Write-Host "2.) Programları kur"
    Write-Host "3.) İnce Ayar yap"
    Write-Host "4.) Windows Aktifleştir"
    Write-Host "0.) Çıkış"
    Write-Host ""
}

function Post-Action {
    [Console]::Beep(500, 800)
    Read-Host "`nDevam etmek için ENTER'a basın"
}

function Start-Toolkit {
    $currentUser = [Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "HATA: Programı yönetici olarak çalıştırın." -ForegroundColor Red
        return
    }
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    do {
        Show-Menu
        $secim = Read-Host "Seçimini gir"

        switch ($secim) {
            "1" { Invoke-AllActions; Post-Action }
            "2" { Invoke-InstallApps; Post-Action }
            "3" { Invoke-Tweaks; Post-Action }
            "4" { Invoke-WinActivation; Post-Action }
            "0" { Write-Host "Çıkılıyor..." -ForegroundColor Yellow }
            default { Write-Host "Geçersiz seçim, tekrar deneyin." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($secim -ne "0")
}

Start-Toolkit
