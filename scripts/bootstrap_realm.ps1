$ErrorActionPreference = "Stop"

$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$clusterId = "3c9734e9-71f5-4562-af0d-9ee93d8f5438"
$tidecloakUrl = "https://$clusterId.us.skycloak.io"
$realmName = "legacyvault"
$clientName = "legacyvault-client"
$licenseEmail = "quocminh1297@gmail.com"

function Get-AdminToken {
    $res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
        grant_type = "client_credentials"
        client_id = $creds.client_id
        client_secret = $creds.client_secret
    }
    return $res.access_token
}

function Drain-ChangeRequests {
    param($token)
    Write-Output "==> Draining IGA change requests..."
    for ($pass = 1; $pass -le 5; $pass++) {
        $token = Get-AdminToken
        $pending = $null
        try {
            $pending = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/iga/change-requests?status=PENDING" -Headers @{
                Authorization = "Bearer $token"
            } -Method Get
        } catch {
            Write-Output "    Drain read error: $($_.Exception.Message)"
            break
        }

        if (-not $pending -or $pending.Count -eq 0) {
            Write-Output "    No pending change requests in pass $pass."
            break
        }

        foreach ($cr in $pending) {
            if ($cr.actionType -in @("DISABLE_IGA", "DELETE_REALM", "OFFBOARD_REALM")) {
                continue
            }
            # Authorize
            try {
                $token = Get-AdminToken
                Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/iga/change-requests/$($cr.id)/authorize" -Headers @{
                    Authorization = "Bearer $token"
                    "Content-Type" = "application/json"
                } -Method Post -Body "{}" | Out-Null
            } catch {
                # Ignore if already authorized
            }
            # Commit if ready
            try {
                $token = Get-AdminToken
                Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/iga/change-requests/$($cr.id)/commit" -Headers @{
                    Authorization = "Bearer $token"
                } -Method Post | Out-Null
            } catch {
                # May fail with 412 if dependency not ready
            }
        }
    }
}

Write-Output "==> 1. Checking if realm '$realmName' exists..."
$adminToken = Get-AdminToken
$existingRealms = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Headers @{ Authorization = "Bearer $adminToken" }
$realmExists = $existingRealms | Where-Object { $_.realm -eq $realmName }

if (-not $realmExists) {
    Write-Output "==> 2. Creating realm '$realmName' from scripts/realm.json..."
    $realmJson = Get-Content "scripts\realm.json" -Raw
    Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Method Post -Headers @{
        Authorization = "Bearer $adminToken"
        "Content-Type" = "application/json"
    } -Body $realmJson
    Write-Output "    Realm created successfully."
} else {
    Write-Output "    Realm '$realmName' already exists."
}

Write-Output "==> 3. Disabling first-broker-login profile review page..."
$adminToken = Get-AdminToken
try {
    $flows = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/flows/first%20broker%20login/executions" -Headers @{ Authorization = "Bearer $adminToken" }
    $rpItem = $flows | Where-Object { $_.providerId -eq "idp-review-profile" } | Select-Object -First 1
    if ($rpItem) {
        $cfgBody = @{
            alias = "review profile config"
            config = @{ "update.profile.on.first.login" = "off" }
        } | ConvertTo-Json
        if ($rpItem.authenticationConfig) {
            Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/config/$($rpItem.authenticationConfig)" -Method Put -Headers @{
                Authorization = "Bearer $adminToken"
                "Content-Type" = "application/json"
            } -Body $cfgBody | Out-Null
        } elseif ($rpItem.id) {
            Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/executions/$($rpItem.id)/config" -Method Post -Headers @{
                Authorization = "Bearer $adminToken"
                "Content-Type" = "application/json"
            } -Body $cfgBody | Out-Null
        }
        Write-Output "    Profile review page turned off (new users go straight in)."
    }
} catch {
    Write-Output "    Note on profile review: $($_.Exception.Message)"
}

Write-Output "==> 4. Setting up Tide realm (licensing + VRK) for $licenseEmail..."
$adminToken = Get-AdminToken
try {
    $setupRes = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/vendorResources/setUpTideRealm" -Method Post -Headers @{
        Authorization = "Bearer $adminToken"
        "Content-Type" = "application/x-www-form-urlencoded"
    } -Body "email=$licenseEmail&isRagnarokEnabled=true"
    Write-Output "    setUpTideRealm response: $setupRes"
} catch {
    Write-Output "    setUpTideRealm: $($_.Exception.Message)"
}

Write-Output "==> 5. Stamping iga.attestor=tide on realm attributes..."
$adminToken = Get-AdminToken
$realmRep = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName" -Headers @{ Authorization = "Bearer $adminToken" }
if (-not $realmRep.attributes) { $realmRep | Add-Member -MemberType NoteProperty -Name "attributes" -Value @{} }
$realmRep.attributes["iga.attestor"] = "tide"
$updatedJson = $realmRep | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName" -Method Put -Headers @{
    Authorization = "Bearer $adminToken"
    "Content-Type" = "application/json"
} -Body $updatedJson | Out-Null
Write-Output "    Stamped iga.attestor=tide."

Write-Output "==> 6. Enabling IGA..."
$adminToken = Get-AdminToken
$currentIga = $realmRep.attributes["isIGAEnabled"]
if ($currentIga -ne "true") {
    try {
        $igaRes = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/tide-admin/toggle-iga" -Method Post -Headers @{
            Authorization = "Bearer $adminToken"
        }
        Write-Output "    toggle-iga response: $igaRes"
    } catch {
        Write-Output "    toggle-iga note: $($_.Exception.Message)"
    }
} else {
    Write-Output "    IGA is already enabled on $realmName."
}

Drain-ChangeRequests $adminToken

Write-Output "==> 7. Creating synthetic demo users (Lan, Admin, Mai, Minh, Hanh, Tuan, Thu)..."
$usersToCreate = @(
    @{ username = "lan"; email = "lan@legacyvault.demo"; firstName = "Ba"; lastName = "Lan"; roles = @("appUser") },
    @{ username = "admin"; email = "admin@legacyvault.demo"; firstName = "Platform"; lastName = "Admin"; roles = @("appUser") },
    @{ username = "mai"; email = "mai@legacyvault.demo"; firstName = "Mai"; lastName = "Nguyen"; roles = @("trustee", "recipient-mai") },
    @{ username = "minh"; email = "minh@legacyvault.demo"; firstName = "Minh"; lastName = "Nguyen"; roles = @("trustee", "recipient-minh") },
    @{ username = "hanh"; email = "hanh@legacyvault.demo"; firstName = "Hanh"; lastName = "Le"; roles = @("trustee", "recipient-hanh") },
    @{ username = "tuan"; email = "tuan@legacyvault.demo"; firstName = "Tuan"; lastName = "Tran"; roles = @("trustee", "recipient-tuan") },
    @{ username = "thu"; email = "thu@legacyvault.demo"; firstName = "Thu"; lastName = "Pham"; roles = @("trustee", "recipient-thu") }
)

$adminToken = Get-AdminToken
$allRealmRoles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/roles" -Headers @{ Authorization = "Bearer $adminToken" }
$existingUsers = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Headers @{ Authorization = "Bearer $adminToken" }

foreach ($u in $usersToCreate) {
    $existing = $existingUsers | Where-Object { $_.username -eq $u.username }
    $userId = $null
    if (-not $existing) {
        $userBody = @{
            username = $u.username
            email = $u.email
            firstName = $u.firstName
            lastName = $u.lastName
            enabled = $true
            emailVerified = $true
            credentials = @(
                @{
                    type = "password"
                    value = "LegacyVault2026!"
                    temporary = $false
                }
            )
        } | ConvertTo-Json -Depth 5

        $adminToken = Get-AdminToken
        Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Method Post -Headers @{
            Authorization = "Bearer $adminToken"
            "Content-Type" = "application/json"
        } -Body $userBody | Out-Null
        
        $adminToken = Get-AdminToken
        $created = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users?username=$($u.username)" -Headers @{ Authorization = "Bearer $adminToken" }
        $userId = $created[0].id
        Write-Output "    Created user '$($u.username)' (ID: $userId)."
    } else {
        $userId = $existing.id
        Write-Output "    User '$($u.username)' already exists."
    }

    # Assign roles
    if ($u.roles.Count -gt 0 -and $userId) {
        $rolesToAssign = $allRealmRoles | Where-Object { $_.name -in $u.roles }
        if ($rolesToAssign) {
            $rolesJson = $rolesToAssign | ConvertTo-Json -Depth 5
            if ($rolesToAssign -isnot [System.Array]) { $rolesJson = "[$rolesJson]" }
            try {
                $adminToken = Get-AdminToken
                Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$userId/role-mappings/realm" -Method Post -Headers @{
                    Authorization = "Bearer $adminToken"
                    "Content-Type" = "application/json"
                } -Body $rolesJson | Out-Null
            } catch {
                # Might create IGA change-request (HTTP 202)
            }
        }
    }
}

Drain-ChangeRequests $adminToken

Write-Output "==> 8. Assigning tide-realm-admin to platform admin..."
# Finding realm-management client
$adminToken = Get-AdminToken
$clients = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients" -Headers @{ Authorization = "Bearer $adminToken" }
$rmClient = $clients | Where-Object { $_.clientId -eq "realm-management" }
if ($rmClient) {
    $rmRoles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients/$($rmClient.id)/roles" -Headers @{ Authorization = "Bearer $adminToken" }
    $traRole = $rmRoles | Where-Object { $_.name -eq "tide-realm-admin" }
    if ($traRole) {
        $adminUser = (Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users?username=admin" -Headers @{ Authorization = "Bearer $adminToken" })[0]
        $traBody = "[$($traRole | ConvertTo-Json -Depth 5)]"
        try {
            $adminToken = Get-AdminToken
            Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($adminUser.id)/role-mappings/clients/$($rmClient.id)" -Method Post -Headers @{
                Authorization = "Bearer $adminToken"
                "Content-Type" = "application/json"
            } -Body $traBody | Out-Null
            Write-Output "    Assigned tide-realm-admin to admin user."
        } catch {
            Write-Output "    tide-realm-admin assignment note: $($_.Exception.Message)"
        }
    }
}

Drain-ChangeRequests $adminToken

Write-Output "==> 9. Exporting adapter JSON (data/tidecloak.json)..."
$adminToken = Get-AdminToken
New-Item -ItemType Directory -Force -Path "data" | Out-Null
$appClient = $clients | Where-Object { $_.clientId -eq $clientName }
$adapterUrl = "$tidecloakUrl/admin/realms/$realmName/vendorResources/get-installations-provider?clientId=$($appClient.id)&providerId=keycloak-oidc-keycloak-json"
$adapterJson = Invoke-RestMethod -Uri $adapterUrl -Headers @{ Authorization = "Bearer $adminToken" }

$adapterJson | ConvertTo-Json -Depth 10 | Set-Content "data\tidecloak.json" -Encoding utf8
Write-Output "SUCCESS: data/tidecloak.json exported successfully!"
Write-Output "Adapter summary:"
Write-Output "  Realm: $($adapterJson.realm)"
Write-Output "  Auth Server: $($adapterJson.'auth-server-url')"
Write-Output "  Has JWK: $([bool]$adapterJson.jwk)"
Write-Output "  Vendor ID: $($adapterJson.vendorId)"
Write-Output "  Home ORK: $($adapterJson.homeOrkUrl)"
