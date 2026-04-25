# =========================================
# Velveteen DFIR Framework
# Simple Triage (Auto Collect Mode)
# =========================================

$BaseDir = "$env:USERPROFILE\Desktop\Velveteen-Cases"
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$CaseName = Read-Host "Enter case name"
$CasePath = Join-Path $BaseDir $CaseName
$CandidatesDir = Join-Path $CasePath "Evidence-Candidates"

New-Item -ItemType Directory -Force -Path $CasePath | Out-Null
New-Item -ItemType Directory -Force -Path $CandidatesDir | Out-Null

$IndexFile = Join-Path $CasePath "candidate-index.csv"

Write-Host "`nCollecting triage artifacts..." -ForegroundColor Cyan

$SearchPaths = @(
    "$env:USERPROFILE\AppData\Local\Temp",
    "$env:USERPROFILE\AppData\Roaming",
    "$env:USERPROFILE\Downloads",
    "$env:ProgramData"
)

$Extensions = @("*.exe", "*.dll", "*.ps1", "*.bat", "*.cmd", "*.vbs", "*.js", "*.lnk")

$Collected = @()

foreach ($Path in $SearchPaths) {
    if (Test-Path $Path) {
        foreach ($Ext in $Extensions) {
            $Files = Get-ChildItem -Path $Path -Filter $Ext -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-14) }

            foreach ($File in $Files) {
                try {
                    $Dest = Join-Path $CandidatesDir $File.Name
                    Copy-Item $File.FullName $Dest -Force

                    $Hash = Get-FileHash $Dest -Algorithm SHA256

                    $Collected += [PSCustomObject]@{
                        FileName = $File.Name
                        OriginalPath = $File.FullName
                        StoredPath = $Dest
                        Size = $File.Length
                        LastModified = $File.LastWriteTime
                        SHA256 = $Hash.Hash
                    }

                    Write-Host "Collected: $($File.Name)"
                }
                catch {
                    # skip errors silently
                }
            }
        }
    }
}

if ($Collected.Count -eq 0) {
    Write-Host "`nNo recent artifacts found." -ForegroundColor Yellow
}
else {
    $Collected | Export-Csv $IndexFile -NoTypeInformation
    Write-Host "`nSaved index: $IndexFile" -ForegroundColor Green
}

Write-Host "`nOpening case folder..." -ForegroundColor Green
Start-Process explorer.exe $CasePath
