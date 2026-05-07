# Deploy to DEV environment
# All logs are saved to logs/ directory

$ErrorActionPreference = "Continue"
$PROJECT_ID = "eazyschool-360-dev"

# Create logs directory
$LogDir = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Generate timestamped log file
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$DeployLog = Join-Path $LogDir "deploy-dev-$Timestamp.log"

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
    $exitCode = $LASTEXITCODE
    Log ">> Exit code: $exitCode" "DarkGray"
    
    if ($exitCode -ne 0) {
        Log "ERROR: Step failed with exit code $exitCode" "Red"
        exit $exitCode
    }
    
    return $exitCode
}

Log "========================================" "Blue"
Log "  DEV DEPLOYMENT - $PROJECT_ID" "Blue"
Log "========================================" "Blue"
Log "Log file: $DeployLog" "DarkGray"

# Capture pre-deploy Cloud Function logs (last 50 lines)
Log "" 
Log "--- Pre-deploy Cloud Function Logs ---" "Magenta"
Run-Logged "firebase functions:log -n 50 --project $PROJECT_ID" "Fetching recent Cloud Function logs"

# Switch to DEV project
Log ""
Run-Logged "firebase use dev" "Switching to DEV project"

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
Log "Step 3/5: Building TypeScript functions..." "Yellow"
Push-Location (Join-Path $PSScriptRoot "..\functions")
Run-Logged "npm run build" "Building TypeScript"
Pop-Location

# Step 4: Build Flutter web app
Log ""
Log "Step 4/5: Building Flutter web app..." "Yellow"
Push-Location (Join-Path $PSScriptRoot "..")
Run-Logged "flutter build web lib/main_dev.dart" "Building Flutter web app with dev entry point"
Pop-Location

# Step 5: Deploy Functions and Hosting
Log ""
Log "Step 5/5: Deploying Cloud Functions and Hosting..." "Yellow"
Run-Logged "firebase deploy --only functions,hosting --project $PROJECT_ID --force" "Deploying Cloud Functions and Hosting"

# Capture post-deploy Cloud Function logs
Log ""
Log "--- Post-deploy Cloud Function Logs ---" "Magenta"
Run-Logged "firebase functions:log -n 20 --project $PROJECT_ID" "Fetching post-deploy Cloud Function logs"

# Summary
Log ""
Log "========================================" "Green"
Log "  DEV DEPLOYMENT COMPLETE" "Green"
Log "========================================" "Green"
Log "Log file saved: $DeployLog" "Cyan"
Log "Console: https://console.firebase.google.com/project/$PROJECT_ID" "Cyan"
Log "Hosting URL: https://$PROJECT_ID.web.app" "Cyan"
Log ""
Log "NOTE: Firestore indexes may take a few minutes to build." "Yellow"
Log "Check status: https://console.firebase.google.com/project/$PROJECT_ID/firestore/indexes" "Yellow"
Log ""
Log "To view live Cloud Function logs:" "Yellow"
Log "  firebase functions:log --project $PROJECT_ID --follow" "White"
