<#
  Builds the three Go4Market panels from one codebase and patches each index.html
  (title, description, theme colour, favicon, manifest, noindex) for its hosting target.

    powershell -ExecutionPolicy Bypass -File tool/build_all.ps1            # all three
    powershell -ExecutionPolicy Bypass -File tool/build_all.ps1 seller     # just one

  Output: build/admin, build/seller, build/delivery (see root firebase.json hosting targets).
  Does NOT deploy.
#>
param([string[]]$Targets = @('admin', 'seller', 'delivery'))

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
Add-Type -AssemblyName System.Drawing

$panels = @{
  admin    = @{ Title = 'Go4Market Admin';    Short = 'G4M Admin';    Desc = 'Go4Market admin panel - orders, catalog, sellers, delivery, finance and settings.'; Color = '#0B8A4F' }
  seller   = @{ Title = 'Go4Market Seller Hub'; Short = 'G4M Seller'; Desc = 'Go4Market seller panel - manage your store, products, orders, POS and payouts.';   Color = '#E8740C' }
  delivery = @{ Title = 'Go4Market Delivery';  Short = 'G4M Delivery'; Desc = 'Go4Market delivery partner panel - go online, accept and complete deliveries.';     Color = '#2563EB' }
}

$logo = Join-Path $root '..\..\logo.png' | Resolve-Path
$appIcon = Join-Path $root '..\..\icons_512.png' | Resolve-Path

function Write-Icon([string]$src, [string]$dest, [int]$size, [string]$badgeHex) {
  $img = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($img, 0, 0, $size, $size)
  if ($badgeHex) {
    # Role badge dot in the bottom-right corner so the three panels are distinguishable in tabs.
    $c = [System.Drawing.ColorTranslator]::FromHtml($badgeHex)
    $d = [int]($size * 0.38); $x = $size - $d; $y = $size - $d
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), $x - 2, $y - 2, $d + 2, $d + 2)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $c), $x, $y, $d - 2, $d - 2)
  }
  $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}

foreach ($t in $Targets) {
  $p = $panels[$t]
  if (-not $p) { throw "Unknown target '$t' (admin|seller|delivery)" }
  $out = "build/$t"
  Write-Host "`n=== Building $t -> $out ===" -ForegroundColor Cyan
  & flutter build web --release -t "lib/main_$t.dart" -o $out --no-wasm-dry-run
  if ($LASTEXITCODE -ne 0) {
    # Older toolchains: fall back to the default output dir and copy.
    & flutter build web --release -t "lib/main_$t.dart"
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed for $t" }
    if (Test-Path $out) { Remove-Item -Recurse -Force $out }
    Copy-Item -Recurse build/web $out
  }

  # --- index.html ---
  $index = Join-Path $out 'index.html'
  $html = [IO.File]::ReadAllText($index)
  $html = $html -replace '<title>[^<]*</title>', "<title>$($p.Title)</title>"
  $html = $html -replace '(<meta name="description" content=")[^"]*(")', "`${1}$($p.Desc)`${2}"
  $html = $html -replace '(<meta name="theme-color" content=")[^"]*(")', "`${1}$($p.Color)`${2}"
  $html = $html -replace '(<meta name="apple-mobile-web-app-title" content=")[^"]*(")', "`${1}$($p.Title)`${2}"
  $html = $html -replace '(<div class="label" id="g4m-splash-label">)[^<]*(</div>)', "`${1}$($p.Title)`${2}"
  $html = $html -replace '#g4m-splash \{', "#g4m-splash { --g4m-accent: $($p.Color);"
  if ($html -notmatch 'name="robots"') { $html = $html -replace '<head>', "<head>`n  <meta name=`"robots`" content=`"noindex, nofollow`">" }
  [IO.File]::WriteAllText($index, $html, (New-Object System.Text.UTF8Encoding $false))

  # --- icons ---
  Write-Icon $logo (Join-Path $out 'favicon.png') 64 $p.Color
  New-Item -ItemType Directory -Force (Join-Path $out 'icons') | Out-Null
  Write-Icon $appIcon (Join-Path $out 'icons/Icon-192.png') 192 $null
  Write-Icon $appIcon (Join-Path $out 'icons/Icon-512.png') 512 $null
  Write-Icon $appIcon (Join-Path $out 'icons/Icon-maskable-192.png') 192 $null
  Write-Icon $appIcon (Join-Path $out 'icons/Icon-maskable-512.png') 512 $null

  # --- manifest ---
  $mf = Join-Path $out 'manifest.json'
  $m = Get-Content $mf -Raw | ConvertFrom-Json
  $m.name = $p.Title; $m.short_name = $p.Short; $m.description = $p.Desc
  $m.theme_color = $p.Color; $m.background_color = '#F7FAF8'
  [IO.File]::WriteAllText($mf, ($m | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))

  # --- push service worker (one per panel; must sit at the site root for FCM web) ---
  $sw = [IO.File]::ReadAllText((Join-Path $root 'web/firebase-messaging-sw.js'))
  $sw = $sw -replace "const PANEL_TITLE = '[^']*';", "const PANEL_TITLE = '$($p.Title)';"
  [IO.File]::WriteAllText((Join-Path $out 'firebase-messaging-sw.js'), $sw, (New-Object System.Text.UTF8Encoding $false))
  if (-not (Test-Path (Join-Path $out 'firebase-messaging-sw.js'))) { throw "firebase-messaging-sw.js missing in $out" }

  # --- robots.txt (belt and braces with X-Robots-Tag header in firebase.json) ---
  [IO.File]::WriteAllText((Join-Path $out 'robots.txt'), "User-agent: *`nDisallow: /`n")
  Write-Host "OK  $t" -ForegroundColor Green
}
