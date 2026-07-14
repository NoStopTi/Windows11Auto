irm https://claude.ai/install.ps1 | iex

$claudePath = "$env:USERPROFILE\.local\bin"

[Environment]::SetEnvironmentVariable(
    "Path",
    $claudePath,
    "User"
)
iable("Path", "User")