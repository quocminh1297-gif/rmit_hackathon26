$deviceCode = "sO1d78-wzhzuUXffjGSor_ivNaTRNDLEo5eHG2bk-7U"
$tokenUrl = "https://login.app.skycloak.io/realms/skycloak/protocol/openid-connect/token"

for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 5
    $res = curl.exe -s -X POST $tokenUrl `
        -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" `
        -d "device_code=$deviceCode" `
        -d "client_id=skycloak-mcp"
    
    if ($res -match '"access_token"') {
        New-Item -ItemType Directory -Force -Path "scripts" | Out-Null
        $res | Out-File -FilePath "scripts/.device_token.json" -Encoding utf8
        Write-Output "SUCCESS: Device token acquired!"
        exit 0
    } elseif ($res -match '"error":"authorization_pending"') {
        # continue waiting
    } else {
        Write-Output "Status: $res"
    }
}
Write-Output "TIMEOUT: Device authorization expired."
exit 1
