param(
    [string]$Engine=$env:OPENMW_EXE,
    [string]$GameData=$env:MORROWIND_DATA,
    [switch]$Smoke,
    [switch]$Vanilla,
    [switch]$PrepareOnly
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$lab=Join-Path $root 'tests\engine-lab'
$local=Join-Path $root '.local\test-paths.json'
if (Test-Path -LiteralPath $local) {
    $paths=Get-Content -LiteralPath $local -Raw | ConvertFrom-Json
    if (-not $Engine) { $Engine=$paths.engine }
    if (-not $GameData) { $GameData=$paths.game_data }
}
if (-not $Engine -or -not $GameData) {
    throw 'Pass -Engine and -GameData, set OPENMW_EXE and MORROWIND_DATA, or configure .local/test-paths.json.'
}
$prepare=@("$lab\tools\lab.py", 'prepare', '--engine', $Engine, '--game-data', $GameData)
if ($Vanilla) { $prepare+='--vanilla' }
python @prepare
if ($LASTEXITCODE -ne 0) { throw 'Lab preparation failed.' }
if ($PrepareOnly) { return }
if ($Smoke) { python "$lab\tools\lab.py" run --smoke } else { python "$lab\tools\lab.py" run }
if ($LASTEXITCODE -ne 0) { throw 'Engine test failed; inspect tests/engine-lab/.runtime/report.json.' }
