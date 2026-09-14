# Build RS_VR_Reload.pk3
#
# Entry-by-entry ZipArchive with forward slashes and an ALLOWLIST: Compress-Archive
# writes backslashes SLADE will not open, and a lump name ignores its extension so
# a stray .bak in the root can silently shadow the real lump.
#
# THE MENU IS LINTED FIRST. A slider pointing at a cvar nothing reads is dead, and
# in a headset a dead slider looks exactly like a broken engine. tools/menu_lint.py
# fails the build on it before it can reach one.
#
# BUILT AND CHECKED OFF TO THE SIDE, INSTALLED ONLY ON A PASS. The pk3 is packed into a
# scratch folder under its own name, verified and compile-checked there, and copied over
# RS_VR_Reload.pk3 only once the check passes. Other lanes compile-check against the
# installed pk3 at any moment (RS_VR_Weapons' build loads it); packing straight over it
# left a broken pk3 in place for the length of a failing check, and one of their checks
# loaded exactly that (2026-09-13).
#
# -NoCompileCheck skips the compile check, which runs doomxr.exe -norun -- for a
# builder whose rule is never to run doomxr at all. The pk3 is still verified and
# installed, and the output says it is NOT proven to compile.
param([switch]$NoCompileCheck)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root  = $PSScriptRoot
$final = Join-Path $root 'RS_VR_Reload.pk3'
$stage = Join-Path $env:TEMP 'rs_vr_reload_build'
New-Item -ItemType Directory -Force $stage | Out-Null
$out   = Join-Path $stage 'RS_VR_Reload.pk3'

& python 'E:\DOOMWork\tools\menu_lint.py' $root --prefix wm_
if ($LASTEXITCODE -ne 0) { throw "menu lint failed -- a slider would be dead. See above." }

$rootLumps = @('zscript.txt', 'WMCARD.txt', 'MAPINFO.txt', 'MODELDEF.txt', 'CVARINFO.txt', 'MENUDEF.txt', 'SNDINFO.txt', 'KEYCONF.txt')
$files = @()
foreach ($l in $rootLumps) {
    $p = Join-Path $root $l
    if (-not (Test-Path $p)) { throw "missing required lump: $l" }
    $files += Get-Item $p
}
$files += Get-ChildItem -Path (Join-Path $root 'zscript') -Recurse -File -Filter *.zs
$files += Get-ChildItem -Path (Join-Path $root 'models')  -Recurse -File
$files += Get-ChildItem -Path (Join-Path $root 'sprites') -Recurse -File
$files += Get-ChildItem -Path (Join-Path $root 'sounds')  -Recurse -File

if (Test-Path $out) { Remove-Item $out -Force }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in $files) {
    $rel = ($f.FullName.Substring($root.Length + 1)) -replace ([regex]::Escape([char]92)), '/'
    $e = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $st = $e.Open(); $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $st.Write($b, 0, $b.Length); $st.Dispose()
}
$zip.Dispose(); $fs.Dispose()

# Verify rather than trust: a model that fails to pack is SILENT -- it resolves
# and simply draws nothing, and a missing sound is simply quiet.
$check = [System.IO.Compression.ZipFile]::OpenRead($out)
$names = $check.Entries | ForEach-Object { $_.FullName }
$check.Dispose()
# NO GUN ASSETS. The pistols' meshes, skins and sounds moved to RS_VR_Weapons on
# 2026-09-12; what is left is the system's own: the wire marker, placeholder and
# effect sprites, and the sounds no gun owns (dry click, brass, magazine drop, impact).
$must = @('zscript.txt','WMCARD.txt','MODELDEF.txt','CVARINFO.txt','MENUDEF.txt','SNDINFO.txt','MAPINFO.txt','KEYCONF.txt',
          'zscript/wm/jitter.zs','zscript/wm/sheet.zs',
          'models/rs_wiresphere.obj','models/rs_wire_hot.png','models/rs_wire_idle.png','models/rs_wire_pouch.png',
          'sprites/WMPRA0.png','sprites/WMMGA0.png','sprites/WMRDA0.png','sprites/WMMKA0.png',
          'sprites/WMCSA0.png',
          'sounds/wm/AKEMPT','sounds/wm/DSCASIN1','sounds/wm/DSBOUNC1.ogg')
# AND NONE MAY COME BACK: a gun asset in this pk3 is a gun the reload system owns.
foreach ($gunAsset in @('models/m4a3.md3','models/pistolet.md3','models/bullet.md3','sounds/wm/PFIRE01.ogg','sounds/wm/9mmshoot.wav')) {
    if ($names -contains $gunAsset) { throw "verification failed: $gunAsset is a gun asset -- it belongs to a weapon package" }
}
foreach ($m in $must) {
    if ($names -notcontains $m) { throw "verification failed: $m missing" }
}
Write-Output "RS_VR_Reload.pk3  --  $($names.Count) entries, verified (staged at $out)"

# INSTALL: the checked pk3 over the one other packages load. A running game or another
# lane's compile check may hold it open; then say so and leave the checked build staged.
function Install-Staged {
    try { Copy-Item $out $final -Force }
    catch { throw "could not install -- $final is in use (a game or a compile check has it open). The checked build is at $out; build again once it closes." }
    Write-Output "installed $final ($((Get-Item $final).LastWriteTime.ToString('MM-dd HH:mm:ss')))"
}

if ($NoCompileCheck) {
    Install-Staged
    Write-Output "compile check SKIPPED (-NoCompileCheck) -- NOT proven to compile"
    return
}

# PROVE IT COMPILES, every build -- through the shared hidden check, on the STAGED pk3.
#
# tools\compile_check.ps1 runs doomxr -norun HIDDEN from a scratch folder against a
# SCRATCH COPY of doomxr.ini, and passes only on 'script parsing took' with no script
# error. (The old inline check ran without -config, so the engine's exit-time config
# save would have written the owner's real ini.)
#
# THIS PK3 WITH RS_BALLISTICS BEFORE IT, AND NOTHING ELSE. The reload system REQUIRES
# RS_Ballistics (its guns fire RSB_Bullet, and their flashes and casings are RS_Ballistics',
# RSB_CALL_SITES_HANDOFF.md), so it loads first here as in the owner's order. Nothing else: no
# RS_VR_Weapons, no ModelSwapper -- so the check cannot let it quietly depend on another
# package. It also no longer reads the owner's last load order from the log,
# which named the pre-rename RS_VR_PistolTest.pk3 and failed on a file that no longer
# exists. Whole load orders are checked separately (RS_VR_Weapons' build checks this
# pk3 together with its own).
$ballisticsPk3 = 'E:\DOOMWork\RS_Ballistics\RS_Ballistics.pk3'
if (-not (Test-Path $ballisticsPk3)) { throw "no RS_Ballistics pk3 at $ballisticsPk3 -- the reload system requires it" }
& 'E:\DOOMWork\tools\compile_check.ps1' -Files $ballisticsPk3, $out
if ($LASTEXITCODE -ne 0) { throw "compile check FAILED -- see above. $final was NOT touched." }
Install-Staged
