Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "VELVETEEN DFIR FRAMEWORK" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host ""
Write-Host "1. Run initial triage"
Write-Host "2. Scan collected candidates"
Write-Host "3. Review files manually"
Write-Host "4. Record confirmed evidence"
Write-Host ""

Write-Host "Select an option:"
Write-Host "1 - Run Quick Triage"
Write-Host "2 - Scan Candidates"
Write-Host "3 - Open Cases Folder"
Write-Host ""

$choice = Read-Host "Enter number"

switch ($choice) {
    "1" { & ".\00-triage\quick-triage.ps1" }
    "2" { & ".\01-case-management\scan-candidates.ps1" }
    "3" { Start-Process explorer.exe "$env:USERPROFILE\Desktop\Velveteen-Cases" }
    default { Write-Host "Invalid selection." }
}
