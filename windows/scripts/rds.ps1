param(
[string]$ENV,
[string]$SEARCH_TERM,
[string]$MODE
)

# -----------------------------

# VALIDATION

# -----------------------------

if (-not $ENV) {
Write-Host "Usage: rds <uat|prod>"
exit 1
}

$PROFILE = $ENV
$MAP_FILE = Join-Path $env:USERPROFILE ".rds-map"

if (-not (Test-Path $MAP_FILE)) {
Write-Host "[ERROR] Map file not found: $MAP_FILE"
exit 1
}

# -----------------------------

# REGION

# -----------------------------

$REGION = aws configure get region --profile $PROFILE 2>$null
if (-not $REGION) { $REGION = "us-east-1" }

Write-Host "Using region: $REGION"

# -----------------------------

# SSO LOGIN

# -----------------------------

aws sts get-caller-identity --profile $PROFILE > $null 2>&1
if ($LASTEXITCODE -ne 0) {
aws sso login --profile $PROFILE
}

# -----------------------------

# FIND JUMPHOST

# -----------------------------

$ec2Args = @(
"ec2","describe-instances",
"--profile",$PROFILE,
"--region",$REGION,
"--filters","Name=instance-state-name,Values=running",
"--query","Reservations[].Instances[?contains(join('', Tags[?Key=='Name'].Value), 'Jumphost')].InstanceId",
"--output","text"
)

$JUMP = aws @ec2Args
$JUMP = ($JUMP -split "`n" | Where-Object { $_ } | Select-Object -First 1)

if (-not $JUMP) {
Write-Host "[ERROR] No Jumphost found"
exit 1
}

Write-Host "Using Jumphost: $JUMP"
Write-Host ""

# -----------------------------

# MODE HANDLING

# -----------------------------

if (-not $MODE) {

Write-Host ""
Write-Host "Select Mode:"
Write-Host "1) Restart tunnels (kill only YOUR sessions + create new tunnels)"
Write-Host "2) Open new tunnels"
Write-Host "3) Exit"

$choice = Read-Host "Enter choice"

switch ($choice) {
    "1" { $MODE = "restart" }
    "2" { $MODE = "open" }
    "3" { exit 0 }
    default { Write-Host "Invalid choice"; exit 1 }
}

}
else {
Write-Host "Mode: $MODE"
}

# -----------------------------

# FUNCTIONS

# -----------------------------

function Is-PortActive($PORT) {
return (Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue) -ne $null
}

function Kill-Port($PORT) {
Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue |
ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}

# 🔥 SAFE: Kill only USER sessions

function Kill-UserSessions {

Write-Host "Cleaning only YOUR port-forwarding sessions..."

# Get your SSO user (email)
$arn = aws sts get-caller-identity `
    --profile $PROFILE `
    --query "Arn" `
    --output text

if (-not $arn) {
    Write-Host "Unable to detect user"
    return
}

$USER = $arn.Split("/")[-1]
Write-Host "User: $USER"

# Get sessions (SessionId, Owner, DocumentName)
$sessions = aws ssm describe-sessions `
    --state Active `
    --profile $PROFILE `
    --region $REGION `
    --query "Sessions[?Target=='$JUMP'].[SessionId,Owner,DocumentName]" `
    --output text

foreach ($line in ($sessions -split "`n")) {

    if (-not $line.Trim()) { continue }

    $parts = $line -split "\s+"
    $sessionId = $parts[0]
    $owner     = $parts[1]
    $doc       = $parts[2]

    if ($owner -like "*$USER*" -and `
        $doc -eq "AWS-StartPortForwardingSessionToRemoteHost") {

        Write-Host "Killing tunnel session: $sessionId"

        aws ssm terminate-session `
            --session-id $sessionId `
            --profile $PROFILE `
            --region $REGION | Out-Null
    }
}

}

function Start-Tunnel($DB, $PORT, $ENDPOINT) {

if (-not $ENDPOINT) {
    Write-Host "[WARN] No endpoint for $DB"
    return
}

if (Is-PortActive $PORT) {
    if ($MODE -eq "open") {
        Write-Host "Restarting $DB"
        Kill-Port $PORT
    } else {
        Write-Host "Reusing $DB"
        return
    }
}

Write-Host "Starting $DB on port $PORT"

$args = @(
    "ssm","start-session",
    "--target",$JUMP,
    "--profile",$PROFILE,
    "--region",$REGION,
    "--document-name","AWS-StartPortForwardingSessionToRemoteHost",
    "--parameters","host=$ENDPOINT,portNumber=3306,localPortNumber=$PORT"
)

Start-Process aws -ArgumentList $args -WindowStyle Hidden

}

# -----------------------------

# MODE EXECUTION

# -----------------------------

if ($MODE -eq "restart") {
Kill-UserSessions
}

# -----------------------------

# FETCH RDS

# -----------------------------

$rdsArgs = @(
"rds","describe-db-instances",
"--profile",$PROFILE,
"--region",$REGION,
"--output","json"
)

$rdsData = aws @rdsArgs | ConvertFrom-Json

$rdsMap = @{}
foreach ($db in $rdsData.DBInstances) {
$rdsMap[$db.DBInstanceIdentifier] = $db.Endpoint.Address
}

# -----------------------------

# READ MAP FILE

# -----------------------------

$CURRENT_ENV = ""
$MATCHED = @()

Get-Content $MAP_FILE | ForEach-Object {

$line = $_.Trim()
if (-not $line) { return }

if ($line -eq "[uat_databases]") { $CURRENT_ENV = "uat"; return }
if ($line -eq "[prod_databases]") { $CURRENT_ENV = "prod"; return }

if ($line.StartsWith("#")) { return }
if ($CURRENT_ENV -ne $ENV) { return }

$parts = $line.Split("=")
if ($parts.Count -ne 2) { return }

$DB = $parts[0].Trim()
$PORT = $parts[1].Trim()

if ($SEARCH_TERM -and ($DB -notmatch $SEARCH_TERM)) {
    return
}

$MATCHED += [PSCustomObject]@{
    DB = $DB
    PORT = $PORT
}

}

if ($MATCHED.Count -eq 0) {
Write-Host "No matching DBs found"
exit 1
}

# -----------------------------

# DISPLAY

# -----------------------------

$i = 1
foreach ($item in $MATCHED) {
Write-Host "$i) $($item.DB) - $($item.PORT)"
$i++
}

# -----------------------------

# MULTI SELECT

# -----------------------------

$input = Read-Host "Enter DB numbers Maximum[3] at a time (e.g. 1 2 3)"
$indexes = $input -split " " | Select-Object -Unique

if ($indexes.Count -gt 3) {
Write-Host "Max 3 tunnels allowed"
exit 1
}

foreach ($n in $indexes) {
$idx = [int]$n - 1

if ($idx -lt 0 -or $idx -ge $MATCHED.Count) {
    Write-Host "Invalid selection"
    exit 1
}

$db = $MATCHED[$idx].DB
$port = $MATCHED[$idx].PORT
$endpoint = $rdsMap[$db]

Start-Tunnel $db $port $endpoint

}

Write-Host ""
Write-Host "Tunnels completed"