$ErrorActionPreference='Stop'
$div='C:\bg3-sidecar-work\Tools\Divine.exe'
$root='C:\Claude Projects\BG3 Mods\ClothMorph_Build'
$src=Join-Path $root '01_runtime_se_mod\ClothMorphRuntime'
$pak=Join-Path $root '01_runtime_se_mod\ClothMorphRuntime_v47.pak'
$live=Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\Mods\ClothMorphRuntime.pak"
$arch='C:\Claude Projects\BG3 Mods\Old ClothMorph Builds'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if (Get-Process bg3,bg3_dx11,bg3_dx12 -EA SilentlyContinue){'ABORT: BG3 running';exit 2}

if(Test-Path $pak){Remove-Item $pak -Force}
& $div -g bg3 -a create-package -s $src -d $pak
"PACK_EXIT=$LASTEXITCODE PAK=$(([IO.FileInfo]$pak).Length)B"

$vdir=Join-Path $root '_pathb\_v47_verify'; if(Test-Path $vdir){Remove-Item $vdir -Recurse -Force}; [IO.Directory]::CreateDirectory($vdir)|Out-Null
& $div -g bg3 -a extract-package -s $pak -d $vdir 2>&1|Out-Null
$ok=$true
$lua=Join-Path $vdir 'Mods\ClothMorphRuntime\ScriptExtender\Lua'
foreach($f in 'BootstrapServer.lua','BootstrapClient.lua','MCMIntegration.lua','Shared.lua','EquipRace.lua','Targeting.lua','BodyRegistry.lua','SharedTemplateProbe.lua'){
  $p=Join-Path $lua $f; $e=Test-Path $p; "in-pak $f = $e"; if(-not $e){$ok=$false}
}
$bs=Get-Content (Join-Path $lua 'BootstrapServer.lua') -Raw
$bc=Get-Content (Join-Path $lua 'BootstrapClient.lua') -Raw
$meta=Get-Content (Join-Path $vdir 'Mods\ClothMorphRuntime\meta.lsx') -Raw
$bp=Get-Content (Join-Path $vdir 'Mods\ClothMorphRuntime\MCM_blueprint.json') -Raw
if($bs -notmatch [regex]::Escape('BootstrapServer v4.7 loaded')){'BS banner missing';$ok=$false}
if($bc -notmatch [regex]::Escape('BootstrapClient v4.7 loaded')){'BC banner missing';$ok=$false}
if($meta -notmatch '755a8a72-407f-4f0d-9a33-274ac0f0b53d'){'MCM dep missing in meta';$ok=$false}
if($bp -match '"Optional"'){'blueprint still Optional';$ok=$false}
if(-not $ok){'ABORT verify';exit 7}
'VERIFY OK'

Copy-Item $live (Join-Path $arch "ClothMorphRuntime_preV47_$stamp.pak") -Force
Copy-Item $pak $live -Force
"DEPLOYED SHA256=$((Get-FileHash $live -Algorithm SHA256).Hash) size=$(([IO.FileInfo]$live).Length)"
Remove-Item $vdir -Recurse -Force
'V47 DONE'
