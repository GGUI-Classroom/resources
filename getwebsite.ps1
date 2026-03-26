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
Write-Host "      [ G.GUI SCRAPER V2.1 ]" -ForegroundColor White
Write-Host "      By Extreem`n" -ForegroundColor Gray

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

# File Extensions
$mediaExt = "\.(mp3|mp4|wav|ogg|webm|mov)$"
$assetExt = "\.(css|js|png|jpg|jpeg|gif|svg|ico|woff2|pdf)$"
$pageExt  = "\.(html|php|asp|aspx|jsp|htm)$"

# 3. Execution Logic
while ($queue.Count -gt 0) {
    $currentUrl = $queue.Dequeue()
    $normalizedUrl = $currentUrl.Split('#')[0].TrimEnd('/')
    
    if ($visited.Contains($normalizedUrl)) { continue }
    $visited.Add($normalizedUrl) | Out-Null

    try {
        Write-Host "[QUEUED: $($queue.Count)] SCANNING: $normalizedUrl" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $normalizedUrl -UserAgent $agent -UseBasicParsing -ErrorAction Stop
        
        # --- Handle File Naming ---
        $uri = [System.Uri]$normalizedUrl
        $localPath = [uri]::UnescapeDataString($uri.AbsolutePath).Trim('/')
        
        $relativeFile = if ([string]::IsNullOrWhiteSpace($localPath)) { "index.html" } else { $localPath }
        
        # If the URL is a directory (doesn't have a file extension), save as index.html inside it
        if ($relativeFile -notmatch "\.\w{2,4}$") { 
            $relativeFile = Join-Path $relativeFile "index.html" 
        }

        $fullLocalPath = Join-Path $rootDestination $relativeFile
        $parentDir = Split-Path $fullLocalPath -Parent
        if (!(Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

        $response.Content | Out-File -FilePath $fullLocalPath -Encoding utf8
        Write-Host "  [+] Mirrored: $relativeFile" -ForegroundColor Green

        # --- Enhanced Scan (Captures spaces and extensionless routes) ---
        $pattern = '(?i)(?:href|src|data-src)\s*=\s*["'']([^"''>#]+)'
        $matches = [regex]::Matches($response.Content, $pattern)

        foreach ($m in $matches) {
            try {
                $rawLink = $m.Groups[1].Value.Trim()
                $uriObj = New-Object System.Uri([System.Uri]$normalizedUrl, $rawLink)
                $absoluteUrl = $uriObj.AbsoluteUri

                # Ensure we stay on the same domain
                if ($absoluteUrl -match [regex]::Escape($domain)) {
                    
                    # CASE A: Media & Assets
                    if ($absoluteUrl -match "$assetExt$|$mediaExt$") {
                        $assetUri = [System.Uri]$absoluteUrl
                        $assetPath = [uri]::UnescapeDataString($assetUri.AbsolutePath).TrimStart('/')
                        $destPath = Join-Path $rootDestination $assetPath
                        
                        if (!(Test-Path $destPath)) {
                            $destDir = Split-Path $destPath -Parent
                            if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                            
                            Write-Host "    -> Download: $assetPath" -ForegroundColor Cyan
                            Invoke-WebRequest -Uri $absoluteUrl -OutFile $destPath -UserAgent $agent -UseBasicParsing -ErrorAction SilentlyContinue
                        }
                    } 
                    # CASE B: Internal Pages (the files like 'Hollow Knight.html')
                    else {
                        $cleanTarget = $absoluteUrl.Split('#')[0].TrimEnd('/')
                        if (!$visited.Contains($cleanTarget)) { 
                            $queue.Enqueue($absoluteUrl) 
                        }
                    }
                }
            } catch { continue }
        }
    } catch {
        Write-Host "  [!] Error: $currentUrl" -ForegroundColor Red
    }
}

Write-Host "`n------------------------------------"
Write-Host "Deep Mirroring Complete." -ForegroundColor Yellow
pause
