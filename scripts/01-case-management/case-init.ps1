# =========================================
# Case Initialization
# =========================================

$CaseName = Read-Host "Enter Case Name"
$BasePath = "$env:USERPROFILE\Desktop\Velveteen-Cases\$CaseName"

New-Item -ItemType Directory -Force -Path $BasePath | Out-Null
New-Item -ItemType Directory -Force -Path "$BasePath\Evidence" | Out-Null
New-Item -ItemType Directory -Force -Path "$BasePath\Logs" | Out-Null

$LogFile = "$BasePath\case-log.txt"

@"
Case: $CaseName
Created: $(Get-Date)
Analyst: $env:USERNAME
"@ | Out-File $LogFile

Write-Host "Case created at: $BasePath" -ForegroundColor Green
