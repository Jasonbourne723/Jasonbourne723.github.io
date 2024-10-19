@echo off
setlocal enabledelayedexpansion

:retry
echo try git command
git pull 
set GIT_EXIT_CODE=%errorlevel%

if %GIT_EXIT_CODE% neq 0 (
    echo git fail
    timeout /t 5 /nobreak >nul
    goto retry
) else (
    echo git successed！
)

endlocal
pause
