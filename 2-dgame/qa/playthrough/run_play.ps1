param([string]$Mode = "scenario", [string]$Scenario = "PLAY-002", [string]$Extra = "")
# QA oynanış koşucusunu GERÇEK PENCEREDE çalıştırır, konsolu kaydeder, gerçek çıkış kodunu döndürür.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$g = "C:\Users\bokeg\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
foreach ($d in "qa\playthrough\reports","qa\playthrough\screenshots","qa\playthrough\bugs") { New-Item -ItemType Directory -Force $d | Out-Null }
$name = if ($Mode -eq "campaign") { "campaign" } else { $Scenario }
$log = "qa\playthrough\reports\${name}_console.log"
$start = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$args2 = @("--path", ".", "res://qa/playthrough/qa_play_runner.tscn", "--", "--qa-mode=$Mode", "--qa-scenario=$Scenario")
if ($Extra) { $args2 += $Extra.Split(" ") }
$p = Start-Process -FilePath $g -ArgumentList $args2 -NoNewWindow -PassThru -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err"
$end = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"START=$start END=$end EXIT=$($p.ExitCode)" | Tee-Object -FilePath "qa\playthrough\reports\${name}_exit.txt"
exit $p.ExitCode

