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
Write-Host "      [ G.GUI SCRAPER V2]" -ForegroundColor White
Write-Host "Made by @Extreem`n" -ForegroundColor Gray

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
        # Unescape converts %20 back to spaces for Windows
        $localPath = [uri]::UnescapeDataString($uri.AbsolutePath).Trim('/')
        
        $relativeFile = if ([string]::IsNullOrWhiteSpace($localPath)) { "index.html" } else { $localPath }
        if ($relativeFile -notmatch "\.(html|php|asp|css|js|png|jpg|jpeg|gif|svg|ico)$") { $relativeFile += ".html" }
        
        $fullLocalPath = Join-Path $rootDestination $relativeFile
        $parentDir = Split-Path $fullLocalPath -Parent
        if (!(Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

        $response.Content | Out-File -FilePath $fullLocalPath -Encoding utf8
        Write-Host "  [+] Saved: $relativeFile" -ForegroundColor Green

        # --- Enhanced Scan (Captures spaces within quotes) ---
        $pattern = '(?i)(?:href|src)\s*=\s*["'']([^"''>#]+)'
        $matches = [regex]::Matches($response.Content, $pattern)

        foreach ($m in $matches) {
            try {
                $rawLink = $m.Groups[1].Value.Trim()
                # Resolve to absolute URI (handles the heavy lifting of relative paths)
                $uriObj = New-Object System.Uri([System.Uri]$normalizedUrl, $rawLink)
                $absoluteUrl = $uriObj.AbsoluteUri

                # CASE A: Internal HTML Links
                if ($absoluteUrl -match [regex]::Escape($domain) -and $absoluteUrl -notmatch "\.(png|jpg|jpeg|css|js|gif|svg|ico|woff2|pdf)$") {
                    $cleanTarget = $absoluteUrl.Split('#')[0].TrimEnd('/')
                    if (!$visited.Contains($cleanTarget)) { $queue.Enqueue($absoluteUrl) }
                }

                # CASE B: Assets (CSS, JS, Images)
                if ($absoluteUrl -match "\.(css|js|png|jpg|jpeg|gif|svg|ico|woff2)$") {
                    $assetUri = [System.Uri]$absoluteUrl
                    # Convert URL path to a clean Windows path string
                    $assetRelativePath = [uri]::UnescapeDataString($assetUri.AbsolutePath).TrimStart('/')
                    $assetLocalPath = Join-Path $rootDestination $assetRelativePath
                    
                    if (!(Test-Path $assetLocalPath)) {
                        $assetDir = Split-Path $assetLocalPath -Parent
                        if (!(Test-Path $assetDir)) { New-Item -ItemType Directory -Path $assetDir -Force | Out-Null }
                        
                        Invoke-WebRequest -Uri $absoluteUrl -OutFile $assetLocalPath -UserAgent $agent -UseBasicParsing -ErrorAction SilentlyContinue
                        Write-Host "    -> Asset: $assetRelativePath" -ForegroundColor Cyan
                    }
                }
            } catch { continue }
        }
    } catch {
        Write-Host "  [!] Error: $currentUrl" -ForegroundColor Red
    }
}

Write-Host "`n------------------------------------"
Write-Host "Process Complete." -ForegroundColor Yellow
pause
