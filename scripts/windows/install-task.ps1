# Install the Agent Bridge polling task on Windows.
# Run as Administrator in PowerShell, from the repo root or anywhere.
# Creates a Scheduled Task "AgentBridgePoll" that runs poll-bridge.ps1 every 5 minutes.

$RepoDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Script = Join-Path $RepoDir "scripts\windows\poll-bridge.ps1"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Script`""
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "AgentBridgePoll" -Action $Action -Trigger $Trigger -Settings $Settings -Description "Agent Bridge: poll GitHub tasks/ every 5 minutes" -Force
Write-Host "Installed. Task 'AgentBridgePoll' will run $Script every 5 minutes."
Write-Host "Repo: $RepoDir"
Write-Host "To stop: Unregister-ScheduledTask -TaskName AgentBridgePoll -Confirm:`$false"
