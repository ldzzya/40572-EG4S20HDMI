param([string]$TdBin = '')
$ErrorActionPreference = 'Stop'
if (!$TdBin) {
    $tdCommand = Get-Command td.exe -ErrorAction SilentlyContinue
    if (!$tdCommand) { throw 'TD not found. Pass -TdBin with the TD bin directory.' }
    $TdBin = Split-Path $tdCommand.Source
}
$tdConsole = Join-Path $TdBin 'td_commands_prompt.exe'
$root = $PSScriptRoot
$bit = Join-Path $root 'build/multimedia_v12_720p.bit'
$log = Join-Path $root 'build/compile.log'
New-Item -ItemType Directory -Force -Path (Join-Path $root 'build') | Out-Null
$started = Get-Date
$scriptFile = (Join-Path $root 'build.tcl').Replace('\','/')
& $tdConsole $scriptFile *> $log
if ($LASTEXITCODE -ne 0) { throw "TD failed. See $log" }
if (!(Test-Path -LiteralPath $bit) -or (Get-Item -LiteralPath $bit).LastWriteTime -lt $started) { throw "No new bitstream. See $log" }
$compileText = Get-Content -LiteralPath $log -Raw
if ($compileText -match "(?m)^.*\bERROR:") { throw 'TD reported an error; reject this BIT.' }
if ($compileText -match 'HDL-5105' -or $compileText -match 'init value of .*menu_font16.*ignored') { throw 'Font ROM initialization failed; do not download this BIT.' }
$badSignals = ($compileText -split "`n") | Where-Object { $_ -match 'HDL-5314|SYN-5013|HDL-7225|HDL-5373.*top_tf_hdmi_audio' -and $_ -notmatch 'src/user_source/hdl_source/(include/sdr_wrrd.enc.v|menu_font16.v)|HDL-5314 Similar messages' }
if ($badSignals) { throw 'Undriven or implicitly redeclared signal: do not download this BIT.' }
$timing = Get-Content -LiteralPath (Join-Path $root 'build/timing.rpt') -Raw
if ($timing -notmatch 'STNS:\s+0\.000ns' -or $timing -notmatch 'HTNS:\s+0\.000ns') { throw 'Timing violations remain; do not treat this build as validated.' }
Write-Output "Build and constrained timing passed: $bit"
