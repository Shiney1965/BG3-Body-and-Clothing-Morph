$ErrorActionPreference='Continue'
$D='C:\bg3-sidecar-work\Tools\Divine.exe'
$B='C:\Claude Projects\BG3 Mods\ClothMorph_Build'
foreach($body in 'sbbf','bcb'){
  $gd=Join-Path $B ("_pathb\gate_"+$body)
  New-Item -ItemType Directory -Force $gd | Out-Null
  $keep=Get-Content (Join-Path $B ("_pathb\keep_cloth_"+$body+".txt")) | ?{$_.Trim()}
  # rigid sample: first 20 staged items not in keep
  $staged=Get-Content (Join-Path $B ("_pathb\staged_"+$body+".txt")) | ?{$_.Trim()}
  $rig=@($staged | ?{$keep -notcontains $_} | Select-Object -First 20)
  $todo=@($keep)+$rig
  $n=0
  foreach($name in $todo){
    $glb=Join-Path $gd ($name+'.glb')
    if(Test-Path $glb){ $n++; continue }
    & $D -g bg3 -a convert-model -s (Join-Path $B ("_pathb\out_"+$body+"\"+$name+'.GR2')) -d $glb 2>&1 | Out-Null
    if(Test-Path $glb){ $n++ } else { "EXPORTFAIL $body $name" | Add-Content (Join-Path $B '_pathb\gate_fails.txt') }
  }
  "$body gate exports done: $n / $($todo.Count)"
}
