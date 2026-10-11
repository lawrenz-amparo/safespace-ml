# Runs the harassment model on this PC at http://127.0.0.1:7860.
# The live site calls that address from the browser, so AI analysis works
# in a browser on this same computer while this window is open.
#
# Usage: run.bat            (or: powershell -ExecutionPolicy Bypass -File run.ps1)
#        run.bat -Tunnel    (also expose it publicly via a Cloudflare tunnel and
#                            point netlify.toml at it; needs gh and a Netlify redeploy)
param(
    [switch]$Tunnel,
    [int]$Port = 7860,
    [string]$SiteRepo = 'lawrenz-amparo/safespace'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1. Python environment
$py = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $py)) {
    Write-Host '==> Creating virtual environment...'
    python -m venv .venv
}
if (-not (Test-Path '.venv\.deps-installed')) {
    Write-Host '==> Installing dependencies (first run only, ~1 GB)...'
    & $py -m pip install --upgrade pip
    # CPU build of torch: much smaller download, fast enough for single predictions
    & $py -m pip install torch --index-url https://download.pytorch.org/whl/cpu
    & $py -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
    New-Item '.venv\.deps-installed' -ItemType File | Out-Null
}

# Model checkpoint (same file the live site was tested with; the Hugging Face copy differs)
$modelFile = Join-Path $PSScriptRoot 'models\best_model.pt'
if (-not (Test-Path $modelFile)) {
    Write-Host '==> Downloading model checkpoint (~440 MB, first run only)...'
    New-Item -ItemType Directory -Force 'models' | Out-Null
    $ProgressPreference = 'SilentlyContinue'  # progress bar makes Invoke-WebRequest very slow
    Invoke-WebRequest 'https://github.com/lawrenz-amparo/safespace-ml/releases/download/model-v1/best_model.pt' -OutFile "$modelFile.part"
    Move-Item "$modelFile.part" $modelFile
}
$env:MODEL_PATH = $modelFile

# Optional: public tunnel and live-site redirect
$tunnelProc = $null
if ($Tunnel) {
    $cf = Join-Path $PSScriptRoot 'tools\cloudflared.exe'
    if (-not (Test-Path $cf)) {
        Write-Host '==> Downloading cloudflared...'
        New-Item -ItemType Directory -Force 'tools' | Out-Null
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile $cf
    }

    Write-Host '==> Starting Cloudflare tunnel...'
    $log = Join-Path $PSScriptRoot 'tools\tunnel.log'
    Remove-Item $log -ErrorAction SilentlyContinue
    $tunnelProc = Start-Process $cf -ArgumentList 'tunnel', '--no-autoupdate', '--url', "http://localhost:$Port" `
        -RedirectStandardError $log -RedirectStandardOutput "$log.out" -WindowStyle Hidden -PassThru

    $url = $null
    for ($i = 0; $i -lt 30 -and -not $url; $i++) {
        Start-Sleep 2
        if (Test-Path $log) {
            $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
            if ($m) { $url = $m.Matches[0].Value }
        }
    }
    if (-not $url) { Stop-Process -Id $tunnelProc.Id -ErrorAction SilentlyContinue; throw "Tunnel did not start; see $log" }
    Write-Host "==> Public URL: $url"

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "==> Updating netlify.toml in $SiteRepo (Netlify redeploys automatically)..."
        $toml = "[[redirects]]`n  from = `"/api/predict`"`n  to = `"$url/predict`"`n  status = 200`n  force = true`n"
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($toml))
        $sha = gh api "repos/$SiteRepo/contents/netlify.toml" --jq '.sha'
        gh api -X PUT "repos/$SiteRepo/contents/netlify.toml" -f message="Point /api/predict to $url" -f content=$b64 -f sha=$sha | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not update netlify.toml. Run "gh auth login", or edit it by hand.' }
        else { Write-Host '==> Live site will use this PC in ~30 seconds.' }
    } else {
        Write-Warning "GitHub CLI (gh) not found. Set the 'to' line in $SiteRepo/netlify.toml to: $url/predict"
    }
}

# 4. Model (foreground; Ctrl+C stops it and the tunnel)
Write-Host '==> Starting model (first run also downloads bert-base-uncased, ~440 MB)...'
$env:PORT = "$Port"
$env:PYTHONIOENCODING = 'utf-8'
try {
    & $py app.py
} finally {
    if ($tunnelProc) { Stop-Process -Id $tunnelProc.Id -ErrorAction SilentlyContinue }
}
