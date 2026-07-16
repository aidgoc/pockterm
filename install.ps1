$ErrorActionPreference = "Stop"
$Repo = if ($env:POCKTERM_REPO) { $env:POCKTERM_REPO } else { "https://github.com/aidgoc/pockterm" }
$Dir  = if ($env:POCKTERM_DIR)  { $env:POCKTERM_DIR }  else { "$HOME\.pockterm-app" }
Write-Host "-> Installing pockterm to $Dir"
if (-not (Test-Path "$Dir\.git")) { git clone --depth 1 $Repo $Dir } else { git -C $Dir pull --ff-only }
Set-Location $Dir
python -m venv .venv
& .\.venv\Scripts\pip.exe install -q -r requirements.txt
& .\.venv\Scripts\pip.exe install -q pywinpty==2.0.14
Write-Host "-> Starting pockterm. Scan the QR with the pockterm app (same Wi-Fi)."
& .\.venv\Scripts\python.exe -m pockterm
