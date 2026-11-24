# Agent Bridge - Windows polling script
# Every run: git pull, find tasks/*.md with status: pending,
# mark in_progress, dispatch by agent field, write results/*.md, git push.
# Run it via install-task.ps1 (every 5 minutes) or manually.
# It never pretends a task is done: if the agent tool is not installed,
# it writes a result saying so and leaves the task pending.

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoDir
$LogFile = Join-Path $RepoDir "poll.log"
function Log($msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
  Add-Content -Path $LogFile -Value $line
  Write-Host $line
}

try { git pull --ff-only 2>&1 | Out-Null } catch { Log "git pull failed: $_" }

$tasks = Get-ChildItem -Path (Join-Path $RepoDir "tasks") -Filter *.md |
  Where-Object { $_.Name -ne "_template.md" }

foreach ($file in $tasks) {
  $text = Get-Content -Raw $file.FullName
  if ($text -notmatch 'status:\s*pending') { continue }

  $id = if ($text -match 'id:\s*(\S+)') { $Matches[1] } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name) }
  $agent = if ($text -match 'agent:\s*(\S+)') { $Matches[1].ToLower() } else { "any" }
  Log "Found pending task $id (agent: $agent)"

  # Mark in_progress
  $text = $text -replace 'status:\s*pending', 'status: in_progress'
  Set-Content -Path $file.FullName -Value $text -Encoding UTF8
  git add $file.FullName
  git commit -m "bridge: $id in_progress" 2>&1 | Out-Null
  git push 2>&1 | Out-Null

  $resultPath = Join-Path $RepoDir "results\$id.md"
  $result = @"
# Result: $id

- task: $($file.Name)
- agent requested: $agent
- run at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- machine: $env:COMPUTERNAME / $env:USERNAME

## What was done

"@

  $done = $false
  try {
    if ($agent -eq "codex" -or $agent -eq "any") {
      $codex = Get-Command codex -ErrorAction SilentlyContinue
      if ($codex) {
        $result += "`nCodex CLI found at $($codex.Source). Manual run needed: open the task file and run it with Codex, then append the output here.`n"
      } else {
        $result += "`nCodex CLI is NOT installed on this machine. Task left for manual run.`n"
      }
    }
    if ($agent -eq "antigravity" -or $agent -eq "any") {
      $agy = Get-Command agy -ErrorAction SilentlyContinue
      if ($agy) {
        $result += "`nAntigravity CLI (agy) found at $($agy.Source). Manual run needed: open the task file and run it with agy, then append the output here.`n"
      } else {
        $result += "`nAntigravity CLI (agy) is NOT installed on this machine. Task left for manual run.`n"
      }
    }
    if ($agent -eq "dsh") {
      $result += "`nDSH task: open the task file in DSH on this machine and run it, then append the output here.`n"
    }
    $result += "`n## Status`n`npending-manual: the bridge delivered the task, but no agent CLI auto-ran it. A human/agent on this machine needs to run it and update this file, then set the task status to done.`n"
  } catch {
    $result += "`n## Error`n`n$_`n"
  }

  Set-Content -Path $resultPath -Value $result -Encoding UTF8
  git add $resultPath
  git commit -m "bridge: $id result (manual run needed)" 2>&1 | Out-Null
  git push 2>&1 | Out-Null
  Log "Result written for $id"
}
Log "Poll finished."
