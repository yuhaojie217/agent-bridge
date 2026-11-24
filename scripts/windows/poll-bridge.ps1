# Agent Bridge - Windows polling script (Antigravity headless runner)
# Runs via Windows Scheduled Task "AgentBridgePoll" every 5 minutes.
# Zero background residency: exits immediately when no matching pending task exists.
# Claims only tasks with status: pending and agent: antigravity | any.
# Leaves codex / dsh / muse tasks untouched.

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoDir

$LogFile = Join-Path $RepoDir "poll.log"
$LockFile = Join-Path $RepoDir ".bridge.lock"
$Model = "gemini-4-neon-medium"
$PrintTimeout = "20m"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Trim-LogIfNeeded {
    if (Test-Path $LogFile) {
        $item = Get-Item $LogFile -ErrorAction SilentlyContinue
        if ($item -and $item.Length -gt 524288) {
            $tail = Get-Content -Path $LogFile -Tail 200
            Set-Content -Path $LogFile -Value $tail -Encoding UTF8
        }
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    return @{ Code = $code; Output = $text }
}

function Resolve-AgyPath {
    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe"),
        "C:\Users\ASUS\AppData\Local\agy\bin\agy.exe"
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

Trim-LogIfNeeded

# Prevent overlapping runs via PID lock
if (Test-Path $LockFile) {
    $existingPid = (Get-Content -Path $LockFile -Raw -ErrorAction SilentlyContinue)
    if ($existingPid) { $existingPid = $existingPid.Trim() }
    if ($existingPid -match '^\d+$') {
        $proc = Get-Process -Id ([int]$existingPid) -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Log "Skip: another poll instance is running (PID $existingPid)."
            exit 0
        }
    }
    Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue
}

Write-Utf8NoBom -Path $LockFile -Content "$PID"

try {
    $pull = Invoke-Git @("pull", "--rebase", "--autostash")
    if ($pull.Code -ne 0) {
        Write-Log "git pull failed (exit $($pull.Code)): $($pull.Output)"
        exit 1
    }

    $tasksDir = Join-Path $RepoDir "tasks"
    $resultsDir = Join-Path $RepoDir "results"
    if (-not (Test-Path $resultsDir)) {
        New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    }

    $taskFiles = Get-ChildItem -Path $tasksDir -Filter "*.md" |
        Where-Object { $_.Name -ne "_template.md" } |
        Sort-Object Name

    $matchingTasks = @()
    foreach ($file in $taskFiles) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        if ($text -notmatch '(?m)^status:\s*pending\s*$') { continue }
        $agent = if ($text -match '(?m)^agent:\s*(\S+)\s*$') { $Matches[1].ToLower() } else { "any" }
        if ($agent -ne "antigravity" -and $agent -ne "any") { continue }
        $id = if ($text -match '(?m)^id:\s*(\S+)\s*$') { $Matches[1] } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name) }
        $matchingTasks += @{ File = $file; Id = $id; Agent = $agent }
    }

    if ($matchingTasks.Count -eq 0) {
        # Quiet fast exit when nothing to do
        exit 0
    }

    $agyPath = Resolve-AgyPath
    if (-not $agyPath) {
        Write-Log "ERROR: agy.exe not found. Leaving $($matchingTasks.Count) task(s) in pending."
        exit 1
    }

    foreach ($task in $matchingTasks) {
        $file = $task.File
        $id = $task.Id
        $agent = $task.Agent
        $resultPath = Join-Path $resultsDir "$id.md"

        Write-Log "Claiming task $id ($($file.Name), agent=$agent) with model $Model"

        # Mark in_progress and push claim first to avoid duplicate execution
        $text = [System.IO.File]::ReadAllText($file.FullName)
        if ($text -notmatch '(?m)^status:\s*pending\s*$') {
            Write-Log "Skip ${id}: status already changed."
            continue
        }
        $claimedText = [regex]::Replace($text, '(?m)^status:\s*pending\s*$', 'status: in_progress', 1)
        Write-Utf8NoBom -Path $file.FullName -Content $claimedText

        $null = Invoke-Git @("add", $file.FullName)
        $c1 = Invoke-Git @("commit", "-m", "claim $id (antigravity)")
        if ($c1.Code -ne 0) {
            Write-Log "Failed to commit claim for ${id}: $($c1.Output)"
            continue
        }
        $p1 = Invoke-Git @("pull", "--rebase")
        $push1 = Invoke-Git @("push")
        if ($p1.Code -ne 0 -or $push1.Code -ne 0) {
            Write-Log "Claim push conflict for ${id}, rolling back local claim."
            $null = Invoke-Git @("rebase", "--abort")
            $null = Invoke-Git @("reset", "--hard", "origin/main")
            continue
        }

        # Run Antigravity CLI in headless print mode
        $prompt = "Read README.md and tasks/$($file.Name) in this repository ($RepoDir). Execute the task completely according to its instructions and acceptance criteria. Write a clear summary of what was done, files changed, and verification results to results/$id.md. Update status in tasks/$($file.Name) to done (or failed if blocked, explaining why in results/$id.md). Do NOT run git commit or git push; the bridge script will commit and push after you exit."

        Write-Log "Launching agy for $id..."
        $prev = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $agyOutput = & $agyPath --model $Model --dangerously-skip-permissions --print-timeout $PrintTimeout --print $prompt 2>&1
            $agyExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prev
        }
        $agyText = ($agyOutput | ForEach-Object { $_.ToString() }) -join "`n"
        Write-Log "agy finished for $id with exit code $agyExit"

        $hasResult = (Test-Path $resultPath) -and ((Get-Item $resultPath).Length -gt 0)
        $currentTaskText = [System.IO.File]::ReadAllText($file.FullName)

        $finalStatus = "done"
        if ($agyExit -ne 0 -or -not $hasResult) {
            $finalStatus = "failed"
            $tailLines = ($agyText -split "`r?`n") | Select-Object -Last 40
            $tailSnippet = $tailLines -join "`n"
            $fallback = @"
---
id: $id
handled_by: antigravity
model: $Model
status: failed
completed_at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
---

## Execution Failed

- agy exit code: $agyExit
- result file generated by agent: $hasResult

## Output Tail

``````text
$tailSnippet
``````
"@
            if (-not $hasResult) {
                Write-Utf8NoBom -Path $resultPath -Content $fallback
            } else {
                Add-Content -Path $resultPath -Value "`n`n## Bridge Runner Error`n`nagy exited with code $agyExit.`n" -Encoding UTF8
            }
            $updatedTaskText = [regex]::Replace($currentTaskText, '(?m)^status:\s*\S+\s*$', 'status: failed', 1)
            Write-Utf8NoBom -Path $file.FullName -Content $updatedTaskText
        } else {
            if ($currentTaskText -match '(?m)^status:\s*failed\s*$') {
                $finalStatus = "failed"
            } elseif ($currentTaskText -notmatch '(?m)^status:\s*done\s*$') {
                $updatedTaskText = [regex]::Replace($currentTaskText, '(?m)^status:\s*\S+\s*$', 'status: done', 1)
                Write-Utf8NoBom -Path $file.FullName -Content $updatedTaskText
            }
        }

        $null = Invoke-Git @("add", "-A")
        $c2 = Invoke-Git @("commit", "-m", "$finalStatus $id (antigravity)")
        if ($c2.Code -eq 0) {
            $null = Invoke-Git @("pull", "--rebase")
            $push2 = Invoke-Git @("push")
            if ($push2.Code -ne 0) {
                Write-Log "ERROR: git push failed for ${id}: $($push2.Output)"
            } else {
                Write-Log "Task $id completed with status=$finalStatus and pushed."
            }
        } else {
            Write-Log "Nothing new to commit for ${id}: $($c2.Output)"
        }
    }
} finally {
    Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue
}
