# Runs Godot script tests through tools/run-godot.cmd, one process per test.
#
#   .\tools\run-tests.cmd                      # core regressions (tests/*.gd)
#   .\tools\run-tests.cmd -Suite labs          # lab-tool regressions (tests/labs)
#   .\tools\run-tests.cmd -Suite benchmarks    # timing only, needs a window (tests/benchmarks)
#   .\tools\run-tests.cmd -Suite all -Filter laser
#
# A test passes when it exits 0. SCRIPT ERROR lines in a passing test are
# reported as warnings. Exit code: 0 when every test passed, 1 otherwise.
param(
	[ValidateSet("core", "labs", "benchmarks", "all")]
	[string]$Suite = "core",
	[string]$Filter = "",
	[int]$TimeoutSec = 180
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root "tools\run-godot.cmd"
$logDir = Join-Path $root ".godot\test-logs"
New-Item -ItemType Directory -Force $logDir | Out-Null

$folders = switch ($Suite) {
	"core" { @("") }
	"labs" { @("labs") }
	"benchmarks" { @("benchmarks") }
	"all" { @("", "labs", "benchmarks") }
}

$tests = foreach ($folder in $folders) {
	Get-ChildItem (Join-Path (Join-Path $root "tests") $folder) -Filter "*.gd" -File |
		Where-Object { $_.BaseName -like "*$Filter*" } |
		ForEach-Object {
			$relative = if ($folder) { "$folder/$($_.Name)" } else { $_.Name }
			[pscustomobject]@{ Name = $_.BaseName; Path = "res://tests/$relative"; Headless = ($folder -ne "benchmarks") }
		}
}

if (-not $tests) {
	Write-Host "No tests matched suite '$Suite' filter '$Filter'."
	exit 1
}

$results = @()
$started = Get-Date
foreach ($test in $tests) {
	$log = Join-Path $logDir "$($test.Name).log"
	$arguments = @()
	if ($test.Headless) { $arguments += "--headless" }
	$arguments += @("--script", $test.Path)
	$timer = [Diagnostics.Stopwatch]::StartNew()
	$process = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $root `
		-RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow
	# Touching Handle keeps ExitCode readable after WaitForExit on Windows PowerShell.
	$null = $process.Handle
	if ($process.WaitForExit($TimeoutSec * 1000)) {
		$code = $process.ExitCode
	} else {
		& taskkill /T /F /PID $process.Id 2>$null | Out-Null
		$code = "timeout"
	}
	$timer.Stop()
	$text = ((Get-Content $log, "$log.err" -Raw -ErrorAction SilentlyContinue) -join "`n")
	$scriptErrors = ([regex]::Matches($text, "SCRIPT ERROR")).Count
	$status = if ($code -eq "timeout") { "TIMEOUT" } elseif ($code -ne 0) { "FAIL" } elseif ($scriptErrors -gt 0) { "WARN" } else { "PASS" }
	$results += [pscustomobject]@{ Status = $status; Seconds = [math]::Round($timer.Elapsed.TotalSeconds, 1); Test = $test.Path; Errors = $scriptErrors; Log = $log }
	Write-Host ("{0,-7} {1,6}s  {2}" -f $status, $results[-1].Seconds, $test.Path)
}

$failed = @($results | Where-Object { $_.Status -in @("FAIL", "TIMEOUT") })
$warned = @($results | Where-Object { $_.Status -eq "WARN" })
Write-Host ""
Write-Host ("{0} tests in {1:N0}s: {2} passed, {3} warned, {4} failed" -f $results.Count, ((Get-Date) - $started).TotalSeconds, ($results.Count - $failed.Count - $warned.Count), $warned.Count, $failed.Count)
foreach ($result in $warned) { Write-Host ("WARN    {0} ({1} SCRIPT ERROR) -> {2}" -f $result.Test, $result.Errors, $result.Log) }
foreach ($result in $failed) { Write-Host ("{0,-7} {1} -> {2}" -f $result.Status, $result.Test, $result.Log) }
if ($failed.Count -gt 0) { exit 1 }
exit 0
