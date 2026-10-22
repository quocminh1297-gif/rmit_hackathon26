$ErrorActionPreference = "Stop"

$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

function Get-AdminToken {
    $res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
        grant_type = "client_credentials"
        client_id = $creds.client_id
        client_secret = $creds.client_secret
    }
    return $res.access_token
}

$token = Get-AdminToken
$roles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/roles" -Headers @{ Authorization = "Bearer $token" }
$users = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Headers @{ Authorization = "Bearer $token" }

$recipientMap = @{
    "mai" = "recipient-mai"
    "minh" = "recipient-minh"
    "hanh" = "recipient-hanh"
    "tuan" = "recipient-tuan"
    "thu" = "recipient-thu"
}

foreach ($uname in $recipientMap.Keys) {
    $rName = $recipientMap[$uname]
    $uObj = $users | Where-Object { $_.username -eq $uname }
    $rObj = $roles | Where-Object { $_.name -eq $rName }
    if ($uObj -and $rObj) {
        $token = Get-AdminToken
        try {
            $body = "[ " + (@{ id = $rObj.id; name = $rObj.name } | ConvertTo-Json -Compress) + " ]"
            Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($uObj.id)/role-mappings/realm" -Method Post -Headers @{
                Authorization = "Bearer $token"
                "Content-Type" = "application/json"
            } -Body $body | Out-Null
            Write-Output "    Queued $rName for $uname"
        } catch {
            Write-Output "    Assign $rName to $uname note: $($_.Exception.Message)"
        }
    }
}

# Assign realm-management client roles to admin (tide-realm-admin / realm-admin)
$adminUser = $users | Where-Object { $_.username -eq "admin" }
$clients = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients" -Headers @{ Authorization = "Bearer $token" }
$realmMgmtClient = $clients | Where-Object { $_.clientId -eq "realm-management" }
if ($adminUser -and $realmMgmtClient) {
    $clientRoles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients/$($realmMgmtClient.id)/roles" -Headers @{ Authorization = "Bearer $token" }
    $adminRoleObj = $clientRoles | Where-Object { $_.name -in @("realm-admin", "tide-realm-admin") }
    if ($adminRoleObj) {
        $token = Get-AdminToken
        try {
            $jsonItems = @($adminRoleObj | ForEach-Object { @{ id = $_.id; name = $_.name } | ConvertTo-Json -Compress })
            $body = "[ " + ($jsonItems -join ", ") + " ]"
            Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($adminUser.id)/role-mappings/clients/$($realmMgmtClient.id)" -Method Post -Headers @{
                Authorization = "Bearer $token"
                "Content-Type" = "application/json"
            } -Body $body | Out-Null
            Write-Output "    Queued realm-management admin roles for admin user"
        } catch {
            Write-Output "    Admin role assign note: $($_.Exception.Message)"
        }
    }
}

Write-Output "==> Draining role assignments..."
Start-Sleep -Seconds 2
& python "scripts\drain_auto_refresh.py"

Write-Output "==> Final User Roles Summary:"
$token = Get-AdminToken
$allUsers = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Headers @{ Authorization = "Bearer $token" }
foreach ($u in $allUsers) {
    $rRoles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($u.id)/role-mappings/realm" -Headers @{ Authorization = "Bearer $token" }
    Write-Output "  $($u.username) ($($u.firstName) $($u.lastName)): $(($rRoles | ForEach-Object { $_.name }) -join ', ')"
}
