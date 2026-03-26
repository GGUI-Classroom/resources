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
Write-Host "      [ G.GUI ULTRA-DEEP SCAN v3.0 ]`n" -ForegroundColor White

# 2. Configuration
$inputUrl = Read-Host "Enter the website URL"
if ($inputUrl -notmatch "^http") { $inputUrl = "https://" + $inputUrl }
$baseUrl = $inputUrl.TrimEnd('/')
$domain = ([System.Uri]$baseUrl).Host

$destination = "$HOME\Downloads\SiteAssets"
if (!(Test-Path $destination)) { New-Item -ItemType Directory -Path $destination -Force }

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($baseUrl)
$visited = [System.Collections.Generic.HashSet[string]]::new()

# 3. Execution Logic
while ($queue.Count -gt 0) {
    $currentUrl = $queue.Dequeue()
    
    # Normalize URL to prevent duplicates (remove trailing slash and fragments)
    $normalizedUrl = $currentUrl.Split('#')[0].TrimEnd('/')
    if ($visited.Contains($normalizedUrl)) { continue }
    $visited.Add($normalizedUrl) | Out-Null

    try {
        Write-Host "[SCANNING] $normalizedUrl" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $normalizedUrl -UserAgent $agent -UseBasicParsing -ErrorAction Stop
        
        # Determine Filename (Handle home page vs sub-pages)
        $uri = [System.Uri]$normalizedUrl
        $path = $uri.AbsolutePath.Trim('/')
        $fileName = if ([string]::IsNullOrWhiteSpace($path)) { "index.html" } else { $path.Replace('/', '_') }
        if ($fileName -notmatch "\.(html|php|asp)$") { $fileName += ".html" }
        
        # Save the HTML
        $response.Content | Out-File -FilePath "$destination\$fileName" -Encoding utf8
        Write-Host "  [+] HTML Saved: $fileName" -ForegroundColor Green

        # 4. Global Regex Pattern (Matches href and src values)
        $pattern = '(?i)(?:href|src)\s*=\s*["'']([^"''>#\s]+)'
        $matches = [regex]::Matches($response.Content, $pattern)

        foreach ($m in $matches) {
            $rawLink = $m.Groups[1].Value
            $absoluteUrl = ""

            # Resolve to Absolute URL
            try {
                $uriObj = New-Object System.Uri([System.Uri]$normalizedUrl, $rawLink)
                $absoluteUrl = $uriObj.AbsoluteUri
            } catch { continue }

            # CASE A: Internal HTML (Queue it)
            if ($absoluteUrl -match $domain -and $absoluteUrl -notmatch "\.(png|jpg|jpeg|css|js|gif|svg|ico|woff2|pdf)$") {
                if (!$visited.Contains($absoluteUrl.Split('#')[0].TrimEnd('/'))) {
                    $queue.Enqueue($absoluteUrl)
                }
            }

            # CASE B: Assets (CSS, JS, Images)
            if ($absoluteUrl -match "\.(css|js|png|jpg|jpeg|gif|svg|ico|woff2)$") {
                $assetFileName = ($absoluteUrl -split '/')[-1].Split('?')[0]
                $assetPath = Join-Path $destination $assetFileName
                
                if (!(Test-Path $assetPath)) {
                    try {
                        Invoke-WebRequest -Uri $absoluteUrl -OutFile $assetPath -UserAgent $agent -Headers @{"Referer"=$normalizedUrl} -UseBasicParsing -ErrorAction SilentlyContinue
                        Write-Host "    -> Asset: $assetFileName" -ForegroundColor Cyan
                    } catch { 
                        Write-Host "    [!] Skipped: $assetFileName" -ForegroundColor DarkGray
                    }
                }
            }
        }
    } catch {
        Write-Host "  [!] Access Denied or 404: $currentUrl" -ForegroundColor Red
    }
}

Write-Host "`n------------------------------------"
Write-Host "Process Complete. Files located in Downloads\SiteAssets" -ForegroundColor Yellow
pause
