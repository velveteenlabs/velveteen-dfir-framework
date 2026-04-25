# =========================================
# Velveteen DFIR Framework
# Full Investigation Runner
# =========================================

$BaseDir = "$env:USERPROFILE\Desktop\Velveteen-Cases"
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "VELVETEEN FULL INVESTIGATION" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host ""
Write-Host "This runner will:"
Write-Host "1. Create or use a case folder"
Write-Host "2. Collect triage artifacts"
Write-Host "3. Scan collected candidates"
Write-Host "4. Open the case folder"
Write-Host ""

$CaseName = Read-Host "Enter case name"
if ([string]::IsNullOrWhiteSpace($CaseName)) {
    Write-Host "Case name cannot be blank." -ForegroundColor Red
    exit
}

$CasePath = Join-Path $BaseDir $CaseName
$CandidatesDir = Join-Path $CasePath "Evidence-Candidates"
$LogsDir = Join-Path $CasePath "Logs"

New-Item -ItemType Directory -Force -Path $CasePath | Out-Null
New-Item -ItemType Directory -Force -Path $CandidatesDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

$RunLog = Join-Path $LogsDir "full-investigation-run-log.txt"

@"
=========================================
VELVETEEN FULL INVESTIGATION RUN
=========================================

Case Name: $CaseName
Started: $(Get-Date)
Analyst: $env:USERNAME
Host: $env:COMPUTERNAME

=========================================
"@ | Out-File $RunLog -Encoding UTF8

Write-Host ""
Write-Host "[1/3] Collecting triage artifacts..." -ForegroundColor Cyan

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
                    $SafeName = $File.Name
                    $Dest = Join-Path $CandidatesDir $SafeName

                    if (Test-Path $Dest) {
                        $Base = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
                        $Extension = [System.IO.Path]::GetExtension($File.Name)
                        $Stamp = Get-Date -Format "yyyyMMddHHmmssfff"
                        $SafeName = "$Base-$Stamp$Extension"
                        $Dest = Join-Path $CandidatesDir $SafeName
                    }

                    Copy-Item $File.FullName $Dest -Force

                    $Hash = Get-FileHash $Dest -Algorithm SHA256

                    $Collected += [PSCustomObject]@{
                        FileName = $SafeName
                        OriginalPath = $File.FullName
                        StoredPath = $Dest
                        Size = $File.Length
                        LastModified = $File.LastWriteTime
                        SHA256 = $Hash.Hash
                    }

                    Write-Host "Collected: $SafeName"
                }
                catch {
                    "Failed to collect: $($File.FullName)" | Out-File $RunLog -Append
                }
            }
        }
    }
}

$IndexFile = Join-Path $CasePath "candidate-index.csv"

if ($Collected.Count -gt 0) {
    $Collected | Export-Csv $IndexFile -NoTypeInformation
    "Collected $($Collected.Count) candidate files." | Out-File $RunLog -Append
}
else {
    "No candidate files collected." | Out-File $RunLog -Append
}

Write-Host ""
Write-Host "[2/3] Scanning candidates..." -ForegroundColor Cyan

$Files = Get-ChildItem $CandidatesDir -File -ErrorAction SilentlyContinue

$ReviewFirst = @()
$ReviewNext = @()
$Reference = @()

foreach ($File in $Files) {
    $Flags = @()
    $ScoreReasons = @()
    $Score = 0

    $Hash = Get-FileHash $File.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue
    $SizeMB = [math]::Round($File.Length / 1MB, 2)
    $Recent = $File.LastWriteTime -gt (Get-Date).AddDays(-7)

    if ($File.Extension -match "\.exe|\.dll|\.ps1|\.bat|\.cmd|\.vbs|\.js|\.lnk") {
        $Flags += "Script or executable file (can run code)"
        $ScoreReasons += "+2 runnable file type"
        $Score += 2
    }

    if ($Recent) {
        $Flags += "Recently modified (last 7 days)"
        $ScoreReasons += "+1 recent modification"
        $Score += 1
    }

    if ($File.Name -match "update|helper|service|host|client|sync|temp|install|setup|run|loader") {
        $Flags += "Name is generic/common — worth a closer look"
        $ScoreReasons += "+1 generic/common filename"
        $Score += 1
    }

    if ($SizeMB -gt 50) {
        $Flags += "Large file (may contain more functionality or payload)"
        $ScoreReasons += "+1 large file"
        $Score += 1
    }

    $SignatureStatus = "Not checked"

    if ($File.Extension -match "\.exe|\.dll") {
        try {
            $Sig = Get-AuthenticodeSignature $File.FullName
            $SignatureStatus = $Sig.Status

            if ($Sig.Status -ne "Valid") {
                $Flags += "Not digitally signed or signature invalid"
                $ScoreReasons += "+2 unsigned/invalid signature"
                $Score += 2
            }
            else {
                $Flags += "Digitally signed (likely legitimate, but still review if needed)"
            }
        }
        catch {
            $SignatureStatus = "Signature check failed"
            $Flags += "Could not verify digital signature"
            $ScoreReasons += "+1 signature check failed"
            $Score += 1
        }
    }

    if ($Flags.Count -eq 0) {
        $Flags += "No strong review flags from current rules"
    }

    if ($ScoreReasons.Count -eq 0) {
        $ScoreReasons += "No score-increasing rules matched"
    }

    $Entry = [PSCustomObject]@{
        Name = $File.Name
        Path = $File.FullName
        SizeMB = $SizeMB
        LastModified = $File.LastWriteTime
        SHA256 = $Hash.Hash
        Signature = $SignatureStatus
        Flags = ($Flags -join "; ")
        Score = $Score
        WhyThisScore = ($ScoreReasons -join "; ")
    }

    if ($Score -ge 5) {
        $ReviewFirst += $Entry
    }
    elseif ($Score -ge 3) {
        $ReviewNext += $Entry
    }
    else {
        $Reference += $Entry
    }
}

$ReportFile = Join-Path $CasePath "candidate-scan-report.txt"

$Report = @()

$Report += @"
=========================================
VELVETEEN DFIR FRAMEWORK — FULL INVESTIGATION
=========================================

Case:
$CaseName

Purpose:
Collect triage artifacts, scan candidate files, and prioritize what to review first.

This report does not determine malicious activity.
It highlights files that deserve review based on simple heuristics.

=========================================

SUMMARY

Collected candidate files:
$($Collected.Count)

Review First:
$($ReviewFirst.Count)

Review Next:
$($ReviewNext.Count)

Reference / Low Context:
$($Reference.Count)

=========================================

FLAGS EXPLAINED

These flags are simple heuristics to help guide review.
They do NOT indicate malicious activity on their own.
Multiple flags together may make a file more interesting to inspect.

Score guide:
0–2 = Reference / Low Context
3–4 = Review Next
5+  = Review First

=========================================
"@

function Add-Bucket {
    param(
        [string]$Title,
        [array]$Items,
        [string]$Description
    )

    $script:Report += ""
    $script:Report += "========================================="
    $script:Report += $Title
    $script:Report += "========================================="
    $script:Report += $Description

    if (-not $Items -or $Items.Count -eq 0) {
        $script:Report += ""
        $script:Report += "None."
        return
    }

    foreach ($Item in $Items) {
        $script:Report += ""
        $script:Report += "Name: $($Item.Name)"
        $script:Report += "Path: $($Item.Path)"
        $script:Report += "Size MB: $($Item.SizeMB)"
        $script:Report += "Last Modified: $($Item.LastModified)"
        $script:Report += "SHA256: $($Item.SHA256)"
        $script:Report += "Signature: $($Item.Signature)"
        $script:Report += "Flags: $($Item.Flags)"
        $script:Report += "Score: $($Item.Score)"
        $script:Report += "Why this score: $($Item.WhyThisScore)"
    }
}

Add-Bucket "REVIEW FIRST" $ReviewFirst "Files with the most review signals. Look here first, but do not assume these are malicious."
Add-Bucket "REVIEW NEXT" $ReviewNext "Files with some review signals. Inspect after Review First if needed."
Add-Bucket "REFERENCE / LOW CONTEXT" $Reference "Files retained for context. These may still matter later if they connect to other findings."

$Report += @"

=========================================
NEXT STEPS
=========================================

Recommended workflow:

1. Review files under REVIEW FIRST.
2. If needed, review files under REVIEW NEXT.
3. Leave REFERENCE / LOW CONTEXT files as background context.
4. Promote files to confirmed evidence only after analyst review.
5. Preserve hashes and original paths.

Useful next scripts:

scripts/01-case-management/record-evidence.ps1
scripts/02-chain-of-custody/chain-log.ps1
scripts/02-chain-of-custody/export-and-verify.ps1

=========================================
"@

$Report | Out-File $ReportFile -Encoding UTF8

@"
Scan completed: $(Get-Date)
Candidate index: $IndexFile
Candidate scan report: $ReportFile
Review First: $($ReviewFirst.Count)
Review Next: $($ReviewNext.Count)
Reference: $($Reference.Count)
"@ | Out-File $RunLog -Append

Write-Host ""
Write-Host "[3/3] Opening report and case folder..." -ForegroundColor Cyan

Start-Process notepad.exe $ReportFile
Start-Process explorer.exe $CasePath

Write-Host ""
Write-Host "Full investigation complete." -ForegroundColor Green
Write-Host "Case folder: $CasePath"
Write-Host "Report: $ReportFile"
