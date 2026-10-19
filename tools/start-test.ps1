param(
    [string]$Engine=$env:OPENMW_EXE,
    [string]$GameData=$env:MORROWIND_DATA,
    [switch]$Launch
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test-game.ps1') -Engine $Engine -GameData $GameData -PrepareOnly:(-not $Launch)
