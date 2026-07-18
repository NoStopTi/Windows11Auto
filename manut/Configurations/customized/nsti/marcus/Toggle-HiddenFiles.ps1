<#
.SYNOPSIS
    Shows or hides hidden and protected operating system files in Windows Explorer.

.DESCRIPTION
    Toggles the Windows Explorer registry settings that control the visibility
    of hidden files/folders and protected system files.

.PARAMETER ShowHidden
    $true  -> Windows Explorer shows hidden files AND protected system files.
    $false -> Windows Explorer hides hidden files AND protected system files
              (forces them back to hidden even if they were already visible).

.EXAMPLE
    .\Toggle-HiddenFiles.ps1 -ShowHidden $true

.EXAMPLE
    .\Toggle-HiddenFiles.ps1 -ShowHidden $false
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [bool]$ShowHidden
)

$explorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($ShowHidden) {
    # 1 = show hidden files and folders
    Set-ItemProperty -Path $explorerAdvancedPath -Name "Hidden" -Value 1 -Type DWord
    # 1 = show protected operating system files
    Set-ItemProperty -Path $explorerAdvancedPath -Name "ShowSuperHidden" -Value 1 -Type DWord
    Write-Host "Hidden and protected system files are now VISIBLE." -ForegroundColor Green
}
else {
    # 2 = do not show hidden files and folders
    Set-ItemProperty -Path $explorerAdvancedPath -Name "Hidden" -Value 2 -Type DWord
    # 0 = hide protected operating system files
    Set-ItemProperty -Path $explorerAdvancedPath -Name "ShowSuperHidden" -Value 0 -Type DWord
    Write-Host "Hidden and protected system files are now HIDDEN." -ForegroundColor Yellow
}

# Restart Explorer so the change takes effect immediately
Stop-Process -Name explorer -Force
Start-Process explorer.exe
