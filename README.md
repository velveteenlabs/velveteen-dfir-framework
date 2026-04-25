# Velveteen DFIR Framework

Velveteen DFIR Framework is a structured digital forensics and incident response workflow system.

It is designed to support:

- initial triage
- case setup
- evidence recording
- chain-of-custody logging
- artifact hashing and validation
- export and reporting
- investigation documentation

## Workflow

Quick Triage  
→ Case Initialization  
→ Evidence Recording  
→ Chain of Custody  
→ Artifact Processing  
→ Export and Verification  

## Start Here

Begin with:

scripts/00-triage/quick-triage.ps1

## Folder Structure

scripts/00-triage  
Initial system review and investigation launchers

scripts/01-case-management  
Case setup, evidence IDs, and evidence recording

scripts/02-chain-of-custody  
Chain logs, evidence transfer, export, and verification

scripts/03-artifact-processing  
Hashing, signing, finalizing, and validating artifacts

scripts/04-watch-mode  
Watcher scripts and monitoring templates

scripts/05-wireshark  
Wireshark helper notes and packet-analysis support

scripts/shared  
Reusable helper scripts

docs  
Workflow, methodology, and usage documentation

templates  
Reusable evidence, report, journal, and artifact templates

examples  
Sample outputs and mock investigation materials
