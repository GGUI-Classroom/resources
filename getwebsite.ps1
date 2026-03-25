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
Write-Host "      [ G.GUI DEEP SCAN & CLONE v2.0 ]`n" -ForegroundColor White

# 2. Setup
$inputUrl = Read-Host "Enter the website URL"
if ($inputUrl -notmatch "^http") { $inputUrl = "https://" + $inputUrl }
$baseUrl = $inputUrl.TrimEnd('/')

$destination = "$HOME\Downloads\SiteAssets"
if (!(Test-Path $destination)) { New-Item -ItemType Directory -Path $destination -Force }

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($baseUrl)
$visited = [System.Collections.Generic.HashSet[string]]::new()

Write-Host "`n[!] Starting deep crawl on: $baseUrl" -ForegroundColor Yellow

# 3. Execution Logic
while ($queue.Count -gt 0) {
    $currentUrl = $queue.Dequeue()
    
    # Skip if already visited or if it's an external link
    if ($visited.Contains($currentUrl) -or ($currentUrl -notmatch $baseUrl.Replace(".", "\."))) { continue }
    $visited.Add($currentUrl) | Out-Null

    try {
        Write-Host "Processing: $currentUrl" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $currentUrl -UserAgent $agent -UseBasicParsing -ErrorAction Stop
        
        # 4. Save the HTML Page
        $fileName = $currentUrl.Replace($baseUrl, "").Trim('/')
        if (!$fileName -or $fileName -eq "") { $fileName = "index.html" }
        if ($fileName -notmatch "\.(html|php|asp)$") { $fileName += ".html" }
        # Replace slashes in filename to prevent path errors
        $safeFileName = $fileName.Replace("/", "_")
        
        $response.Content | Out-File -FilePath "$destination\$safeFileName" -Encoding utf8
        Write-Host "  [+] Saved Page: $safeFileName" -ForegroundColor Green

        # 5. Scan for EVERYTHING (Links and Assets)
        $rawHtml = $response.Content
        # Improved Regex to catch almost any path in src or href
        $pattern = '(?<=href="|src=")[^"#\s>]+'
        $matches = [regex]::Matches($rawHtml, $pattern)

        foreach ($item in $matches) {
            $link = $item.Value
            
            # Resolve URL
            if ($link -match "^//") { $link = "https:" + $link }
            elseif ($link -match "^/") { $link = $baseUrl + $link }
            elseif ($link -notmatch "^http") { $link = $baseUrl + "/" + $link }

            # If it's an internal link (another page), add to queue
            if ($link.StartsWith($baseUrl)) {
                # Filter out obvious non-html files from the page queue
                if ($link -notmatch "\.(png|jpg|css|js|gif|svg|ico|woff|zip|pdf)$") {
                    if (!$visited.Contains($link)) { $queue.Enqueue($link) }
                }
                
                # If it IS an asset, download it
                if ($link -match "\.(png|jpg|jpeg|css|js|gif|svg|ico|woff2)$") {
                    $assetName = ($link -split '/')[-1].Split('?')[0]
                    $assetPath = Join-Path $destination $assetName
                    if (!(Test-Path $assetPath)) {
                        Invoke-WebRequest -Uri $link -OutFile $assetPath -UserAgent $agent -UseBasicParsing -ErrorAction SilentlyContinue
                        Write-Host "    -> Downloaded Asset: $assetName" -ForegroundColor Cyan
                    }
                }
            }
        }
    } catch {
        Write-Host "  [!] Failed to process: $currentUrl" -ForegroundColor DarkRed
    }
}

Write-Host "`n------------------------------------"
Write-Host "Deep Scan Complete. Check Downloads\SiteAssets" -ForegroundColor Yellow
pause
