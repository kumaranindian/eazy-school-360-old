# Deploy to UAT environment
Write-Host "[UAT] Deploying to eazyschool-360-uat..." -ForegroundColor DarkYellow
Write-Host ""

# Switch to UAT project
Write-Host "Switching to UAT project..." -ForegroundColor Cyan
firebase use uat

# Step 1: Deploy Firestore Rules & Indexes FIRST
Write-Host ""
Write-Host "Step 1/3: Deploying Firestore Rules..." -ForegroundColor Yellow
firebase deploy --only firestore:rules

Write-Host ""
Write-Host "Step 2/3: Deploying Firestore Indexes..." -ForegroundColor Yellow
firebase deploy --only firestore:indexes

# Wait for indexes to build
Write-Host ""
Write-Host "Waiting 10 seconds for indexes to start building..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 2: Build TypeScript functions
Write-Host ""
Write-Host "Step 3/3: Building TypeScript functions..." -ForegroundColor Yellow
Set-Location ..\functions
npm run build
Set-Location ..

# Step 3: Deploy Functions only (Storage not configured yet)
Write-Host ""
Write-Host "Deploying Cloud Functions..." -ForegroundColor Yellow
firebase deploy --only functions

Write-Host ""
Write-Host "[SUCCESS] UAT deployment complete!" -ForegroundColor Green
Write-Host "Console: https://console.firebase.google.com/project/eazyschool-360-uat" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: Firestore indexes may take a few minutes to build." -ForegroundColor Yellow
Write-Host "Check status: https://console.firebase.google.com/project/eazyschool-360-uat/firestore/indexes" -ForegroundColor Yellow
