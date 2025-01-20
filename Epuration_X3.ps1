########################################################## Commentaires ############################################
#region commentaires
# Script d'épuration des dossiers pour serveurs Sage X3
$version = "1.0"
# Dernière modification : 20/01/2025
# Par JDUB - Société KARDOL

# Utilisation :
#
# Attention : le script ne supprimera aucun fichier sur la partition système. Il faut donc le placer sur une autre partition et il n'est pas possible de définir des dossiers à épurer qui seraient sur la partition système.
#             Il convient de le lancer une première fois avec l'option "DEBUG" pour vérifier qu'il opère bien dans les dossiers et fichiers traités.
#
# Si le script est lancé sans paramètres ou avec des paramètres inconnus, il opère les actions suivantes :
# - vérifier sa mise à jour
# - suppression de ses propres fichiers journaux plus anciens que 15 jours
# - suppression des fichiers plus anciens que 7 jours dans "runtime\tmp", les dossiers "TMP" de chaque dossier X3, les dossiers "TRA" de chaque dossier et sous-dossier X3. Les fichiers supprimés dans les répertoires "TRA" sont zippés. Ces archives zippées sont gardées une année puis supprimées.
# 
# Si le script est lancé avec ces paramètres (pas d'ordre à respecter dans leur déclaration) :
# - Paramètre "DEBUG" : ne supprime aucun fichier mais les liste dans un journal à la date + _Epuration_X3_Debug.log. Ce paramètre prend le pas sur LOG.
# - Paramètre "LOG" : liste les fichiers supprimés dans un journal à la date + _Epuration_X3_Detail.log
# - Paramètre "NOX3TRT" : ne gère pas et donc ne supprime pas les fichiers dans le dossier "runtime\tmp".
# - Paramètre "NOX3APP" : ne gère pas et donc ne supprime pas les fichiers dans les dossiers "TRA et TMP" de chaque dossiers et sous-dossiers X3.
# - Paramètre "FOLDER" : suppression des fichiers de répertoires précis, et de leurs sous-répertoires, avec compression ou non et indication du nombre de jours à garder. Les informations sont à placer dans le fichier "Epuration_X3.conf"
# - Paramètre "EMAIL" : Envoi d'un email en cas d'erreur(s) dans le traitement du script. Les informations sont à placer dans le fichier "Epuration_X3.conf"
# - Paramètre "ERROR" : à adjoindre au paramètre "EMAIL" pour prise en compte. L'envoi d'email ne s'opère qu'en cas d'erreur.

# Les paramètres "EMAIL" et "FOLDER" nécessitent le fichier "Epuration_X3.conf" qui va contenir les informations en rapport avec les tâches à effectuer.

# Exemple pour un serveur TRT / APP : .\Epuration_X3.ps1
# Exemple pour un serveur TRT / APP sans suppression mais avec journalisation des fichiers traités : .\Epuration_X3.ps1 DEBUG
# Exemple pour un serveur uniquement TRT : .\Epuration_X3.ps1 NOX3APP 
# Exemple pour un serveur sans X3 mais avec des répertoires précis à épurer : .\Epuration_X3.ps1 NOX3APP NOX3TRT FOLDER
# Exemple pour un serveur TRT / APP avec des répertoires précis à épurer et une journalisation de ces fichiers : .\Epuration_X3.ps1 FOLDER LOG
# Exemple pour un serveur TRT / APP et envoi du fichier journal par email : .\Epuration_X3.ps1 FOLDER EMAIL
# Exemple pour un serveur TRT / APP avec des répertoires précis à épurer et envoi du fichier journal par email uniquement en cas d'erreurs : .\Epuration_X3.ps1 FOLDER EMAIL ERROR
#
#endregion
########################################################## Définition des variables ############################################
#region variables
$ScriptPath = Split-Path -Path $PSCommandPath
$SystemDrive = [System.Environment]::SystemDirectory.Substring(0, 2)
$logFileTime = $(Get-Date -Format 'yyyyMMdd-HHmmss')
$logFile = "$ScriptPath\" + "$logFileTime" + "_Epuration_X3.log"
$folderconf = "$ScriptPath\Epuration_X3.conf"
$conflines=@()
$parametres = "nox3app nox3trt debug folder email error log"
$defaultExclude = @("*.zip", "serveur.tra", "accentry.tra", "espion.tra")
$global:NbTotalFichiers = 0
$global:debug = "NON"
$global:log = "NON"
$global:NbErreurs = 0
#endregion
########################################################## Création du fichier journal ############################################
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Lancement du script Epuration X3 v$version"
Add-Content -Path $logFile -Value "  - Chemin de la partition système interdit à l'épuration : $SystemDrive"
try{
########################################################## Vérification que le script est lancé en administrateur et de la variable SystemDrive #############################
#region verif admin et systemdrive
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Le script n'est pas lancé en administrateur - sortie du script !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin du script - Nombre d'erreurs : $global:NbErreurs"
    Exit
    }
If ([string]::IsNullOrEmpty($SystemDrive) -or (-Not (Test-Path $SystemDrive))) {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Impossible de définir la partition système à protéger - sortie du script !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin du script - Nombre d'erreurs : $global:NbErreurs"
    Exit
    }
#endregion
########################################################## Récupération des paramètres passé au script #############################
#region récupération paramètres
#Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début de la récupération des paramètres passés"

If ($args.count -eq 0) {
    Add-Content -Path $logFile -Value "  - Pas de paramètres passés"
    }
Else {
    Add-Content -Path $logFile -Value "  - Paramètres passés : $args"
    }
Foreach ($ligne in $args) {
    If (-Not ($parametres -match $ligne)) {
        Add-Content -Path $logFile -Value "  - Paramètre passé inconnu et non traité : $ligne"
    }
}
If ($args -contains "log" -and $args -notcontains "debug") {
    $logFileDetail = "$ScriptPath\$(Get-Date -Format 'yyyyMMdd-HHmmss')_Epuration_X3_Detail.log"
    Add-Content -Path $logFile -Value "`r`n** Paramètre passé LOG - Les fichiers supprimés seront inscrits dans le journal $logFileDetail *******************"
    $global:log="OUI"
    }
If ($args -contains "debug") {
    $logFileDebug = "$ScriptPath\$(Get-Date -Format 'yyyyMMdd-HHmmss')_Epuration_X3_Debug.log"
    Add-Content -Path $logFile -Value "`r`n*********************** Paramètre passé DEBUG - Aucun fichier ne sera supprimé mais inscrit dans le journal $logFileDebug *******************"
    $global:debug="OUI"
    }
#endregion
########################################################## Lecture du fichier de configuration ###################################
#region Lecture du fichier de configuration
If (($args -contains "EMAIL") -or ($args -contains "FOLDER")) {
    If (-Not (Test-Path $folderconf)) {
        Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de fichier conf - Pas de traitement des paramètres FOLDER et EMAIL !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        $global:NbErreurs +=1
        $args = $args -replace "folder", ""
        $args = $args -replace "email", ""
        }
    Else {
        Get-Content -Path $folderconf | ForEach-Object {
            If ($_.StartsWith("SMTP:") -or $_.StartsWith("FOLD:")) {
                $conflines += $_
            }
        }
    }
}
#$conflines
#endregion
########################################################## Vérification d'une mise à jour #############################
#region Vérification MAJ
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Vérification d'une mise à jour"
try {
    $web = Invoke-WebRequest -Uri "https://github.com/jdub-kardol/epurationx3/raw/refs/heads/main/version.html" -UseBasicParsing
    $webversion = $web.Content.Replace("`n", "").Replace("`r", "")
    Add-Content -Path $logFile -Value "  - Version du script : $version / Version disponible en MAJ : $webversion"
    If ($webversion -gt $version) {
        Add-Content -Path $logFile -Value "  - Lancement du téléchargement de l'exécutable de mise à jour"
        Invoke-WebRequest -Uri "https://github.com/jdub-kardol/epurationx3/raw/refs/heads/main/Epuration_X3_Update.ps1" -OutFile "$ScriptPath\Epuration_X3_Update.ps1"
        $env:EpurationX3Params = $args
        & "$ScriptPath\Epuration_X3_Update.ps1"
        Add-Content -Path $logFile -Value "  - Lancement de l'exécutable de mise à jour et fin du script"
        Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin du script - Raison : mise à jour"
        Exit
        }        
Else {
    Add-Content -Path $logFile -Value "  - Pas de mise à jour"
    }
    }
catch {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Impossible de vérifier ou télécharger la mise à jour !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    Add-Content -Path $logFile -Value "  - Raison : $($_.Exception.Message)"
    $global:NbErreurs +=1
    }
#endregion
########################################################## Definition des fonctions ############################################
#region Fonctions
Function Epuration
{
param (
    [int]$daytokeep,
    [string]$path,
    [string]$filter,
    [array]$exclude,
    [string]$compress
    )

Add-Content -Path $logFile -Value "  - Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
If ($path -like "$SystemDrive*" -or [string]::IsNullOrEmpty($path)) {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Le chemin à épurer est vide ou sur la partition système !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Return
    }
If (-Not (Test-Path $path)) {
    Add-Content -Path $logFile -Value "`r`n  !!!!!!!!!!!!!! Epuration demandé avec chemin $path non trouvé. Epuration non traitée !!!!!!!!!!!!!!`r`n"
    $global:NbErreurs +=1
    }
$jours = (Get-Date).AddDays(-$daytokeep)
$fichiers = (Get-ChildItem -Path $path -Recurse -File -Filter $filter -Exclude $exclude | Where-Object {($_.LastWriteTime -lt $jours)}).FullName
If ($fichiers -like "$SystemDrive*") {
    Add-Content -Path $logFile -Value "`r`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Un ou plusieurs fichiers à épurer sont sur la partition système !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Return
    }
$global:NbTotalFichiers += $fichiers.count
Add-Content -Path $logFile -Value "    Nombre de fichiers traités : $($fichiers.count)"
If ($null -ne $fichiers) {
    If ($global:debug -eq "OUI") {
        Add-Content -Path $logFileDebug -Value "* Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
        Add-Content -Path $logFileDebug -Value "* Nombre de fichiers traités : $($fichiers.count)"
        Add-Content -Path $logFileDebug -Value $fichiers
        Add-Content -Path $logFileDebug -Value ""
        }
    If ($global:log -eq "OUI") {
        Add-Content -Path $logFileDetail -Value "* Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
        Add-Content -Path $logFileDetail -Value "* Nombre de fichiers traités : $($fichiers.count)"
        Add-Content -Path $logFileDetail -Value $fichiers
        Add-Content -Path $logFileDetail -Value ""
        }
    If ($global:debug -eq "NON") {
        If ($compress -eq "Oui") {
            Compress-Archive -Path $fichiers -DestinationPath "$path\$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        }
        Remove-Item $fichiers -Recurse -ErrorAction SilentlyContinue
        }
    }
} #Fin Epuration
#endregion
########################################################## Epuration des journaux plus anciens que 15 jours ############################################
#region Epuration journaux
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Suppression des fichiers journaux plus anciens que 15 jours"
$exclude = @("*.zip", "*.conf", "*.ps1")
Epuration 15 $ScriptPath "*Epuration_X3*" $exclude "NON"

# Suppression des archives ZIP > 1 an
#Epuration 360 $ScriptPath "*.zip" "" "NON"
#endregion
########################################################## Epuration du dossier runtime\tmp ############################################
#region Epuration du dossier runtime\tmp
If ($args -contains "NOX3TRT") {
    Add-Content -Path $logFile -Value "`r`n*********************** Paramètre passé NOX3TRT - Pas d'épuration du dossier runtime\tmp *******************"
    }
Else {
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration runtime\tmp" 
    # Récupération du chemin du runtime X3
    $service = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.PathName -like "*runtime\bin*" }
    If ($service) {
        $runtime = ($($service.PathName) -split " ")[0]
        $runtime = $runtime.Substring(0, $runtime.length - 15) + "tmp"
        # Epuration du runtime\tmp
        If (Test-Path $runtime) {
            Add-Content -Path $logFile -Value "  - Chemin du runtime = $runtime"
            Epuration 7 $runtime * $defaultExclude "NON"
            }
        Else {
            Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de chemin runtime trouvé - Arrêt de l'épuration du runtime\tmp !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            Add-Content -Path $logFile -Value "!!! Si ce serveur ne comporte pas de Runtime X3, pensez à passer le paramètre NOX3TRT pour ne pas avoir cette erreur !!!"
            $global:NbErreurs +=1
            }
        }
    Else {
        Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de service runtime trouvé - Arrêt de l'épuration du runtime\tmp !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Add-Content -Path $logFile -Value "!!! Si ce serveur ne comporte pas de Runtime X3, pensez à passer le paramètre NOX3TRT pour ne pas avoir cette erreur !!!"
        $global:NbErreurs +=1
        }
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration runtime\tmp"
    }
#endregion
########################################################## Epuration sous-dossiers X3 répertoires TRA/TMP ############################################
#region Epuration sous-dossiers X3 répertoires TRA/TMP
If ($args -contains "NOX3APP") {
    Add-Content -Path $logFile -Value "`r`n*********************** Paramètre passé NOX3APP - Pas d'épuration des sous-dossiers X3 répertoires TRA/TMP *******************"
    }
Else {
    # Récupération du chemin des dossiers X3
    $BDRKey = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Sage .* Application Component" }
    If (-not [string]::IsNullOrEmpty($BDRKey)) {
        $BDRKey = $BDRKey.Name -replace "HKEY_LOCAL_MACHINE", "HKLM:"
        $X3APPPATH = Get-ItemProperty -Path $BDRKey
        $X3APPPATH = $X3APPPATH.DisplayIcon
        $x3folder = $X3APPPATH.replace("\Uninstaller\UninstallerIcon.ico", "")
        If (Test-Path $x3folder) {
            # Récupération et épuration de la liste des sous-dossiers X3 TMP à traiter
            Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration sous-dossiers X3 répertoires TMP"
            Add-Content -Path $logFile -Value "  - Chemin des dossiers X3 = $x3folder"
            # Listing des dossiers TMP à la racine des dossiers X3 et X3_PUB seulement. 
            $foldersTMP = Get-ChildItem -Path $x3folder -Directory -Recurse -Include TMP | Where-Object {
                ($_ | Get-Item).FullName.Split('\').Count -le ($x3folder.Split('\').Count + "2")
                }
            $foldersTMP += Get-ChildItem -Path "$x3folder\X3_PUB" -Directory -Recurse -Include TMP | Where-Object {
                ($_ | Get-Item).FullName.Split('\').Count -le ($x3folder.Split('\').Count + "3")
                }
             ForEach ($folderTMP in $foldersTMP) {
                Epuration 7 $folderTMP.Fullname * $defaultExclude NON
                }
            # Epuration de TMP dans X3\SRV
            Epuration 7 "$x3folder\X3\SRV\tmp" * $defaultExclude NON
            Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration sous-dossiers X3 répertoires TMP"

            # Récupération et épuration de la liste des sous-dossiers X3 TRA à traiter
            Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration sous-dossiers X3 répertoires TRA"
            Add-Content -Path $logFile -Value "  - Chemin des dossiers X3 = $x3folder"
            Get-ChildItem -Path $x3folder -Directory -Recurse -Include TRA | ForEach-Object {
                Epuration 7 $_.FullName * $defaultExclude "OUI"
                Epuration 360 $_.FullName "*.zip" "" "NON"
                }
            Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration sous-dossiers X3 répertoires TRA"
            }
        Else {
            Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de chemin des dossiers X3 trouvé - Arrêt épuration sous-dossiers X3 répertoires TRA/TMP !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            Add-Content -Path $logFile -Value "!!! Si ce serveur ne comporte pas le composant d'application X3, pensez à passer le paramètre NOX3APP pour ne pas avoir cette erreur !!!"
            $global:NbErreurs +=1
            }
        }
    Else {
        Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de chemin des dossiers X3 trouvé - Arrêt épuration sous-dossiers X3 répertoires TRA/TMP !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        $global:NbErreurs +=1
        }
    }
#endregion
########################################################## Traitement du paramètre FOLDER ############################################
#region FOLDER
If ($args -contains "FOLDER") {
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Traitement du paramètre FOLDER"
    $parameterline=@()
    $conflines | Where-Object {$_.StartsWith("FOLD") } | ForEach-Object {
        $_ = $_.Substring(5)
        $parameterline = $_ -split ";"
        $exclude = @($parameterline[3] -split " ")
        Else {
            Epuration $parameterline[0] $parameterline[1] $parameterline[2] $exclude $parameterline[4]
            }
        }
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin traitement du paramètre FOLDER" 
    }
#endregion
########################################################## Fin des épurations ############################################
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin des épurations - Nombre d'erreurs : $global:NbErreurs - Nombre total de fichiers traités : $global:NbTotalFichiers"
########################################################## Traitement du paramètre EMAIL ############################################
#region EMAIL
If ($args -contains "EMAIL") {
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Traitement du paramètre EMAIL"
    $logfiletemp = "$env:TEMP\"  + "$logFileTime" + "_Epuration_X3.log"
    Copy-Item -Path $logFile -Destination $logfiletemp
    $smtp = $conflines | Where-Object {$_.StartsWith("SMTP")}
    $smtp = $smtp.Substring(5)
    $parameterline = $smtp -split ";"
    $smtpparameters = @{
        From = "$($parameterline[3])"
        To = "$($parameterline[4])"
        Subject = "Script Epuration X3 sur $env:computername"
        Body = "Veuillez trouver en piece jointe le fichier journal de l'epuration des dossiers lancee sur $env:computername le $logFileTime"
        SmtpServer = "$($parameterline[0])"
        Port = $($parameterline[1])
        Attachments = $logfiletemp
        }
    If ($parameterline[2] -eq "OUI") {
        $smtpparameters["UseSsl"] = $true
        }
    If (-not [string]::IsNullOrEmpty($parameterline[5]) -and -not [string]::IsNullOrEmpty($parameterline[6])) {
        $credential = New-Object System.Management.Automation.PSCredential ($parameterline[5], (ConvertTo-SecureString $parameterline[6] -AsPlainText -Force))
        $smtpparameters["Credential"] = $credential
        }
    try {
        If ($args -contains "ERROR" -and $global:NbErreurs -eq 0) {
            Add-Content -Path $logFile -Value "  - Pas d'email envoyé à $($parameterline[4]) car paramètre ERROR passé et pas d'erreurs"
            }
        Else {
            Send-MailMessage @smtpparameters -ErrorAction Stop
            Add-Content -Path $logFile -Value "  - Email envoyé à $($parameterline[4])"
            Remove-Item $logfiletemp -ErrorAction SilentlyContinue
        }
        }
    catch {
        Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Envoi du message impossible !!!!!!!!!!!!!!!!!!!!!!!!!!!!!`r`nRaison : $($_.Exception.Message)"
        $global:NbErreurs +=1
        }
    }
#endregion
########################################################## Fin du script ############################################
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin du script - Nombre d'erreurs : $global:NbErreurs"
}
catch {
Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR GENERALE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!`r`nRaison : $($_.Exception.Message)"
}
