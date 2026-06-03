#Requires -RunAsAdministrator
# remove-windows-legal-notice.ps1
#
# Supprime le LegalNotice (ecran plein-ecran "Notice" avec bouton OK
# affiche apres login, avant l'arrivee sur le bureau) sur un poste
# Windows 11 precedemment manage par la technique Rudder
# `motdConfiguration` 3.3.
#
# Contexte : la technique motdConfiguration ecrit en realite dans
#   HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
# (LegalNoticeCaption + LegalNoticeText), PAS dans Policies\System
# comme le suggere la documentation MS classique. Un nettoyage
# uniquement sur Policies\System ne suffit donc pas : la banniere
# reste affichee. Ce script ratisse les trois emplacements connus.
#
# A executer en PowerShell admin, post-rollback Rudder community
# (cf. rollback-to-community.sh) ou sur tout poste Windows ou la
# technique motdConfiguration a ete utilisee puis retiree.

$targets = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',
  'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
)

Write-Host "=== Etat avant ===" -ForegroundColor Cyan
foreach ($p in $targets) {
  $v = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
  if ($v) {
    $cap = $v.LegalNoticeCaption
    $txt = $v.LegalNoticeText
    if ($cap -or $txt) {
      Write-Host "[$p]" -ForegroundColor Yellow
      Write-Host "  Caption: $cap"
      Write-Host "  Text   : $($txt -replace "`r?`n", ' | ' | ForEach-Object { if ($_.Length -gt 200) { $_.Substring(0,200)+'...' } else { $_ } })"
    }
  }
}

Write-Host "`n=== Suppression ===" -ForegroundColor Cyan
foreach ($p in $targets) {
  foreach ($name in 'LegalNoticeCaption','LegalNoticeText') {
    $exists = (Get-ItemProperty -Path $p -Name $name -ErrorAction SilentlyContinue) -ne $null
    if ($exists) {
      Remove-ItemProperty -Path $p -Name $name -ErrorAction SilentlyContinue
      Write-Host "  Supprime $p\$name" -ForegroundColor Green
    }
  }
}

Write-Host "`n=== Etat apres ===" -ForegroundColor Cyan
$found = $false
foreach ($p in $targets) {
  $v = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
  if ($v -and ($v.LegalNoticeCaption -or $v.LegalNoticeText)) {
    Write-Host "RESTE: $p" -ForegroundColor Red
    $found = $true
  }
}
if (-not $found) { Write-Host "Aucune valeur LegalNotice restante dans les 3 emplacements." -ForegroundColor Green }

Write-Host "`n=== reg query (filet de securite) ===" -ForegroundColor Cyan
reg query HKLM /f LegalNotice /s 2>$null | Select-String -Pattern 'LegalNotice|HKEY'

gpupdate /force | Out-Null
Write-Host "`ngpupdate execute. Reboot ou logoff/logon pour tester." -ForegroundColor Green
