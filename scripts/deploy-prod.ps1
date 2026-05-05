# Deploy to PRODUCTION environment
# All logs are saved to logs/ directory

$ErrorActionPreference = "Continue"
$PROJECT_ID = "eazy-school-360"

# Create logs directory
$LogDir = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Generate timestamped log file
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$DeployLog = Join-Path $LogDir "deploy-prod-$Timestamp.log"

# Logging function - writes to both console and file
function Log {
    param([string]$Message, [string]$Color = "White")
    $LogEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    Add-Content -Path $DeployLog -Value $LogEntry
}

# Run command and capture output to log
function Run-Logged {
    param([string]$Command, [string]$Description)
    Log ">> $Description" "Cyan"
    Log ">> Running: $Command" "DarkGray"
    $output = Invoke-Expression "$Command 2>&1" | Tee-Object -Append -FilePath $DeployLog
    $output | ForEach-Object { Write-Host $_ }
    Log ">> Exit code: $LASTEXITCODE" "DarkGray"
    return $LASTEXITCODE
}

Log "========================================" "Red"
Log "  PRODUCTION DEPLOYMENT - $PROJECT_ID" "Red"
Log "========================================" "Red"
Log "Log file: $DeployLog" "DarkGray"

# Confirmation prompt
Write-Host ""
Write-Host "WARNING: You are about to deploy to PRODUCTION!" -ForegroundColor Red
$confirmation = Read-Host "Type 'DEPLOY-PROD' to confirm deployment to production"
if ($confirmation -ne "DEPLOY-PROD") {
    Log "[CANCELLED] Deployment cancelled." "Red"
    exit 1
}
Log "User confirmed production deployment" "Green"

# Capture pre-deploy Cloud Function logs (last 50 lines)
Log "" 
Log "--- Pre-deploy Cloud Function Logs ---" "Magenta"
Run-Logged "firebase functions:log -n 50 --project $PROJECT_ID" "Fetching recent Cloud Function logs"

# Switch to PROD project
Log ""
Run-Logged "firebase use prod" "Switching to PROD project"

# Step 1: Deploy Firestore Rules
Log ""
Log "Step 1/4: Deploying Firestore Rules..." "Yellow"
Run-Logged "firebase deploy --only firestore:rules --project $PROJECT_ID" "Deploying Firestore rules"

# Step 2: Deploy Firestore Indexes
Log ""
Log "Step 2/4: Deploying Firestore Indexes..." "Yellow"
Run-Logged "firebase deploy --only firestore:indexes --project $PROJECT_ID --force" "Deploying Firestore indexes"

# Wait for indexes to build
Log ""
Log "Waiting 10 seconds for indexes to start building..." "Yellow"
Start-Sleep -Seconds 10

# Step 3: Build TypeScript functions
Log ""
Log "Step 3/4: Building TypeScript functions..." "Yellow"
Push-Location (Join-Path $PSScriptRoot "..\functions")
Run-Logged "npm run build" "Building TypeScript"
Pop-Location

# Step 4: Deploy Functions
Log ""
Log "Step 4/4: Deploying Cloud Functions..." "Yellow"
Run-Logged "firebase deploy --only functions --project $PROJECT_ID --force" "Deploying Cloud Functions"

# Capture post-deploy Cloud Function logs
Log ""
Log "--- Post-deploy Cloud Function Logs ---" "Magenta"
Run-Logged "firebase functions:log -n 20 --project $PROJECT_ID" "Fetching post-deploy Cloud Function logs"

# Summary
Log ""
Log "========================================" "Green"
Log "  PRODUCTION DEPLOYMENT COMPLETE" "Green"
Log "========================================" "Green"
Log "Log file saved: $DeployLog" "Cyan"
Log "Console: https://console.firebase.google.com/project/$PROJECT_ID" "Cyan"
Log ""
Log "NOTE: Firestore indexes may take a few minutes to build." "Yellow"
Log "Check status: https://console.firebase.google.com/project/$PROJECT_ID/firestore/indexes" "Yellow"
Log ""
Log "To view live Cloud Function logs:" "Yellow"
Log "  firebase functions:log --project $PROJECT_ID --follow" "White"
