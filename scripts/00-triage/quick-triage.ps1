# =========================================
# Velveteen DFIR Framework
# Quick Triage
# =========================================

Write-Host "=== Velveteen Quick Triage ===" -ForegroundColor Cyan

$Time = Get-Date
$User = $env:USERNAME
$HostName = $env:COMPUTERNAME

Write-Host "`n[System Info]"
Write-Host "Time: $Time"
Write-Host "User: $User"
Write-Host "Host: $HostName"

Write-Host "`n[Running Processes]"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

Write-Host "`n[Network Connections]"
Get-NetTCPConnection | Where-Object { $_.State -eq "Established" } | Select-Object -First 10

Write-Host "`n[Startup Items]"
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command

Write-Host "`nTriage complete."
