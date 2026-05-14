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
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($raw.Trim(), [ref]$parsed)) { return $true }
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
