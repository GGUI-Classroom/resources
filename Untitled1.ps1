# 1. Visual Intro (3D Neon ASCII Art & Loading)
Clear-Host

$neonG = @"
  ██████╗      ██████╗ ██╗   ██╗ ██╗
 ██╔════╝     ██╔════╝ ██║   ██║ ██║
 ██║  ███╗    ██║  ███╗██║   ██║ ██║
 ██║   ██║    ██║   ██║██║   ██║ ██║
 ╚██████╔╝ ██╗╚██████╔╝╚██████╔╝ ██║
  ╚═════╝  ╚═╝ ╚═════╝  ╚═════╝  ╚═╝
"@

Write-Host $neonG -ForegroundColor Cyan
Write-Host "      [ G.GUI ASSET DOWNLOADER v1.0 ]`n" -ForegroundColor White

Write-Host "Initializing G.GUI modules..." -ForegroundColor Gray
for ($i = 1; $i -le 20; $i++) {
    Write-Progress -Activity "Loading G.GUI System" -Status "$($i*5)%" -PercentComplete ($i*5)
    Start-Sleep -Milliseconds 100
}
Write-Host "System Online.`n" -ForegroundColor Green

# 2. User Input
$url = Read-Host "Enter the website URL (e.g., example.com)"
if ($url -notmatch "^http") { $url = "https://" + $url }

$destination = "$HOME\Downloads\SiteAssets"
$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0"

# 3. Execution Logic
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $destination)) { New-Item -ItemType Directory -Path $destination -Force }

Write-Host "`nTargeting: $url" -ForegroundColor Yellow
Write-Host "Saving to: $destination" -ForegroundColor Yellow
Write-Host "------------------------------------"

try {
    # Download index.html
    $webPage = Invoke-WebRequest -Uri $url -UserAgent $agent -UseBasicParsing
    $webPage.Content | Out-File -FilePath "$destination\index.html" -Encoding utf8
    Write-Host "[+] index.html saved." -ForegroundColor Green

    # Scan for Assets
    $rawHtml = $webPage.Content
    $pattern = '(?<=src="|href=")[^"]+'
    $matches = [regex]::Matches($rawHtml, $pattern)

    foreach ($match in $matches) {
        $assetUrl = $match.Value
        
        # Fix Relative Paths
        if ($assetUrl -match "^//") { $assetUrl = "https:" + $assetUrl }
        elseif ($assetUrl -match "^/") { $assetUrl = $url.TrimEnd('/') + $assetUrl }
        elseif ($assetUrl -notmatch "^http") { $assetUrl = $url.TrimEnd('/') + "/" + $assetUrl }

        # Filter for Assets
        if ($assetUrl -match "\.(png|jpg|jpeg|css|js|gif|svg|ico)$") {
            try {
                $fileName = ($assetUrl -split '/')[-1].Split('?')[0]
                if (!$fileName) { continue }
                $filePath = Join-Path $destination $fileName
                
                Invoke-WebRequest -Uri $assetUrl -OutFile $filePath -UserAgent $agent -Headers @{"Referer"=$url} -UseBasicParsing -ErrorAction Stop
                Write-Host "  -> Downloaded: $fileName" -ForegroundColor Cyan
            } catch {
                Write-Host "  [!] Failed: $fileName" -ForegroundColor DarkGray
            }
        }
    }
} catch {
    Write-Host "`n[ERROR] Could not reach the site. Check URL or Internet." -ForegroundColor Red
}

Write-Host "`n------------------------------------"
Write-Host "Task Complete. Check Downloads\SiteAssets" -ForegroundColor Yellow
pause
