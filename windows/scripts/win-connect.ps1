param(
    [string]$PROFILE
)

if (-not $PROFILE) {
    Write-Host "Usage: win-connect <uat|prod>"
    exit 1
}

# ----------------------------
# REGION
# ----------------------------
$region = aws configure get region --profile $PROFILE 2>$null
if (-not $region) { $region = "us-east-1" }

# ----------------------------
# SSO LOGIN
# ----------------------------
aws sts get-caller-identity --profile $PROFILE 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    aws sso login --profile $PROFILE
}

# ----------------------------
# GET SSM CONNECTED INSTANCES
# ----------------------------
$ssmInstances = aws ssm describe-instance-information `
    --profile $PROFILE `
    --region $region `
    --query "InstanceInformationList[].InstanceId" `
    --output text

$ssmSet = $ssmInstances -split "\s+"

# ----------------------------
# FETCH INSTANCES
# ----------------------------
Write-Host "Fetching instances..."

$instances = aws ec2 describe-instances `
  --profile $PROFILE `
  --region $region `
  --no-paginate `
  --filters Name=instance-state-name,Values=running `
  --query "Reservations[].Instances[].{
    Name: Tags[?Key=='Name'] | [0].Value,
    Id: InstanceId,
    ImageId: ImageId,
    Platform: Platform,
    LaunchTime: LaunchTime
  }" `
  --output json | ConvertFrom-Json

$instances = @($instances)

# ----------------------------
# FILTER ONLY LINUX + SSM
# ----------------------------
$instances = $instances | Where-Object {
    $_.Platform -ne "windows" -and
    $ssmSet -contains $_.Id
}

if (-not $instances) {
    Write-Host "No SSM-connected Linux instances found"
    exit 1
}

# ----------------------------
# DISPLAY
# ----------------------------
"{0,-4} {1,-40} {2,-22} {3,-25}" -f "No","Instance Name","Instance ID","Creation Time"

$i = 1

foreach ($inst in $instances) {

    $name = $inst.Name
    if (-not $name) { $name = "No-Name" }

    $launchTime = $inst.LaunchTime

    "{0,-4} {1,-40} {2,-22} {3,-25}" -f $i, $name, $inst.Id, $launchTime

    $i++
}

# ----------------------------
# SELECT INSTANCE
# ----------------------------
Write-Host ""

$choice = Read-Host "Select instance number"

$num = 0

if (-not [int]::TryParse($choice, [ref]$num) -or $num -lt 1 -or $num -gt $instances.Count) {
    Write-Host "Invalid selection"
    exit 1
}

$inst = $instances[$num - 1]

$INSTANCE_ID   = $inst.Id
$INSTANCE_NAME = $inst.Name
$IMAGE_ID      = $inst.ImageId

# ----------------------------
# DETECT OS USING SSM
# ----------------------------
Write-Host "Detecting OS..."

$commandId = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters commands=["cat /etc/os-release"] `
    --profile $PROFILE `
    --region $region `
    --query "Command.CommandId" `
    --output text

Start-Sleep -Seconds 3

$osInfo = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --profile $PROFILE `
    --region $region `
    --query "StandardOutputContent" `
    --output text

# ----------------------------
# DETERMINE TARGET USER
# ----------------------------
$osInfoLower = $osInfo.ToLower()

if ($osInfoLower -match "ubuntu") {
    $TARGET_USER = "ubuntu"
}
elseif ($osInfoLower -match "amzn" -or $osInfoLower -match "amazon") {
    $TARGET_USER = "ec2-user"
}
else {
    $TARGET_USER = "ec2-user"
}

Write-Host "Using user: $TARGET_USER"

# ----------------------------
# CLEAN PROMPT (NO COLOR)
# ----------------------------
$RC_CONTENT = @"
# SSM_PROMPT_INJECTED
unset PROMPT_COMMAND
unset color_prompt
unset force_color_prompt
export PS1="[$PROFILE][$INSTANCE_NAME][\u@\h \W]\$ "
"@

$B64 = [Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes($RC_CONTENT)
)

# ----------------------------
# PROMPT INJECTION
# ----------------------------
Write-Host "Configuring prompt..."

$cmd = "sudo rm -f /etc/profile.d/ssm_prompt.sh; echo $B64 | base64 -d > /etc/profile.d/ssm_prompt.sh"

aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[$cmd]" `
    --profile $PROFILE `
    --region $region `
    | Out-Null

# ----------------------------
# CONNECT
# ----------------------------
Write-Host "Connecting as $TARGET_USER..."

$param = "command=[`"sudo su - $TARGET_USER`"]"

aws ssm start-session `
  --target $INSTANCE_ID `
  --profile $PROFILE `
  --region $region `
  --document-name AWS-StartInteractiveCommand `
  --parameters $param