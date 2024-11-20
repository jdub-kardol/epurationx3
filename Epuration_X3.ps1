########################################################## Commentaires ############################################
#region commentaires
# Script d'épuration des dossiers pour serveurs Sage X3
$version = "1.5"
# Dernière modification : 21/10/2024
# Par JDUB - Société KARDOL

# Utilisation :
# Si le script est lancé sans paramètres ou avec des paramètres inconnus, il ne fait que vérifier sa mise à jour et supprimer ses propres fichiers journaux plus anciens que 15 jours.
# Si le script est lancé avec ces paramètres :
# - Paramètre "DEBUG" : ne supprime aucun fichier mais les liste dans un journal à la date + _Epuration_X3_Debug.log. Ce paramètre prend le pas sur LOG.
# - Paramètre "LOG" : liste les fichiers supprimés dans un journal à la date + _Epuration_X3_Detail.log
# - Paramètre "DEFAULT" : suppression des fichiers plus anciens que 15 jours dans "runtime\tmp", les dossiers "TRA et TMP" de chaque dossiers et sous-dossiers X3. Les fichiers supprimés dans les répertoires "TRA" sont zippés. Ces archives zippées sont gardées une année puis supprimées.
# - Paramètre "TRT" : A adjoindre au paramètre "DEFAULT" pour prise en compte. Suppression des fichiers plus anciens que 15 jours dans "runtime\tmp". Les dossiers "TRA et TMP" de chaque dossiers et sous-dossiers X3 sont ignorés.
# - Paramètre "FOLDER" : suppression des fichiers de répertoires précis avec compression ou non et indication du nombre de jours à garder. Les informations sont à placer dans le fichier "Epuration_X3.conf"
# - Paramètre "EMAIL" : Envoi d'un email en cas d'erreur(s) dans le traitement du script. Les informations sont à placer dans le fichier "Epuration_X3.conf"
# - Paramètre "ERROR" : à adjoindre au paramètre "EMAIL" pour prise en compte. L'envoi d'email ne s'opère qu'en cas d'erreur.
#
# Les paramètres "EMAIL" et "FOLDER" nécessitent le fichier "Epuration_X3.conf" qui va contenir les informations en rapport avec les tâches à effectuer.
#
# Exemple pour un serveur TRT / APP : .\Epuration_X3.ps1 DEFAULT
# Exemple pour un serveur uniquement TRT : .\Epuration_X3.ps1 DEFAULT TRT
# Exemple pour un serveur avec des répertoires précis à épurer : .\Epuration_X3.ps1 FOLDER
# Exemple pour un serveur TRT / APP avec des répertoires précis à épurer : .\Epuration_X3.ps1 DEFAULT FOLDER
# Exemple pour un serveur TRT / APP avec des répertoires précis à épurer et envoi du fichier journal par email : .\Epuration_X3.ps1 DEFAULT FOLDER EMAIL
# Exemple pour un serveur TRT / APP avec des répertoires précis à épurer et envoi du fichier journal par email uniquement en cas d'erreurs : .\Epuration_X3.ps1 DEFAULT FOLDER EMAIL ERROR
#
#endregion
########################################################## Définition des variables ############################################
#region variables
$ScriptPath = Split-Path -Path $PSCommandPath
$logFileTime = $(Get-Date -Format 'yyyyMMdd-HHmmss')
$logFile = "$ScriptPath\" + "$logFileTime" + "_Epuration_X3.log"
$folderconf = "$ScriptPath\Epuration_X3.conf"
$conflines=@()
$parametres = "default debug trt folder email error log"
$defaultExclude = @("*.zip", "serveur.tra", "accentry.tra", "espion.tra")
$global:NbTotalFichiers = 0
$global:debug = "NON"
$global:log = "NON"
$global:NbErreurs = 0
#endregion
########################################################## Création du fichier journal ############################################
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Lancement du script Epuration X3 v$version"
########################################################## Récupération des paramètres passé au script #############################
#region récupération paramètres
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début de la récupération des paramètres passés"

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
$jours = (Get-Date).AddDays(-$daytokeep)
$fichiers = (Get-ChildItem –Path $path -Recurse -File -Filter $filter -Exclude $exclude | Where-Object {($_.LastWriteTime -lt $jours)}).FullName
Add-Content -Path $logFile -Value "  - Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
$nbfichiers = $fichiers.count
$global:NbTotalFichiers += $fichiers.count
Add-Content -Path $logFile -Value "    Nombre de fichiers traités : $nbfichiers"
If ($null -ne $fichiers) {
    If ($global:debug -eq "OUI") {
        Add-Content -Path $logFileDebug -Value "* Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
        Add-Content -Path $logFileDebug -Value "* Nombre de fichiers traités : $nbfichiers"
        Add-Content -Path $logFileDebug -Value $fichiers
        Add-Content -Path $logFileDebug -Value ""
        }
    If ($global:log -eq "OUI") {
        Add-Content -Path $logFileDetail -Value "* Epuration lancée avec paramètres : chemin = $path | Nbre de jours = $daytokeep | Filtres = $filter | Exclusions = $exclude | Compression = $compress"
        Add-Content -Path $logFileDetail -Value "* Nombre de fichiers traités : $nbfichiers"
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

Function Default
{
param (
    [string]$trt
    )
# Récupération du chemin du runtime X3
$service = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.PathName -like "*runtime\bin*" }
If ($service) {
    $runtime = ($($service.PathName) -split " ")[0]
    $runtime = $runtime.Substring(0, $runtime.length - 15)
    Add-Content -Path $logFile -Value "  - Chemin du runtime = $runtime"
    }
Else {
    Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de service runtime trouvé - Arrêt de traitement du paramètre DEFAULT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Return
    }

# Epuration du runtime\tmp
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration runtime\tmp" 
$runtimetmp = $runtime + "tmp"
Epuration 15 $runtimetmp * $defaultExclude "NON"
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration runtime\tmp" 

If ($trt -eq "OUI") {
    Add-Content -Path $logFile -Value "`r`n*********************** Paramètre passé TRT - Pas de traitement des dossiers applicatifs X3 TRA et TMP *******************"
    Return
}
# Récupération du chemin des dossiers X3
$BDRKey = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Sage .* Application Component" }
If (-not [string]::IsNullOrEmpty($BDRKey)) {
    $BDRKey = $BDRKey.Name -replace "HKEY_LOCAL_MACHINE", "HKLM:"
    $X3APPPATH = Get-ItemProperty -Path $BDRKey
    $X3APPPATH = $X3APPPATH.DisplayIcon
    $x3folder = $X3APPPATH.replace("\Uninstaller\UninstallerIcon.ico", "")
    }
Else {
    $x3folder = "z:\terterse"
    }
If (-Not (Test-Path $x3folder)) {
    Add-Content -Path $logFile -Value "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERREUR - Pas de chemin des dossiers X3 trouvé - Arrêt de traitement du paramètre DEFAULT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    $global:NbErreurs +=1
    Return
    }
Add-Content -Path $logFile -Value "  - Chemin des dossiers X3 = $x3folder"

# Récupération et épuration de la liste des sous-dossiers X3 TMP à traiter
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration sous-dossiers X3 répertoires TMP"
Get-ChildItem -Path $x3folder -Directory -Recurse -Include TMP | ForEach-Object {
    Epuration 15 $_.FullName * $defaultExclude NON
    }
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration sous-dossiers X3 répertoires TMP"

# Récupération et épuration de la liste des sous-dossiers X3 TRA à traiter
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Début épuration sous-dossiers X3 répertoires TRA"
Get-ChildItem -Path $x3folder -Directory -Recurse -Include TRA | ForEach-Object {
    Epuration 15 $_.FullName * $defaultExclude "OUI"
    Epuration 360 $_.FullName "*.zip" "" "NON"
    }
Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Fin épuration sous-dossiers X3 répertoires TRA"
} #Fin function Default
#endregion
########################################################## Epuration des journaux plus anciens que 15 jours ############################################
#region Epuration journaux
Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Suppression des fichiers journaux plus anciens que 15 jours"
$exclude = @("*.zip", "*.conf", "*.ps1")
Epuration 15 $ScriptPath "*Epuration_X3*" $exclude "NON"

# Suppression des archives ZIP > 1 an
#Epuration 360 $ScriptPath "*.zip" "" "NON"
#endregion
########################################################## Traitement du paramètre DEFAULT ############################################
#region DEFAULT
If ($args -contains "DEFAULT") {
    Add-Content -Path $logFile -Value "`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Traitement du paramètre DEFAULT"
    If ($args -contains "TRT") {
        $trt = "OUI"
    }
    Else {
        $trt= "NON"
    }
    Default($trt)
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
        If (-Not (Test-Path $parameterline[1])) {
            Add-Content -Path $logFile -Value "`r`n  !!!!!!!!!!!!!! Epuration demandé avec chemin $($parameterline[1]) non trouvé. Epuration non traitée !!!!!!!!!!!!!!`r`n"
            $global:NbErreurs +=1
            }
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
