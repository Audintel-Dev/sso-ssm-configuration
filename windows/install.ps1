Write-Host "Starting Dev Environment Setup..."

# ----------------------------
# SAFE EXECUTION POLICY (NO ADMIN NEEDED)
# ----------------------------
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
    Write-Host "Execution policy could not be set, continuing..."
}

# ----------------------------
# PATH SETUP
# ----------------------------
$bin = "$env:USERPROFILE\bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null

if ($env:PATH -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$env:PATH;$bin",
        "User"
    )
    Write-Host "Added $bin to PATH"
}

# ----------------------------
# INSTALL AWS CLI
# ----------------------------
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Installing AWS CLI..."

    $msi = "$env:TEMP\aws.msi"
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi

    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`""
}

# ----------------------------
# INSTALL SESSION MANAGER
# ----------------------------
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Session Manager Plugin..."

    $ssm = "$env:TEMP\ssm.exe"
    Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $ssm

    Start-Process $ssm -Wait
}

# ----------------------------
# INSTALL SCRIPTS
# ----------------------------
Write-Host "Installing scripts..."

Get-ChildItem ".\scripts\*.ps1" | ForEach-Object {
    Copy-Item $_.FullName $bin -Force
    Write-Host "Installed $($_.Name)"
}

# ----------------------------
# RDS MAP SETUP
# ----------------------------
$rdsMap = "$env:USERPROFILE\.rds-map"

if (-not (Test-Path $rdsMap)) {
    Write-Host "Creating rds-map..."
    Copy-Item ".\templates\rds-map" $rdsMap
}

# ----------------------------
# POWERSHELL PROFILE
# ----------------------------
$profilePath = $PROFILE
New-Item -ItemType File -Force -Path $profilePath | Out-Null

Write-Host "Updating PowerShell profile..."

$block = @'

# >>> SSM_SETUP >>>

function aws-auto-login {

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    return
}

$profiles = aws configure list-profiles 2>$null

foreach ($env in @("uat","prod")) {

    if ($profiles -notcontains $env) {
        Write-Host "Skipping $env (not configured)"
        continue
    }

    aws sts get-caller-identity --profile $env 2>$null | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Logging into $env..."
        aws sso login --profile $env
    } else {
        Write-Host "$env already logged in"
    }
}

}

function start-ssm-setup {

$choice = Read-Host "Continue full setup[aws auth and dbprod and dbuat tunnels opening]? (y/n)"
if ($choice -ne "y") {
    Write-Host "Skipping setup..."
    return
}

# AUTH
aws-auto-login

# PROD
$prodChoice = Read-Host "Open PROD DB tunnels? (y/n)"
if ($prodChoice -eq "y") {
    try { dbprod } catch { Write-Host "dbprod failed" }
}

# UAT
$uatChoice = Read-Host "Open UAT DB tunnels? (y/n)"
if ($uatChoice -eq "y") {
    try { dbuat } catch { Write-Host "dbuat failed" }
}

# PORT CHECK
if ($prodChoice -eq "y" -or $uatChoice -eq "y") {
    try { dbpc } catch { Write-Host "Port check failed" }
}

Write-Host "Setup complete"

}

function uat { win-connect uat }
function prod { win-connect prod }
function dbuat { rds uat }
function dbprod { rds prod }
function dbpc { db-pc }

start-ssm-setup

# <<< SSM_SETUP <<<

'@

if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $content = $content -replace '# >>> SSM_SETUP >>>[\s\S]*?# <<< SSM_SETUP <<<', ''
    $content | Set-Content $profilePath
}

Add-Content $profilePath $block

# ----------------------------
# REFRESH PATH (CURRENT SESSION)
# ----------------------------
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + `
            [System.Environment]::GetEnvironmentVariable("PATH","User")

# ----------------------------
# DONE
# ----------------------------
Write-Host ""
Write-Host "Setup Complete!"
Write-Host ""
Write-Host "Reload PowerShell:"
Write-Host "   . `$PROFILE"
Write-Host ""