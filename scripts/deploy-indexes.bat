@echo off
echo ========================================
echo Deploying Firestore Indexes to All Environments
echo ========================================
echo.

echo [1/4] Deploying to DEV...
call firebase deploy --only firestore:indexes --project eazyschool-360-dev
if %errorlevel% neq 0 (
    echo FAILED: DEV deployment failed
) else (
    echo SUCCESS: DEV indexes deployed
)
echo.

echo [2/4] Deploying to TEST...
call firebase deploy --only firestore:indexes --project eazyschool-360-test
if %errorlevel% neq 0 (
    echo FAILED: TEST deployment failed
) else (
    echo SUCCESS: TEST indexes deployed
)
echo.

echo [3/4] Deploying to UAT...
call firebase deploy --only firestore:indexes --project eazyschool-360-uat
if %errorlevel% neq 0 (
    echo FAILED: UAT deployment failed
) else (
    echo SUCCESS: UAT indexes deployed
)
echo.

echo [4/4] Deploying to PROD...
call firebase deploy --only firestore:indexes --project eazy-school-360
if %errorlevel% neq 0 (
    echo FAILED: PROD deployment failed
) else (
    echo SUCCESS: PROD indexes deployed
)
echo.

echo ========================================
echo Deployment Complete!
echo ========================================
pause
