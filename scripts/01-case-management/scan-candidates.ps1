# =========================================
# Velveteen DFIR Framework
# Scan Evidence Candidates
# Purpose: Review collected triage artifacts and prioritize what to look at first
# =========================================

$BaseDir = "$env:USERPROFILE\Desktop\Velveteen-Cases"

if (-not (Test-Path $BaseDir)) {
    Write-Host "No Velveteen-Cases folder found. Run quick-triage first." -ForegroundColor Yellow
    exit
}

$Cases = Get-ChildItem $BaseDir -Directory

if (-not $Cases) {
    Write-Host "No cases found. Run quick-triage first." -ForegroundColor Yellow
    exit
}

Write-Host "`nAvailable cases:" -ForegroundColor Cyan

for ($i = 0; $i -lt $Cases.Count; $i++) {
    Write-Host "$($i + 1). $($Cases[$i].Name)"
}

$Choice = Read-Host "`nSelect case number"

if ($Choice -notmatch '^\d+$') {
    Write-Host "Invalid selection." -ForegroundColor Red
    exit
}

$Index = [int]$Choice - 1

if ($Index -lt 0 -or $Index -ge $Cases.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    exit
}

$CasePath = $Cases[$Index].FullName
$CaseName = $Cases[$Index].Name
$CandidatesDir = Join-Path $CasePath "Evidence-Candidates"
$ReportFile = Join-Path $CasePath "candidate-scan-report.txt"

if (-not (Test-Path $CandidatesDir)) {
    Write-Host "No Evidence-Candidates folder found for this case." -ForegroundColor Yellow
    exit
}

$Files = Get-ChildItem $CandidatesDir -File -ErrorAction SilentlyContinue

if (-not $Files) {
    Write-Host "No candidate files found." -ForegroundColor Yellow
    exit
}

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

$Report = @()

$Report += @"
=========================================
VELVETEEN DFIR FRAMEWORK — CANDIDATE SCAN
=========================================

Case:
$CaseName

Purpose:
Scan files collected by quick-triage and prioritize which candidates deserve review first.

This report does not determine malicious activity.
It highlights files that deserve review based on simple heuristics.

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
ANALYST NOTES
=========================================

This scan is intentionally noisy.

The goal is not to remove every normal file.
The goal is to organize collected candidates so an analyst can review them in a sensible order.

A file becomes more interesting when multiple conditions line up, such as:

- runnable file type
- recent modification
- unsigned or invalid signature
- generic/common filename
- large file size
- repeated appearance across reports or cases

Do not delete or modify files based only on this report.

=========================================
NEXT STEPS
=========================================

Recommended workflow:

1. Review files under REVIEW FIRST.
2. If needed, review files under REVIEW NEXT.
3. Leave REFERENCE / LOW CONTEXT files as background context.
4. Promote files to confirmed evidence only after analyst review.
5. Preserve hashes and original paths.

Potential next script:

scripts/01-case-management/mark-evidence.ps1

=========================================
"@

$Report | Out-File $ReportFile -Encoding UTF8

Start-Process notepad.exe $ReportFile

Write-Host ""
Write-Host "Candidate scan complete." -ForegroundColor Green
Write-Host "Report saved to: $ReportFile"
