$ErrorActionPreference='Continue'
$D='C:\bg3-sidecar-work\Tools\Divine.exe'
$B='C:\Claude Projects\BG3 Mods\ClothMorph_Build'
$map=Get-Content (Join-Path $B '_pathb\van_paths.json') -Raw | ConvertFrom-Json
$outd=Join-Path $B '_pathb\gr2_ordered'
New-Item -ItemType Directory -Force $outd | Out-Null
$n=0; $fail=0
foreach($p in $map.PSObject.Properties){
  $dst=Join-Path $outd ($p.Name+'.GR2')
  if(Test-Path $dst){ $n++; continue }
  & $D -g bg3 -a convert-model -s $p.Value -d $dst 2>&1 | Out-Null
  if(Test-Path $dst){ $n++ } else { $fail++; "FAIL $($p.Name)" | Add-Content (Join-Path $B '_pathb\rewrite_fails.txt') }
}
"REWRITE DONE ok=$n fail=$fail"
