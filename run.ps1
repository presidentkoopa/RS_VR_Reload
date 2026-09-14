# ============================================================================
# LAUNCH THE TEST, AND ALWAYS LEAVE A LOG BEHIND.
#
# WHY A RUNNER EXISTS AT ALL: this package cannot be tested any other way.
#
# A headless run of this engine dies at Vulkan init -- there is no window and
# no OpenXR runtime, so the game never reaches a map and no automated test can
# ever observe a grab, a drive, a dropped magazine or a pose. The machine with
# the headset on it is the only one that can run this build, and the only thing
# that comes back out of it is text.
#
# So the text has to survive the session. `+logfile` writes the console to disk
# as it goes, which means a crash, a hang or a headset yanked off still leaves a
# readable record -- and "it did not work" becomes a file someone can read.
#
# EVERY RUN OVERWRITES wm_last.log AND KEEPS A TIMESTAMPED COPY. The fixed name
# is so there is always one path to look at without hunting; the copies are so
# comparing this run against the one before it is possible at all.
#
#   .\run.ps1                 the test pk3 alone, no other mods
#   .\run.ps1 -Full           with your whole load order from test.zdl
#   .\run.ps1 -Map map07      somewhere else
#   .\run.ps1 -Tail           print the WM lines when it exits
# ============================================================================
[CmdletBinding()]
param(
    [switch] $Full,
    [switch] $Tail,
    [string] $Map  = 'map01',
    [int]    $Level = 3
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$eng  = 'E:\DOOMWork\UZDXREMA\build-dxr\RelWithDebInfo'
$exe  = Join-Path $eng 'doomxr.exe'
$iwad = Join-Path $eng 'doom2.wad'

if (-not (Test-Path $exe))  { throw "no engine build at $exe -- build it first" }
if (-not (Test-Path $iwad)) { throw "no iwad at $iwad" }

# Build it first, every time. A test run against a stale pk3 is worse than no
# test: it answers a question about code that is no longer on disk.
& (Join-Path $root 'build.ps1')

$pk3 = Join-Path $root 'RS_VR_Reload.pk3'
$log = Join-Path $root 'wm_last.log'
if (Test-Path $log) { Remove-Item $log -Force }

# ORDER MATTERS AND THIS ORDER IS DELIBERATE. The test pk3 goes LAST so its
# MODELDEF, CVARINFO and player class win any collision -- loading it in the
# middle means another mod's block silently shadows one of ours, which looks
# exactly like ours failed to pack.
$files = @()
if ($Full) {
    foreach ($m in 'RS_Graveyard\Graveyard.zip','RS_Fog\RS_Fog.pk3','RS_Sweeps\RS_Sweeps.pk3',
                   'RS_Darkness\RS_Darkness.pk3','RS_Flashlight\RS_Flashlight.zip',
                   'RS_Grenade\RS_Grenade.pk3','RS_WeaponSelectionSystem\RS_WeaponSelectionSystem.pk3',
                   'RS_GESTURES\RS_GESTURES.pk3','RS_VRBody\RS_VRBody.pk3',
                   'RS_WorldHands\RS_WorldHands.pk3') {
        $p = Join-Path 'E:\DOOMWork' $m
        if (Test-Path $p) { $files += $p } else { Write-Warning "skipping missing $m" }
    }
}
# RS_BALLISTICS BEFORE THE RELOAD SYSTEM, which requires it: its guns fire RSB_Bullet, and their
# flashes and casings are RS_Ballistics'. Loaded by this list, never by itself.
$ballistics = 'E:\DOOMWork\RS_Ballistics\RS_Ballistics.pk3'
if (-not (Test-Path $ballistics)) { throw "no RS_Ballistics pk3 at $ballistics -- the reload system requires it" }
$files += $ballistics
$files += $pk3

$args = @('-iwad', $iwad, '-file') + $files + @(
    '-noautoload',          # no autoloads, ever -- the load order is THIS list
    '+logfile', $log,
    '+wm_log', "$Level",
    '+map', $Map
)

Write-Host ''
Write-Host "  engine   $exe" -ForegroundColor DarkGray
Write-Host "  loading  $($files.Count) file(s), test pk3 last" -ForegroundColor DarkGray
Write-Host "  log      $log" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  In game:  netevent wm_dump      full state, right now' -ForegroundColor DarkGray
Write-Host '            netevent wm_selftest  re-run the setup checks' -ForegroundColor DarkGray
Write-Host ''

& $exe @args | Out-Null

# Keep the history. Comparing a run against the previous one is most of
# debugging, and it is impossible if each run erases the last.
if (Test-Path $log) {
    $keep = Join-Path $root 'logs'
    if (-not (Test-Path $keep)) { New-Item -ItemType Directory $keep | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $log (Join-Path $keep "wm-$stamp.log")

    # Prune, or this directory grows without limit and the useful recent ones
    # get lost among a hundred old ones.
    Get-ChildItem $keep -Filter 'wm-*.log' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 30 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $lines = Get-Content $log
    $wm    = $lines | Select-String -Pattern 'WM |WM ERROR|WM warn'
    $errs  = $lines | Select-String -Pattern 'Script error|VM execution|Unknown identifier|Execution could not continue'

    Write-Host ''
    Write-Host "  $($lines.Count) lines, $($wm.Count) from WM, $($errs.Count) engine error(s)" -ForegroundColor DarkGray
    if ($errs.Count) {
        Write-Host ''
        Write-Host '  ENGINE ERRORS' -ForegroundColor Red
        $errs | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }
    if ($Tail) {
        Write-Host ''
        $wm | ForEach-Object { Write-Host "    $_" }
    }
    Write-Host ''
} else {
    Write-Warning "no log was written -- the engine exited before it opened $log"
}
