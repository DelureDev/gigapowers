# Gigapowers throttle helpers. Dot-sourced by session-start.ps1 and the tests.
# Defines functions only -- no side effects on load.

function Test-SyncStale {
    <#
      Returns $true when the Codex-side update should run:
      the timestamp file is missing, empty, unparseable, or at least
      $MaxAgeHours old.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile,
        [datetime]$Now = (Get-Date),
        [int]$MaxAgeHours = 24
    )
    if (-not (Test-Path -LiteralPath $TimestampFile)) { return $true }
    $raw = Get-Content -LiteralPath $TimestampFile -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) { return $true }
    # Parse culture-invariantly: the timestamp is machine-written by
    # Write-SyncTimestamp (ISO 8601 'o'), so CurrentCulture must not affect it.
    $parsed  = [datetime]::MinValue
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles  = [System.Globalization.DateTimeStyles]::RoundtripKind
    if (-not [datetime]::TryParse($raw.Trim(), $culture, $styles, [ref]$parsed)) { return $true }
    return ($Now - $parsed).TotalHours -ge $MaxAgeHours
}

function Write-SyncTimestamp {
    <#
      Writes $Now as an ISO 8601 'o' string to $TimestampFile, creating the
      parent directory if needed.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile,
        [datetime]$Now = (Get-Date)
    )
    $dir = Split-Path -Parent $TimestampFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Now.ToString('o') | Set-Content -LiteralPath $TimestampFile -Encoding utf8
}

function Test-AcquireSyncLock {
    <#
      Claims the sync lock. The CreateNew open below is the atomic primitive:
      in the common path, two concurrent SessionStart events race for it and
      only one wins; the other returns $false and skips dispatch.

      An abandoned lock (a crashed session that never released it) older than
      $StaleMinutes is reclaimed -- the real lock is only held for the
      milliseconds it takes to dispatch a detached process, so any lock that
      old is dead. The stale-reclaim path is *not* atomic: if two callers both
      observe the same stale lock, the second caller's reclaim can race the
      first caller's fresh lock. The blast radius is bounded -- worst case is
      a duplicate `codex plugin marketplace upgrade` dispatch within
      milliseconds, which is idempotent -- so this is a deliberate v1 tradeoff
      rather than a true mutex. If a future use case widens the blast radius,
      replace this with a proper named-mutex / file-lock.
    #>
    param(
        [Parameter(Mandatory)][string]$LockFile,
        [int]$StaleMinutes = 5,
        [datetime]$Now = (Get-Date)
    )
    $dir = Split-Path -Parent $LockFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $LockFile) {
        $age = $Now - (Get-Item -LiteralPath $LockFile).LastWriteTime
        if ($age.TotalMinutes -ge $StaleMinutes) {
            Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
        }
    }
    try {
        $fs = [System.IO.File]::Open($LockFile, [System.IO.FileMode]::CreateNew)
        $fs.Close()
        return $true
    } catch {
        return $false
    }
}

function Remove-SyncLock {
    <#
      Releases the sync lock. Safe to call when the lock is already gone.
      Parameter is named -TimestampFile to match the other throttle helpers;
      pass the lock-file path.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile
    )
    Remove-Item -LiteralPath $TimestampFile -Force -ErrorAction SilentlyContinue
}
