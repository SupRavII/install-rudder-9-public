# Installation de l'agent Rudder 9.0 sur Windows

Cible : <windows-node> et <windows-host> (Windows 11 Pro 24H2/25H2) une fois la base Linux
stabilisee. La documentation editeur officielle est :
https://docs.rudder.io/reference/9.0/installation/agent/windows.html

Cette page consigne **les pieges specifiques au parc <admin>** qui ne
sont pas couverts par la doc editeur, et qui se reproduiront sur toute
nouvelle machine Windows joignant le serveur Rudder.

## Pieges connus

### 1. Controlled Folder Access (Defender) bloque hdparm.exe

**Symptome :**
Apres install de l'agent, les inventaires hardware remontes a Rudder
sont incomplets (pas de modele/serie/SMART pour les disques physiques).
Cote machine, l'observateur d'evenements Windows logge plusieurs events
1127 par jour dans `Microsoft-Windows-Windows Defender/Operational`,
typiquement deux fois par jour, en sync avec le scheduled task
FusionInventory-Agent :

    L'acces controle aux dossiers a empeche
    C:\Program Files\FusionInventory-Agent\perl\bin\hdparm.exe
    de modifier la memoire.
    Chemin d'acces : \Device\Harddisk0\DR0
    Nom du processus : ...\hdparm.exe

Un event 1127 par disque physique. Sur <windows-host> (3 disques) : 3 events
groupes par scan.

**Cause :**
L'agent Rudder Windows embarque FusionInventory-Agent pour l'inventaire
hardware. FusionInventory utilise `hdparm.exe` (port Windows de l'outil
Linux) pour interroger les disques en I/O brut sur les devices
`\Device\HarddiskX\DRX`. Le bouclier Controlled Folder Access (CFA) de
Defender, active sur le parc <admin> comme protection anti-ransomware,
interprete cette I/O brute comme une tentative de modification de la
memoire des dossiers proteges et tue le processus.

CFA est en place et utile (vmrun, vmware-vmx, LibreHardwareMonitor,
firefox, powershell etc. sont deja whitelistes pour des raisons
similaires). On ne le desactive pas, on whiteliste hdparm.

**Fix :**
PowerShell admin sur la machine Rudder :

    Add-MpPreference -ControlledFolderAccessAllowedApplications `
      'C:\Program Files\FusionInventory-Agent\perl\bin\hdparm.exe'

Verification :

    (Get-MpPreference).ControlledFolderAccessAllowedApplications `
      | Where-Object { $_ -match 'hdparm' }

La sortie doit contenir le chemin complet. L'inventaire suivant
(prochain run du scheduled task FusionInventory, par defaut toutes les
12h) doit remonter cette fois les disques complets.

**Diagnostic si symptome reapparait :**

    Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' `
      -MaxEvents 500 | Where-Object { $_.Message -match 'hdparm' } `
      | Select-Object -First 10 TimeCreated, Id

Si des events 1127 ressortent apres la date du Add-MpPreference, c'est
qu'une strategie centrale (GPO, Intune, ou nouveau scan systeme) a
recrasee la whitelist. Re-appliquer et investiguer la source.

**Historique :**

- 2026-05-16 : whitelist appliquee sur <windows-host>. <windows-node> deja whitelistee a
  une intervention anterieure non documentee. Memo Claude
  `feedback_cfa_fusioninventory_hdparm.md` cree pour que ce piege soit
  verifie automatiquement sur toute prochaine install Rudder Windows.
