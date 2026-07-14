Add-AppxPackage -Path https://aka.ms/getwinget

 [Environment]::SetEnvironmentVariable("Path", $($env:LOCALAPPDATA)+"\Microsoft\WindowsApps", "User")

 $winGetExefile = $($env:LOCALAPPDATA)+"\Microsoft\WindowsApps\winget.exe"

 Start-Process -FilePath $winGetExefile -ArgumentList "install --id=9NT1R1C2HH7J --source=msstore --accept-package-agreements --accept-source-agreements --silent"
 Start-Process -FilePath $winGetExefile -ArgumentList "install --id=XPFFXG0G03WN69 --source=msstore --accept-package-agreements --accept-source-agreements --silent"



 
