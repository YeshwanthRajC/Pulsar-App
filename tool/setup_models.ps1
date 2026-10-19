# Setup models for Pulsar (100% Offline Single-APK Bundling)
$ErrorActionPreference = "Stop"

$modelsDir = Join-Path $PSScriptRoot "..\assets\models"
if (-not (Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
}

$whistlePath = Join-Path $modelsDir "whistle.cact"
$needlePath = Join-Path $modelsDir "needle.cact"

# 1. Download Cactus Whistle (Speech-to-Text ASR model, ~16.9 MB)
if (-not (Test-Path $whistlePath)) {
    Write-Host "[1/2] Downloading Cactus Whistle model (whistle.cact)..." -ForegroundColor Cyan
    $whistleUrl = "https://huggingface.co/Cactus-Compute/whistle/resolve/main/whistle.cact"
    curl.exe -L -o $whistlePath $whistleUrl
    Write-Host "Cactus Whistle downloaded successfully." -ForegroundColor Green
} else {
    Write-Host "[1/2] Cactus Whistle model already exists." -ForegroundColor Green
}

# 2. Download Cactus Needle (Function-Calling Mini-LLM, ~35.3 MB)
if (-not (Test-Path $needlePath)) {
    Write-Host "[2/2] Downloading Cactus Needle 3 model (needle3.cact -> needle.cact)..." -ForegroundColor Cyan
    $needleUrl = "https://huggingface.co/Cactus-Compute/needle3/resolve/main/needle3.cact"
    curl.exe -L -o $needlePath $needleUrl
    Write-Host "Cactus Needle downloaded successfully." -ForegroundColor Green
} else {
    Write-Host "[2/2] Cactus Needle model already exists." -ForegroundColor Green
}

Write-Host "`nModels in assets/models:" -ForegroundColor Yellow
Get-ChildItem -Path $modelsDir -Filter "*.cact" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
Write-Host "Both models are ready! They will be packaged directly into the single APK when running 'flutter build apk'." -ForegroundColor Green
