#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$taskDisk = Join-Path $env:LOCALAPPDATA 'Docker/wsl/disk/docker_data.vhdx'
$taskReport = [ordered]@{ success = $false; disk = $taskDisk }
try {
    if (Get-Process -Name 'com.docker.backend' -ErrorAction SilentlyContinue) {
        throw 'Stop Docker Desktop before compacting its disk.'
    }
    $taskDiskItem = Get-Item -LiteralPath $taskDisk
    if ($taskDiskItem.PSIsContainer -or $taskDiskItem.Extension -ne '.vhdx') {
        throw 'Expected the Docker Desktop VHDX file.'
    }
    $taskReport.beforeBytes = $taskDiskItem.Length
    $taskReport.freeBeforeBytes = (Get-PSDrive C).Free
    $taskDiskCommands = @(
        ('select vdisk file="' + $taskDiskItem.FullName + '"'),
        'compact vdisk',
        'exit'
    )
    $taskOutput = ($taskDiskCommands -join "`r`n") | & "$env:SystemRoot/System32/diskpart.exe" 2>&1
    $taskReport.diskpartExitCode = $LASTEXITCODE
    $taskReport.output = ($taskOutput | Out-String)
    $taskReport.afterBytes = (Get-Item -LiteralPath $taskDisk).Length
    $taskReport.freeAfterBytes = (Get-PSDrive C).Free
    $taskReport.success = ($taskReport.diskpartExitCode -eq 0 -and
        $taskReport.afterBytes -lt $taskReport.beforeBytes)
} catch {
    $taskReport.error = $_.Exception.Message
}
[System.IO.File]::WriteAllText($ResultPath, ($taskReport | ConvertTo-Json -Depth 4))
