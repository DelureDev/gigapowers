# Plain-PowerShell unit test for hooks/lib/throttle.ps1.
# No Pester dependency (PS 5.1's bundled Pester is too old to rely on).
# Exits 1 on any failure, 0 when all pass.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../plugins/gigapowers/hooks/lib/throttle.ps1"

$script:failures = 0
function Assert-Equal($expected, $actual, $name) {
    if ($expected -ne $actual) {
        Write-Host "FAIL: $name -- expected [$expected], got [$actual]" -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host "PASS: $name" -ForegroundColor Green
    }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gp-throttle-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $now = Get-Date '2026-05-14T12:00:00'

    Assert-Equal $true (Test-SyncStale -TimestampFile "$tmp/missing" -Now $now) 'missing file is stale'

    $fresh = "$tmp/fresh"; ($now.AddHours(-1)).ToString('o') | Set-Content $fresh
    Assert-Equal $false (Test-SyncStale -TimestampFile $fresh -Now $now) 'fresh (1h) file not stale'

    $old = "$tmp/old"; ($now.AddHours(-25)).ToString('o') | Set-Content $old
    Assert-Equal $true (Test-SyncStale -TimestampFile $old -Now $now) 'old (25h) file is stale'

    $edge = "$tmp/edge"; ($now.AddHours(-24)).ToString('o') | Set-Content $edge
    Assert-Equal $true (Test-SyncStale -TimestampFile $edge -Now $now) '24h boundary is stale'

    $corrupt = "$tmp/corrupt"; 'not-a-date' | Set-Content $corrupt
    Assert-Equal $true (Test-SyncStale -TimestampFile $corrupt -Now $now) 'corrupt file is stale'

    $empty = "$tmp/empty"; '' | Set-Content $empty
    Assert-Equal $true (Test-SyncStale -TimestampFile $empty -Now $now) 'empty file is stale'

    $nested = "$tmp/a/b/last-sync"
    Write-SyncTimestamp -TimestampFile $nested -Now $now
    Assert-Equal $true (Test-Path $nested) 'Write-SyncTimestamp creates nested dirs + file'
    Assert-Equal $false (Test-SyncStale -TimestampFile $nested -Now $now) 'just-written timestamp not stale'

    # --- sync lock (Task 4: TOCTOU fix) ---
    $lock = "$tmp/sync.lock"
    Assert-Equal $true  (Test-AcquireSyncLock -LockFile $lock) 'first acquire wins the lock'
    Assert-Equal $false (Test-AcquireSyncLock -LockFile $lock) 'second acquire is refused while lock is held'
    Remove-SyncLock -TimestampFile $lock
    Assert-Equal $false (Test-Path $lock) 'Remove-SyncLock deletes the lock file'
    Assert-Equal $true  (Test-AcquireSyncLock -LockFile $lock) 'acquire succeeds again after release'
    Remove-SyncLock -TimestampFile $lock

    $nestedLock = "$tmp/x/y/sync.lock"
    Assert-Equal $true (Test-AcquireSyncLock -LockFile $nestedLock) 'acquire creates the nested lock dir'
    Remove-SyncLock -TimestampFile $nestedLock

    $staleLock = "$tmp/stale.lock"
    New-Item -ItemType File -Path $staleLock | Out-Null
    (Get-Item $staleLock).LastWriteTime = $now.AddMinutes(-10)
    Assert-Equal $true (Test-AcquireSyncLock -LockFile $staleLock -Now $now) 'abandoned lock (>5m old) is reclaimed'
    Remove-SyncLock -TimestampFile $staleLock
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($script:failures -gt 0) {
    Write-Host "$script:failures test(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "All throttle tests passed" -ForegroundColor Green
exit 0
