#Requires -Version 5.1
<#
    KDPU BIDB BULK Araci (Offline)
    -------------------------------
    Toplu program kurulumu, ince ayar ve Windows aktivasyonu icin basit CLI arac.
#>
Set-Location $PSScriptRoot

$Programs = @(
    @{
        Name    = "WinRAR"
        Path = "winrar-x64.exe"
        Args = "/S"
    },
    @{
        Name    = "Java Runtime(x64)"
        Path = "jre-8u503-windows-x64.exe"
        Args = "/s INSTALL_SILENT=Enable AUTO_UPDATE=Disable SPONSORS=Disable REBOOT=Disable"
    },
    @{
        Name    = "Java Runtime(x32)"
        Path = "jre-8u503-windows-i586.exe"
        Args = "/s INSTALL_SILENT=Enable AUTO_UPDATE=Disable SPONSORS=Disable REBOOT=Disable"
    },
    @{
        Name    = "Google Chrome"
        Path = "GoogleChromeEnterprise64.msi"
        Args = ""
    },
    @{
        Name     = "ACS Unified Reader"
        Path = "ACS-Unified\\Setup.exe"
        Args = "/q /norestart"
    },
    @{
        Name     = "AkisKart Surucusu"
        Path  = "Akia.exe"
        Args = "-q"
    },
    @{
        Name    = "Adobe Acrobat Reader"
        Path = "AcrobatReader.exe"
        Args = "/sAll /rs /msi EULA_ACCEPT=YES /norestart /passive"
    },
    @{
        Name    = "Office 2016"
        Path = "Office2016x64\\setup.exe"
        Args = " "
    }
)

function Invoke-InstallApps {
    Write-Host "`n===== PROGRAMLARI KUR =====" -ForegroundColor Magenta
    foreach ($program in $Programs) {
        $programName = $program.Name
        $programPath = $program.Path
        $programArgs = $program.Args

        Write-Host "`n$programName kuruluyor..." -ForegroundColor Cyan

        if (-not (Test-Path -Path $programPath)) {
            Write-Host "HATA: $programName dosyasi bulunamadi: $programPath" -ForegroundColor Red
            continue
        }
        try {
            if ($programPath -like "*.msi") {
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$programPath`" $programArgs /passive /norestart" -Wait
            } else {
                Start-Process -FilePath $programPath -ArgumentList $programArgs -Wait
            }
            Write-Host "$programName basariyla kuruldu." -ForegroundColor Green
        } catch {
            Write-Host "HATA: $programName kurulumu basarisiz oldu: $_" -ForegroundColor Red
        }
    }
    Write-Host "`nProgram kurulumu tamamlandi." -ForegroundColor Green
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
    Write-Host "`n===== INCE AYAR =====" -ForegroundColor Magenta

    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -ErrorAction SilentlyContinue

    $ExplorerPath = "C:\Windows\explorer.exe"
    $ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    Start-Process -FilePath ".\syspin.exe" -ArgumentList "`"$ExplorerPath`" 5386" -Wait
    if (Test-Path $ChromePath) {
        Start-Process -FilePath ".\syspin.exe" -ArgumentList "`"$ChromePath`" 5386" -Wait
    }

    Write-Host "Gorev cubugu duzeni degistirildi" -ForegroundColor Cyan
    
    $TempXmlPath = Join-Path $env:TEMP "AppAssoc.xml"
    try {
        Set-Content -Path $TempXmlPath -Value $AppAssocXml -Encoding UTF8
        Import-Module DISM
        Dism.exe /Online /Import-DefaultAppAssociations:$TempXmlPath
        Write-Host "Varsayilan uygulamalar degistirildi" -ForegroundColor Cyan
    }
    catch {
        Write-Error "HATA: $_"
    }

    $basePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }
    # {20D04FE0-3AEA-1069-A2D8-08002B30309D} = Bilgisayar (Bu PC)
    # {5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0} = Denetim Masasi
    # {59031a47-3f72-44a7-89c5-5595fe6b30ee} = Kullanici Dosyalari
    New-ItemProperty -Path $basePath -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $basePath -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $basePath -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Host "Masaustu ikonlari eklendi" -ForegroundColor Cyan

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Write-Host "Ince ayar tamamlandi." -ForegroundColor Green
    Start-Sleep -Seconds 0.5
}

function Invoke-Activation {
    Write-Host "`n===== LISANS AKTIFLESTIR =====" -ForegroundColor Magenta

    $productKey = Get-Content -Path "win10key.txt" -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($productKey)) {
        Write-Host "HATA: Windows urun anahtari gecersiz!" -ForegroundColor Red
        return
    }

    if ($productKey -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') {
        Write-Host "HATA: Urun anahtari XXXXX-XXXXX-XXXXX-XXXXX-XXXXX biciminde olmalidir." -ForegroundColor Red
        return
    }

    Write-Host "Lisans anahtari giriliyor..." -ForegroundColor Cyan
    try {
        cscript.exe //Nologo "$env:windir\System32\slmgr.vbs" /ipk $productKey
    } catch {
        Write-Host "HATA: Anahtar girilemedi: $_" -ForegroundColor Red
        return
    }

    Write-Host "Windows aktiflestiriliyor..." -ForegroundColor Cyan
    try {
        cscript.exe //Nologo "$env:windir\System32\slmgr.vbs" /ato
    } catch {
        Write-Host "HATA: Aktivasyon basarisiz: $_" -ForegroundColor Red
        return
    }
    $OfficePath = "C:\Program Files\Microsoft Office\Office16"
    $OfficeKey = Get-Content -Path "office2016key.txt" -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($OfficeKey)) {
        Write-Host "HATA: Office urun anahtari gecersiz" -ForegroundColor Red
        return
    }

    Write-Host "Office 2016 urun anahtari giriliyor..." -ForegroundColor Cyan
    cscript "$OfficePath\ospp.vbs" /inpkey:$OfficeKey

    Write-Host "Office 2016 aktiflestiriliyor..." -ForegroundColor Cyan
    cscript "$OfficePath\ospp.vbs" /act

    Write-Host "Aktivasyon islemi tamamlandi." -ForegroundColor Green
    Start-Sleep -Seconds 0.5
}

function Invoke-AllActions {
    Invoke-InstallApps
    Invoke-Tweaks
    Invoke-Activation
    Write-Host "`nTum islemler tamamlandi." -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "KDPU BIDB OFFLINE Windows Bulk Araci v1.0" -ForegroundColor Yellow
    Write-Host "--------------------------------"
    Write-Host "1.) Hepsini uygula"
    Write-Host "2.) Programlari kur"
    Write-Host "3.) Ince Ayar yap"
    Write-Host "4.) Lisans Aktiflestir"
    Write-Host "0.) Cikis"
    Write-Host ""
}

function Post-Action {
    [Console]::Beep(500, 800)
    Read-Host "`nDevam etmek icin ENTER'a basin"
}

function Start-Toolkit {
    $currentUser = [Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "HATA: Programi yonetici olarak calistirin." -ForegroundColor Red
        return
    }
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    do {
        Show-Menu
        $secim = Read-Host "Secimini gir"

        switch ($secim) {
            "1" { Invoke-AllActions; Post-Action }
            "2" { Invoke-InstallApps; Post-Action }
            "3" { Invoke-Tweaks; Post-Action }
            "4" { Invoke-Activation; Post-Action }
            "0" { Clear-Host; }
            default { Write-Host "Gecersiz secim, tekrar deneyin." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($secim -ne "0")
}

Start-Toolkit
