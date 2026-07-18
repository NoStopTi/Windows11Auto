$url = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"
$installerPath = "$env:TEMP\GoogleDriveSetup.exe"

function DownloadFile {
    param ($url, $path)

    $maxRetries = 3

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
            return $true
        }
        catch {
            Start-Sleep -Seconds 5
        }
    }

    return $false
}

if (DownloadFile $url $installerPath) {

    if (Test-Path $installerPath) {

        Start-Process -FilePath $installerPath `
            -ArgumentList "--silent" `
            -Wait

        Write-Output "Instalação finalizada."
      
        
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Output "File not found after download."
    }
}
else {
    Write-Output "tried many times and still failed."
}