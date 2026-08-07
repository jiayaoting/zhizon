#!/usr/bin/env bash
stdout_path='C:\devlop\devecostudio\workspace\zhizon\.bugfix\arkts-detail-braces-20260807\reproduction\stdout.txt'
stderr_path='C:\devlop\devecostudio\workspace\zhizon\.bugfix\arkts-detail-braces-20260807\reproduction\stderr.txt'
exit_path='C:\devlop\devecostudio\workspace\zhizon\.bugfix\arkts-detail-braces-20260807\reproduction\exit_code.txt'
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& 'C:\devlop\devecostudio\workspace\zhizon\.bugfix\arkts-detail-braces-20260807\reproduction\static_brace_scan.ps1' 1> '$stdout_path' 2> '$stderr_path'; [System.IO.File]::WriteAllText('$exit_path', [string]\$LASTEXITCODE); exit \$LASTEXITCODE"
