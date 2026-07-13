$ErrorActionPreference='Stop'
$div='C:\bg3-sidecar-work\Tools\Divine.exe'
$root='C:\Claude Projects\BG3 Mods\ClothMorph_Build'
$stage=Join-Path $root '_fullbatch_stage\ClothMorphContent'
$banks=Join-Path $stage 'Public\ClothMorphContent\Content\Assets\Characters\Humans'
$fem=Join-Path $stage 'Generated\Public\ClothMorphContent\Assets\Characters\_Models\Humans\_Female'
$pak=Join-Path $root '_pathb\ClothMorphContent_v4.pak'
$live=Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\Mods\ClothMorphContent.pak"
$arch='C:\Claude Projects\BG3 Mods\Old ClothMorph Builds'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if (Get-Process bg3,bg3_dx11,bg3_dx12 -EA SilentlyContinue){'ABORT: BG3 running';exit 2}

# 1. stage Path-B GR2s
$ns=0; Get-Content "$root\_pathb\staged_sbbf.txt" | ?{$_.Trim()} | %{ Copy-Item "$root\_pathb\out_sbbf\$($_).GR2" (Join-Path $fem "Resources\$($_).GR2") -Force; $ns++ }
$nb=0; Get-Content "$root\_pathb\staged_bcb.txt"  | ?{$_.Trim()} | %{ Copy-Item "$root\_pathb\out_bcb\$($_).GR2"  (Join-Path $fem "Resources_BCB\$($_).GR2") -Force; $nb++ }
"staged sbbf=$ns bcb=$nb"

# 2. banks
$jobs=@(
 @{lsx="$root\_fullbatch_stage\refit_full_v4.lsx"; dir='[PAK]_ClothMorph_Refits';     mapk=305; cp=363},
 @{lsx="$root\_bcb_work\refit_bcb_v4.lsx";         dir='[PAK]_ClothMorph_Refits_BCB'; mapk=382; cp=486})
foreach($j in $jobs){
  $tlsf=Join-Path (Join-Path $banks $j.dir) '_merged.lsf'
  & $div -g bg3 -a convert-resource -s $j.lsx -d $tlsf 2>&1|Out-Null
  "CONVERTED $($j.dir) lsf=$(([IO.FileInfo]$tlsf).Length)B"
}

# 3. pack
if(Test-Path $pak){Remove-Item $pak -Force}
& $div -g bg3 -a create-package -s $stage -d $pak
"PACK_EXIT=$LASTEXITCODE PAK=$(([IO.FileInfo]$pak).Length)B"

# 4. listing diff vs live
function Listing($p){ (& $div -g bg3 -a list-package -s $p 2>&1)|?{$_ -match '\S'}|%{($_ -split '\t')[0].Trim()}|?{$_ -match '/|\\'}|Sort-Object }
$d=Compare-Object (Listing $live) (Listing $pak)
"listing diff vs live (want 0): $(@($d).Count)"
if(@($d).Count -ne 0){ $d|%{"  "+$_.SideIndicator+" "+$_.InputObject}; 'ABORT diff'; exit 6 }

# 5. deep verify
$vdir=Join-Path $root '_pathb\_v4_verify'; if(Test-Path $vdir){Remove-Item $vdir -Recurse -Force}; [IO.Directory]::CreateDirectory($vdir)|Out-Null
& $div -g bg3 -a extract-package -s $pak -d $vdir -x "*ClothMorph_Refits*_merged.lsf" 2>&1|Out-Null
& $div -g bg3 -a extract-package -s $pak -d $vdir -x "*Platemail_B_Body.GR2" 2>&1|Out-Null
$ok=$true
foreach($j in $jobs){
  $dirn=$j.dir
  $lsf=Get-ChildItem $vdir -Recurse -Filter '_merged.lsf'|?{$_.FullName -match [regex]::Escape($dirn)}|select -First 1
  $vx=Join-Path $vdir ($dirn.Replace('[PAK]_','')+'.lsx')
  & $div -g bg3 -a convert-resource -s $lsf.FullName -d $vx 2>&1|Out-Null
  $t=Get-Content $vx -Raw
  $mask=([regex]::Matches($t,'VertexColorMaskSlots')).Count
  $cp=([regex]::Matches($t,'<node id="ClothParams">')).Count
  $mapk=([regex]::Matches($t,'id="MapKey"')).Count
  "${dirn}: maskSlots=$mask ClothParams=$cp (want $($j.cp)) mapKeys=$mapk (want $($j.mapk))"
  if($mask -ne 2173 -or $cp -ne $j.cp -or $mapk -ne $j.mapk){$ok=$false}
}
$hS=(Get-FileHash "$root\_pathb\out_sbbf\HUM_F_ARM_Platemail_B_Body.GR2" -Algorithm SHA256).Hash
$hB=(Get-FileHash "$root\_pathb\out_bcb\HUM_F_ARM_Platemail_B_Body.GR2" -Algorithm SHA256).Hash
$gS=Get-ChildItem $vdir -Recurse -Filter 'HUM_F_ARM_Platemail_B_Body.GR2'|?{$_.FullName -notmatch 'Resources_BCB'}|select -First 1
$gB=Get-ChildItem $vdir -Recurse -Filter 'HUM_F_ARM_Platemail_B_Body.GR2'|?{$_.FullName -match 'Resources_BCB'}|select -First 1
$mS=((Get-FileHash $gS.FullName -Algorithm SHA256).Hash -eq $hS)
$mB=((Get-FileHash $gB.FullName -Algorithm SHA256).Hash -eq $hB)
"in-pak Platemail hash match: SBBF=$mS BCB=$mB"
if(-not ($ok -and $mS -and $mB)){'ABORT deep verify';exit 7}
'DEEP VERIFY OK'

# 6. backup + deploy
Copy-Item $live (Join-Path $arch "ClothMorphContent_preV4_$stamp.pak") -Force
Copy-Item $pak $live -Force
"DEPLOYED SHA256=$((Get-FileHash $live -Algorithm SHA256).Hash) size=$(([IO.FileInfo]$live).Length)"
Remove-Item $vdir -Recurse -Force
'V4 DONE'
