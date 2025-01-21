########################################################## Commentaires ############################################
#region commentaires
# Script de mise � jour du script Epuration_X3.ps1"
$version = "1.0"
# Derni�re modification : 21/01/2025
# Par JDUB - Soci�t� KARDOL
#endregion
########################################################## D�finition des variables ############################################
#region variables
$ScriptPath = Split-Path -Path $PSCommandPath
$logFileTime = $(Get-Date -Format 'yyyyMMdd-HHmmss')
$logFile = "$ScriptPath\" + "$logFileTime" + "_Epuration_Update.log"
#endregion
########################################################## mise � jour #############################
#region V�rification MAJ
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - D�but du script de mise � jour"
try {
    Add-Content -Path $logFile -Value "  - Lancement du t�l�chargement de Epuration_X3.ps1"
    Invoke-WebRequest -Uri "https://github.com/jdub-kardol/epurationx3/raw/refs/heads/main/Epuration_X3.ps1" -OutFile "$ScriptPath\Epuration_X3.ps1"
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin du script - Raison : mise � jour effectu�e"
    Exit
    }
catch {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Impossible d'effectuer la mise � jour !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    Add-Content -Path $logFile -Value "  - Raison : $($_.Exception.Message)"
    }
#endregion
