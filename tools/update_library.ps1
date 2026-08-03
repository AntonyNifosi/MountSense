# Refreshes the embedded third-party libraries (Libs/) from their upstream
# sources. Run this occasionally (e.g. before cutting a release) to pick up
# the latest mount rarity data — MountsRarity is maintained upstream and
# updated automatically from DataForAzeroth several times a week, so this
# script never needs to know anything about that data itself.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lua-wow/LibStub/master/LibStub.lua" `
    -UseBasicParsing -OutFile (Join-Path $root "Libs\LibStub\LibStub.lua")

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sgade/MountsRarity/master/MountsRarity.lua" `
    -UseBasicParsing -OutFile (Join-Path $root "Libs\MountsRarity\MountsRarity.lua")

Write-Output "Libs/LibStub/LibStub.lua and Libs/MountsRarity/MountsRarity.lua updated."
