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
Write-Output "==> Checking realm roles..."
$roles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/roles" -Headers @{ Authorization = "Bearer $token" }
Write-Output "    Available roles: $(($roles | ForEach-Object { $_.name }) -join ', ')"

$usersToCreate = @(
    @{ username = "lan"; email = "lan@legacyvault.demo"; firstName = "Lan"; lastName = "Nguyen (Owner)"; roles = @("appUser") },
    @{ username = "admin"; email = "admin@legacyvault.demo"; firstName = "Platform"; lastName = "Admin"; roles = @("appUser") },
    @{ username = "mai"; email = "mai@legacyvault.demo"; firstName = "Mai"; lastName = "Nguyen (Daughter)"; roles = @("trustee", "recipient-mai") },
    @{ username = "minh"; email = "minh@legacyvault.demo"; firstName = "Minh"; lastName = "Nguyen (Son)"; roles = @("trustee", "recipient-minh") },
    @{ username = "hanh"; email = "hanh@legacyvault.demo"; firstName = "Hanh"; lastName = "Le (Friend)"; roles = @("trustee", "recipient-hanh") },
    @{ username = "tuan"; email = "tuan@legacyvault.demo"; firstName = "Tuan"; lastName = "Tran (Lawyer)"; roles = @("trustee", "recipient-tuan") },
    @{ username = "thu"; email = "thu@legacyvault.demo"; firstName = "Thu"; lastName = "Pham (Executor)"; roles = @("trustee", "recipient-thu") }
)

Write-Output "==> Creating synthetic users..."
foreach ($u in $usersToCreate) {
    $token = Get-AdminToken
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

    try {
        $createRes = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Method Post -Headers @{
            Authorization = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $userBody
        Write-Output "    Queued create user: $($u.username)"
    } catch {
        Write-Output "    Note on $($u.username): $($_.Exception.Message)"
    }
}

Write-Output "==> Draining user creation change requests..."
Start-Sleep -Seconds 2
& python "scripts\drain_auto_refresh.py"

Write-Output "==> Assigning roles to users..."
$token = Get-AdminToken
$existingUsers = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Headers @{ Authorization = "Bearer $token" }

foreach ($u in $usersToCreate) {
    $userObj = $existingUsers | Where-Object { $_.username -eq $u.username }
    if ($userObj) {
        $rolesToAssign = @()
        foreach ($rn in $u.roles) {
            $roleObj = $roles | Where-Object { $_.name -eq $rn }
            if ($roleObj) {
                $rolesToAssign += @{
                    id = $roleObj.id
                    name = $roleObj.name
                }
            }
        }
        if ($rolesToAssign.Count -gt 0) {
            $token = Get-AdminToken
            try {
                Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($userObj.id)/role-mappings/realm" -Method Post -Headers @{
                    Authorization = "Bearer $token"
                    "Content-Type" = "application/json"
                } -Body ($rolesToAssign | ConvertTo-Json) | Out-Null
                Write-Output "    Assigned roles to $($u.username): $($u.roles -join ', ')"
            } catch {
                Write-Output "    Role assign note for $($u.username): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Output "    User $($u.username) not found yet."
    }
}

Write-Output "==> Draining role assignment change requests..."
Start-Sleep -Seconds 2
& python "scripts\drain_auto_refresh.py"

Write-Output "==> Verifying users and role mappings..."
$token = Get-AdminToken
$finalUsers = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users" -Headers @{ Authorization = "Bearer $token" }
foreach ($fu in $finalUsers) {
    $uRoles = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/users/$($fu.id)/role-mappings/realm" -Headers @{ Authorization = "Bearer $token" }
    Write-Output "  User '$($fu.username)' ($($fu.firstName) $($fu.lastName)): $(($uRoles | ForEach-Object { $_.name }) -join ', ')"
}
