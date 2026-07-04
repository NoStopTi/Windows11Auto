function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Registry write failed: $Path\$Name - $_" -Level 'ERROR'
        return $false
    }
}

function Set-ProtectedRegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )

    $result = Set-RegistryValue $Path $Name $Value $Type
    if ($result) { return $true }

    Write-Log "Acesso negado. Tentando tomar posse da chave: $Path" -Level 'WARN'
    try {
        $hive = $Path -replace '^HKLM:\\', ''
        $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $hive,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership
        )
        if ($null -eq $regKey) { throw "Nao foi possivel abrir chave para TakeOwnership" }
        $acl = $regKey.GetAccessControl()
        $admin = [System.Security.Principal.NTAccount]'BUILTIN\Administrators'
        $acl.SetOwner($admin)
        $regKey.SetAccessControl($acl)
        $regKey.Close()

        $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $hive,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions
        )
        $acl = $regKey.GetAccessControl()
        $rule = [System.Security.AccessControl.RegistryAccessRule]::new(
            $admin,
            'FullControl',
            'ContainerInherit,ObjectInherit',
            'None',
            'Allow'
        )
        $acl.AddAccessRule($rule)
        $regKey.SetAccessControl($acl)
        $regKey.Close()

        Write-Log "Posse tomada. Tentando escrita novamente..." -Level 'INFO'
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Falha mesmo apos tomar posse: $Path\$Name - $_" -Level 'ERROR'
        return $false
    }
}

function Invoke-AsSystem {
    param([string]$ScriptBlock)

    $taskName = "ClaudeSecTask_$(Get-Random)"
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$ScriptBlock`""
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
        Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        Start-Sleep -Seconds 3
        return $true
    }
    catch {
        Write-Log "Falha ao executar como SYSTEM: $_" -Level 'ERROR'
        return $false
    }
    finally {
        try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    }
}

function Set-RegistryDefaultValue {
    param([string]$Path, $Value)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-Item -Path $Path -Value $Value -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Registry default value failed: $Path - $_" -Level 'ERROR'
        return $false
    }
}
