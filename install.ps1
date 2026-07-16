$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = if ($env:POCKTERM_REPO) { $env:POCKTERM_REPO } else { "aidgoc/pockterm" }
$Dir  = if ($env:POCKTERM_DIR)  { $env:POCKTERM_DIR }  else { "$HOME\.pockterm-app" }

if ($env:POCKTERM_REF) {
  $Ref = $env:POCKTERM_REF
} else {
  try {
    $latest = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" `
      -Headers @{ "User-Agent" = "pockterm-installer" }
    $Ref = $latest.tag_name
  } catch {
    $Ref = $null
  }
  if (-not $Ref) {
    Write-Error "pockterm: could not resolve the latest release. Set `$env:POCKTERM_REF=vX.Y.Z and retry."
    exit 1
  }
}

Write-Host "-> Installing pockterm $Ref to $Dir"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Tmp = Join-Path $env:TEMP "pockterm-$Ref.tar.gz"
Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/tags/$Ref.tar.gz" `
  -OutFile $Tmp -Headers @{ "User-Agent" = "pockterm-installer" }
tar -xzf $Tmp -C $Dir --strip-components=1
Remove-Item $Tmp -Force

Set-Location $Dir
python -m venv .venv
& .\.venv\Scripts\pip.exe install -q -r requirements.txt
& .\.venv\Scripts\pip.exe install -q "pywinpty>=2.0.14"

if ($env:POCKTERM_INSTALL_ONLY -eq "1") {
  Write-Host "-> Installed to $Dir (POCKTERM_INSTALL_ONLY set); not launching."
  exit 0
}

Write-Host "-> Starting pockterm. Scan the QR with the pockterm app (same Wi-Fi)."
& .\.venv\Scripts\python.exe -m pockterm
