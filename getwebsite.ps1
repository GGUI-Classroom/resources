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
Write-Host "      [ G.GUI FULL SITE ASSET & HTML CLONER ]`n" -ForegroundColor White

# 2. User Input & Setup
$inputUrl = Read-Host "Enter the website URL (e.g., example.com)"
if ($inputUrl -notmatch "^http") { $inputUrl = "https://" + $inputUrl }
$baseUrl = $inputUrl.TrimEnd('/')

$destination = "$HOME\Downloads\SiteAssets"
if (!(Test-Path $destination)) { New-Item -ItemType Directory -Path $destination -Force }

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Queues for Crawling
$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($baseUrl)
$visited = [System.Collections.Generic.HashSet[string]]::new()

Write-Host "`nTargeting: $baseUrl" -ForegroundColor Yellow
Write-Host "Saving to: $destination" -ForegroundColor Yellow
Write-Host "------------------------------------"

# 3. Execution Logic
while ($queue.Count -gt 0) {
    $currentUrl = $queue.Dequeue()
    if ($visited.Contains($currentUrl)) { continue }
    $visited.Add($currentUrl) | Out-Null

    try {
        Write-Host "[*] Processing Page: $currentUrl" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $currentUrl -UserAgent $agent -UseBasicParsing -ErrorAction Stop
        
        # Determine Filename for HTML
        $pageName = ($currentUrl -split '/')[-1].Split('?')[0]
        if (!$pageName -or $pageName -notmatch "\.") { $pageName = "index.html" }
        if ($pageName -notmatch "\.html$") { $pageName += ".html" }
        
        # Save HTML Content
        $response.Content | Out-File -FilePath "$destination\$pageName" -Encoding utf8
        Write-Host "  [+] Saved HTML: $pageName" -ForegroundColor Green

        # Scan for Links and Assets
        $rawHtml = $response.Content
        $pattern = '(?<=src="|href=")[^"|#]+'
        $matches = [regex]::Matches($rawHtml, $pattern)

        foreach ($match in $matches) {
            $assetUrl = $match.Value
            
            # Resolve Relative Paths
            if ($assetUrl -match "^//") { $assetUrl = "https:" + $assetUrl }
            elseif ($assetUrl -match "^/") { $assetUrl = $baseUrl + $assetUrl }
            elseif ($assetUrl -notmatch "^http") { $assetUrl = $baseUrl + "/" + $assetUrl }

            # CASE A: It's an internal HTML link (Queue it for crawling)
            if ($assetUrl.StartsWith($baseUrl) -and ($assetUrl -match "\.(html|php|asp)$" -or $assetUrl -notmatch "\.\w{2,4}$")) {
                if (!$visited.Contains($assetUrl)) {
                    $queue.Enqueue($assetUrl)
                }
            }
            
            # CASE B: It's an Asset (Download it)
            if ($assetUrl -match "\.(png|jpg|jpeg|css|js|gif|svg|ico|pdf|woff2)$") {
                try {
                    $fileName = ($assetUrl -split '/')[-1].Split('?')[0]
                    $filePath = Join-Path $destination $fileName
                    if (!(Test-Path $filePath)) {
                        Invoke-WebRequest -Uri $assetUrl -OutFile $filePath -UserAgent $agent -Headers @{"Referer"=$currentUrl} -UseBasicParsing -ErrorAction Stop
                        Write-Host "    -> Asset: $fileName" -ForegroundColor Cyan
                    }
                } catch { 
                    continue # Skip failed individual assets
                }
            }
        }
    } catch {
        Write-Host "  [!] Error accessing: $currentUrl" -ForegroundColor DarkRed
    }
}

Write-Host "`n------------------------------------"
Write-Host "Task Complete. All pages and assets saved to Downloads\SiteAssets" -ForegroundColor Yellow
pause
