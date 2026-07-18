function Set-Windows10Tweaks {
    param([Logger] $Log)

    $Log.Info("Applying Windows 10 tweaks...")

    $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $searchPath)) {
        New-Item -Path $searchPath -Force | Out-Null
    }
    Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    $feedsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds"
    if (Test-Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds") {
        Set-ItemProperty -Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2 -ErrorAction SilentlyContinue
    }

    $Log.Success("Windows 10 tweaks applied.")
}

function Set-Windows11Tweaks {
    param([Logger] $Log)

    $Log.Info("Applying Windows 11 tweaks...")
    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advancedPath -Name "TaskbarDa" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advancedPath -Name "TaskbarMn" -Value 0 -ErrorAction SilentlyContinue

    $Log.Success("Windows 11 tweaks applied.")
}
