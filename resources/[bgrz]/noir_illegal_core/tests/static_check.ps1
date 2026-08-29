$ErrorActionPreference = 'Stop'
$resourceRoot = Split-Path -Parent $PSScriptRoot

$manifest = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot 'fxmanifest.lua')
if ($manifest -notmatch "server_only 'yes'") { throw 'Manifest is not server-only.' }
if ($manifest -match 'client_scripts?') { throw 'Manifest must not load client scripts.' }
if ($manifest -notmatch "server/migrations.lua") { throw 'Migration runner is not loaded.' }

$luaFiles = Get-ChildItem -LiteralPath $resourceRoot -Filter '*.lua' -Recurse
$networkMutations = $luaFiles | Select-String -Pattern 'RegisterNetEvent|RegisterServerEvent'
if ($networkMutations) { throw 'Network event registration found in server-only core.' }

$requiredExports = @(
    'RecordActivity', 'GetProfile', 'GetReputation', 'GetLevel', 'GetHeat',
    'HasUnlock', 'IsEligible', 'GrantUnlock', 'RevokeUnlock',
    'GetOrganization', 'GetOrganizationReputation'
)
$api = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot 'server\api.lua')
foreach ($exportName in $requiredExports) {
    if ($api -notmatch [regex]::Escape("exports('$exportName'")) {
        throw "Missing export: $exportName"
    }
}

$migration = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot 'migrations\001_initial.sql')
foreach ($statement in ($migration -split ';')) {
    $statement = $statement.Trim()
    if (-not $statement) { continue }
    if (
        $statement -notmatch '^CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+' -and
        $statement -notmatch '^INSERT\s+IGNORE\s+INTO\s+'
    ) {
        throw "Unsafe or non-idempotent migration statement: $($statement.Substring(0, [Math]::Min(80, $statement.Length)))"
    }
}
foreach ($tableName in @(
    'noir_illegal_profiles', 'noir_illegal_player_reputation',
    'noir_illegal_organization_reputation', 'noir_illegal_player_heat',
    'noir_illegal_unlocks', 'noir_illegal_cooldowns',
    'noir_illegal_activity_ledger', 'noir_illegal_audit_log'
)) {
    if ($migration -notmatch [regex]::Escape($tableName)) {
        throw "Missing migration table: $tableName"
    }
}

Write-Output 'static_check: ok'
