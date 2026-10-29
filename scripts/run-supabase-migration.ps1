$ErrorActionPreference = 'Stop'

$projectId = 'spdwcsocsclucnwttdnk'
$repoRoot = Split-Path -Parent $PSScriptRoot
$exportDir = Join-Path $env:LOCALAPPDATA 'Temp\gsm-supabase-export'
$toolsDir = Join-Path $env:LOCALAPPDATA 'Temp\gsm-supabase-migration-tools'
$pgPackage = Join-Path $toolsDir 'node_modules\pg\package.json'

function ConvertFrom-SecureInput([Security.SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $pgPackage)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        npm install --prefix $toolsDir --no-save --ignore-scripts pg
        if ($LASTEXITCODE -ne 0) { throw 'Could not install the temporary PostgreSQL client.' }
    }

    $env:GSM_SUPABASE_EXPORT_DIR = $exportDir
    $env:NEW_SUPABASE_URL = "https://$projectId.supabase.co"
    $env:GSM_PG_MODULE_ANCHOR = Join-Path $toolsDir 'migration-anchor.cjs'

    node scripts/import-supabase-export.mjs --dry-run
    if ($LASTEXITCODE -ne 0) { throw 'Local export validation failed; no destination changes were made.' }

    $caCertificatePath = (Read-Host 'Path to the destination Supabase database root CA certificate (PEM)').Trim().Trim([char]'"')
    if (-not (Test-Path -LiteralPath $caCertificatePath -PathType Leaf)) {
        throw 'The Supabase root CA certificate file was not found. No destination changes were made.'
    }
    $env:NODE_EXTRA_CA_CERTS = (Resolve-Path -LiteralPath $caCertificatePath).Path
    if ((Get-Content -LiteralPath $env:NODE_EXTRA_CA_CERTS -Raw) -notmatch '-----BEGIN CERTIFICATE-----') {
        throw 'The selected file is not a PEM certificate. No destination changes were made.'
    }

    $dbPasswordInput = Read-Host 'Destination Postgres password (input hidden)' -AsSecureString
    $serviceKeyInput = Read-Host 'Destination service-role key (input hidden)' -AsSecureString
    $env:GSM_SUPABASE_DB_PASSWORD = ConvertFrom-SecureInput $dbPasswordInput
    $env:NEW_SUPABASE_SERVICE_KEY = ConvertFrom-SecureInput $serviceKeyInput

    node scripts/apply-supabase-bootstrap.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Schema application failed. Review the error above before retrying.' }

    node scripts/import-supabase-export.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Data import stopped. Upserts are restartable; review the error before retrying.' }
} finally {
    $env:GSM_SUPABASE_DB_PASSWORD = $null
    $env:NEW_SUPABASE_SERVICE_KEY = $null
    $env:GSM_PG_MODULE_ANCHOR = $null
    $env:GSM_SUPABASE_EXPORT_DIR = $null
    $env:NEW_SUPABASE_URL = $null
    $env:NODE_EXTRA_CA_CERTS = $null
    Pop-Location
}
