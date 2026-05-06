# Deploy Firestore Indexes to All Environments
# Run this script to deploy indexes to dev, test, uat, and prod

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Firestore Indexes to All Environments" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to deploy indexes
function Deploy-Indexes {
    param (
        [string]$Environment,
        [string]$ProjectId
    )
    
    Write-Host "Deploying to $Environment ($ProjectId)..." -ForegroundColor Yellow
    
    try {
        firebase use $Environment
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to switch to $Environment" -ForegroundColor Red
            return $false
        }
        
        firebase deploy --only firestore:indexes --project $ProjectId
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully deployed indexes to $Environment" -ForegroundColor Green
            Write-Host ""
            return $true
        } else {
            Write-Host "✗ Failed to deploy indexes to $Environment" -ForegroundColor Red
            Write-Host ""
            return $false
        }
    } catch {
        Write-Host "✗ Error deploying to $Environment : $_" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

# Deploy to each environment
$results = @{}

Write-Host "1. Deploying to DEV..." -ForegroundColor Cyan
$results["dev"] = Deploy-Indexes -Environment "dev" -ProjectId "eazyschool-360-dev"

Write-Host "2. Deploying to TEST..." -ForegroundColor Cyan
$results["test"] = Deploy-Indexes -Environment "test" -ProjectId "eazyschool-360-test"

Write-Host "3. Deploying to UAT..." -ForegroundColor Cyan
$results["uat"] = Deploy-Indexes -Environment "uat" -ProjectId "eazyschool-360-uat"

Write-Host "4. Deploying to PROD..." -ForegroundColor Cyan
$results["prod"] = Deploy-Indexes -Environment "prod" -ProjectId "eazy-school-360"

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($env in $results.Keys) {
    $status = if ($results[$env]) { "✓ SUCCESS" } else { "✗ FAILED" }
    $color = if ($results[$env]) { "Green" } else { "Red" }
    Write-Host "$($env.ToUpper()): $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Cyan

# Switch back to dev
firebase use dev
