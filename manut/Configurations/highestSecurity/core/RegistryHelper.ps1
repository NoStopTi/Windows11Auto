function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    }
    catch {
        Write-Log "Registry write failed: $Path\$Name - $_" -Level 'ERROR'
        return $false
    }
}

function Remove-RegistryValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
            }
        }
        return $true
    }
    catch {
        Write-Log "Registry remove failed: $Path\$Name - $_" -Level 'ERROR'
        return $false
    }
}

function Set-RegistryDefaultValue {
    param([string]$Path, $Value)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-Item -Path $Path -Value $Value -Force
        return $true
    }
    catch {
        Write-Log "Registry default value failed: $Path - $_" -Level 'ERROR'
        return $false
    }
}
