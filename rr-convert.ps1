#!/usr/bin/env pwsh
# rr-convert.ps1 — Convert Obsidian markdown to Royal Road-compatible HTML
# Windows PowerShell / pwsh script.
#
# Usage: .\rr-convert.ps1 input.md [-OutputFile output.html]

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,

    [Parameter(Position = 1)]
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Filter = Join-Path $ScriptDir "rr-convert.lua"
$Settings = Join-Path $ScriptDir "rr-convert.settings.lua"

# Validate inputs
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}
if (-not (Test-Path $Filter)) {
    Write-Error "Lua filter not found: $Filter"
    exit 1
}
if (-not (Test-Path $Settings)) {
    Write-Error "Settings file not found: $Settings"
    exit 1
}

# Find pandoc
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) {
    $candidates = @(
        "C:\Program Files\Pandoc\pandoc.exe",
        "C:\Program Files (x86)\Pandoc\pandoc.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $pandoc = $c
            break
        }
    }
}
if (-not $pandoc) {
    Write-Error "pandoc not found. Install from https://pandoc.org/installing.html"
    exit 1
}

# Preprocess: replace \[ with SOH+LB and \] with SOH+RB
$SOH_LB = [char]0x01 + "LB"
$SOH_RB = [char]0x01 + "RB"
$content = Get-Content -Raw -Path $InputFile
$content = $content -replace '\\\[', $SOH_LB
$content = $content -replace '\\\]', $SOH_RB

# Build pandoc arguments
$pandocArgs = @(
    "--from", "markdown+fenced_divs",
    "--to", "html",
    "--lua-filter", $Filter
)

if ($OutputFile) {
    $pandocArgs += "-o", $OutputFile
}

# Set environment variable for settings
$env:RR_CONVERT_SETTINGS = $Settings

# Run pandoc — pipe preprocessed content via stdin
$content | & $pandoc @pandocArgs 2>&1
