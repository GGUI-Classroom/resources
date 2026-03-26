# 1. Visual Intro
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
Write-Host "      [ G.GUI SCRAPER V2.2]" -ForegroundColor White
Write-Host "By @Extreem`n" -ForegroundColor Gray

# 2. Setup
$inputUrl = Read-Host "Enter the website URL"
if ($inputUrl -notmatch "^http") { $inputUrl = "https://" + $inputUrl }
$baseUrl = $inputUrl.TrimEnd('/')
$domain = ([System.Uri]$baseUrl).Host

$rootDestination = "$HOME\Downloads\SiteAssets"
$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($baseUrl)
$visited = [System.Collections.Generic.HashSet[string]]::new()

# Define supported extensions
$mediaExt = "\.(mp3|mp4|wav|ogg|webm|mov)$"
$assetExt = "\.(css|js|png|jpg|jpeg|gif|svg|ico|woff2|pdf|webmanifest)$"
$pageExt  = "\.(html|php|asp|aspx|jsp|htm)$"

# 3. Execution Logic
while ($queue.Count -gt 0) {
    $currentUrl = $queue.Dequeue()
    $normalizedUrl = $currentUrl.Split('#')[0].TrimEnd('/')
    if ($visited.Contains($normalizedUrl)) { continue }
    $visited.Add($normalizedUrl) | Out-Null

    try {
        Write-Host "[SCANNING] $normalizedUrl" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $normalizedUrl -UserAgent $agent -UseBasicParsing -ErrorAction Stop
        
        # --- Handle Folder Structure & Spaces ---
        $uri = [System.Uri]$normalizedUrl
        $localPath = [uri]::UnescapeDataString($uri.AbsolutePath).Trim('/')
        
        $relativeFile = if ([string]::IsNullOrWhiteSpace($localPath)) { "index.html" } else { $localPath }
        # Ensure it ends in .html if it's a page route
        if ($relativeFile -notmatch "$pageExt$|$assetExt$|$mediaExt$") { $relativeFile += ".html" }
        
        $fullLocalPath = Join-Path $rootDestination $relativeFile
        $parentDir = Split-Path $fullLocalPath -Parent
        if (!(Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

        $response.Content | Out-File -FilePath $fullLocalPath -Encoding utf8
        Write-Host "  [+] Saved: $relativeFile" -ForegroundColor Green

        # --- Enhanced Scan (Matches href, src, and data-src) ---
        $pattern = '(?i)(?:href|src|data-src)\s*=\s*["'']([^"''>#]+)'
        $matches = [regex]::Matches($response.Content, $pattern)

        foreach ($m in $matches) {
            try {
                $rawLink = $m.Groups[1].Value.Trim()
                $uriObj = New-Object System.Uri([System.Uri]$normalizedUrl, $rawLink)
                $absoluteUrl = $uriObj.AbsoluteUri

                # CASE A: Internal HTML Links (Keep Crawling)
                if ($absoluteUrl -match [regex]::Escape($domain)) {
                    if ($absoluteUrl -notmatch "$assetExt$|$mediaExt$") {
                        $cleanTarget = $absoluteUrl.Split('#')[0].TrimEnd('/')
                        if (!$visited.Contains($cleanTarget)) { $queue.Enqueue($absoluteUrl) }
                    }
                }

                # CASE B: Assets & Media (Download)
                if ($absoluteUrl -match "$assetExt$|$mediaExt$") {
                    $assetUri = [System.Uri]$absoluteUrl
                    $assetRelativePath = [uri]::UnescapeDataString($assetUri.AbsolutePath).TrimStart('/')
                    $assetLocalPath = Join-Path $rootDestination $assetRelativePath
                    
                    if (!(Test-Path $assetLocalPath)) {
                        $assetDir = Split-Path $assetLocalPath -Parent
                        if (!(Test-Path $assetDir)) { New-Item -ItemType Directory -Path $assetDir -Force | Out-Null }
                        
                        Write-Host "    -> Downloading: $assetRelativePath" -ForegroundColor Cyan
                        Invoke-WebRequest -Uri $absoluteUrl -OutFile $assetLocalPath -UserAgent $agent -UseBasicParsing -ErrorAction SilentlyContinue
                    }
                }
            } catch { continue }
        }
    } catch {
        Write-Host "  [!] Error: $currentUrl" -ForegroundColor Red
    }
}

Write-Host "`n------------------------------------"
Write-Host "Deep Scan Complete. Check Downloads\SiteAssets" -ForegroundColor Yellow
pause
