param(
    [string]$PROFILE,
    [string]$SEARCH_TERM
)

$MAP_FILE = "$HOME\.rds-map"

if (-not $PROFILE) {
    Write-Host "Usage:"
    Write-Host "  dbuat"
    Write-Host "  dbprod"
    exit 1
}

if (-not (Test-Path $MAP_FILE)) {
    Write-Host "Mapping file not found (~/.rds-map)"
    exit 1
}

$REGION = aws configure get region --profile $PROFILE
if (-not $REGION) { $REGION = "us-east-1" }

# SSO check
aws sts get-caller-identity --profile $PROFILE *> $null
if ($LASTEXITCODE -ne 0) {
    aws sso login --profile $PROFILE
}

# ---------------------------------
# FIND JUMPHOST
# ---------------------------------
Write-Host "Fetching connection..."

$JUMPS = aws ec2 describe-instances `
    --profile $PROFILE `
    --region $REGION `
    --filters "Name=instance-state-name,Values=running" `
    --query "Reservations[].Instances[?contains(join('', Tags[?Key=='Name'].Value), 'Jumphost')].InstanceId" `
    --output text

$JUMPS = $JUMPS -split "\s+"

if ($JUMPS.Count -eq 0) {
    Write-Host "No gateway hosts available"
    exit 1
}

$JUMP = Get-Random -InputObject $JUMPS

Write-Host "Connected via secure gateway ($JUMP)"

# -----------------------------
# FUNCTIONS
# -----------------------------
function Kill-Port {
    param($PORT)

    $pids = Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess

   foreach ($procId in $pids) {
     Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    }
}

function Kill-User-Sessions {

    $USER = (aws sts get-caller-identity `
        --profile $PROFILE `
        --query "Arn" `
        --output text).Split("/")[-1]

    Write-Host ""
    Write-Host "Your active database connections:"
    Write-Host ""

    $sessions = aws ssm describe-sessions `
        --state Active `
        --region $REGION `
        --profile $PROFILE `
        --query "Sessions[*].[SessionId,Owner,DocumentName,Target,StartDate]" `
        --output text

    foreach ($line in $sessions) {
        $parts = $line -split "\s+"

        if ($parts.Count -ge 5) {
            $sessionId = $parts[0]
            $owner = $parts[1]
            $doc = $parts[2]
            $target = $parts[3]
            $start = $parts[4]

            if ($owner -like "*$USER*" -and $doc -eq "AWS-StartPortForwardingSessionToRemoteHost") {
                "{0,-40} {1,-20} {2}" -f $sessionId, $target, $start
            }
        }
    }

    Write-Host ""
    Write-Host "Cleaning your database connections..."

    $sessions = aws ssm describe-sessions `
        --state Active `
        --region $REGION `
        --profile $PROFILE `
        --query "Sessions[*].[SessionId,Owner,DocumentName]" `
        --output text

    foreach ($line in $sessions) {
        $parts = $line -split "\s+"

        if ($parts.Count -ge 3) {
            $sessionId = $parts[0]
            $owner = $parts[1]
            $doc = $parts[2]

            if ($owner -like "*$USER*" -and $doc -eq "AWS-StartPortForwardingSessionToRemoteHost") {
                Write-Host "Closing: $sessionId"

                aws ssm terminate-session `
                    --session-id $sessionId `
                    --region $REGION `
                    --profile $PROFILE *> $null
            }
        }
    }

    Write-Host ""
    Write-Host "Your database connections cleared"
}

function Start-Connection {
    param($DB, $PORT, $ENDPOINT)

    Write-Host "Connecting: $DB (127.0.0.1:$PORT)"

    Kill-Port $PORT

    $params = "host=$ENDPOINT,portNumber=3306,localPortNumber=$PORT"

    Start-Process -FilePath "aws" -ArgumentList @(
        "ssm","start-session",
        "--target",$JUMP,
        "--profile",$PROFILE,
        "--region",$REGION,
        "--document-name","AWS-StartPortForwardingSessionToRemoteHost",
        "--parameters",$params
    ) -WindowStyle Hidden
}

# -----------------------------
# READ DB MAP
# -----------------------------
$CURRENT_ENV = ""
$MATCHED_DBS = @()
$MATCHED_PORTS = @()

Get-Content $MAP_FILE | ForEach-Object {

    $line = $_.Trim()

    if (-not $line) { return }

    if ($line -eq "[uat_databases]") { $CURRENT_ENV = "uat"; return }
    if ($line -eq "[prod_databases]") { $CURRENT_ENV = "prod"; return }

    if ($line.StartsWith("#")) { return }
    if ($CURRENT_ENV -ne $PROFILE) { return }

    $parts = $line -split "="
    $DB = $parts[0].Trim()
    $PORT = $parts[1].Trim()

    if ($SEARCH_TERM -and ($DB -notmatch $SEARCH_TERM)) { return }

    $MATCHED_DBS += $DB
    $MATCHED_PORTS += $PORT
}

if ($MATCHED_DBS.Count -eq 0) {
    Write-Host "No databases found"
    exit 1
}

# -----------------------------
# SHOW DB LIST
# -----------------------------
Write-Host ""
Write-Host "Available Databases:"
Write-Host ""

for ($i=0; $i -lt $MATCHED_DBS.Count; $i++) {
    "{0,-3} {1,-20} (Port: {2})" -f ($i+1), $MATCHED_DBS[$i], $MATCHED_PORTS[$i]
}

Write-Host ""
Write-Host "Enter database number to connect (e.g. 1 or 1,2,3)"
Write-Host "Press Enter - connect ALL"
Write-Host "Type 'c' - clean old connections"
Write-Host "Type 'q' - exit"
Write-Host ""

$choice = Read-Host "Selection"

if (-not $choice) {
    $SELECTED_INDEXES = 0..($MATCHED_DBS.Count-1)

} elseif ($choice -eq "c") {
    Kill-User-Sessions
    exit

} elseif ($choice -eq "q") {
    exit

} else {
    $choice = ($choice -replace ",", " ").Trim()
    $SELECTED_INDEXES = @()

    foreach ($num in $choice -split "\s+") {
        $index = [int]$num - 1

        if ($index -lt 0 -or $index -ge $MATCHED_DBS.Count) {
            Write-Host "Invalid selection: $num"
            exit 1
        }

        $SELECTED_INDEXES += $index
    }

    $SELECTED_INDEXES = $SELECTED_INDEXES | Sort-Object -Unique

    if ($SELECTED_INDEXES.Count -gt 3) {
        Write-Host "Max 3 connections allowed"
        exit 1
    }
}

# -----------------------------
# START CONNECTIONS
# -----------------------------
foreach ($idx in $SELECTED_INDEXES) {

    $DB = $MATCHED_DBS[$idx]
    $PORT = $MATCHED_PORTS[$idx]

    $ENDPOINT = aws rds describe-db-instances `
        --profile $PROFILE `
        --region $REGION `
        --db-instance-identifier $DB `
        --query "DBInstances[0].Endpoint.Address" `
        --output text

    Start-Connection $DB $PORT $ENDPOINT
}

Write-Host ""
Write-Host "--------------------------------------------"
Write-Host "Connection ready"
Write-Host "Use: 127.0.0.1:<port>"
Write-Host "--------------------------------------------"