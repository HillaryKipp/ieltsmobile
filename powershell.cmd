@echo off
if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" (
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" %*
) else if exist "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" (
    "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" %*
) else (
    powershell.exe %*
)
