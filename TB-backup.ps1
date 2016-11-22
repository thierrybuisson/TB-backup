##############################################################
#
# based on Powershell script by Jesper M. Christensen
# Blog: http://JesperMChristensen.spaces.live.com
#
# Codeplex project: http://www.codeplex.com/spbackup
#
# Backup Sharepoint farm, sites, 12-hive and IIS Metadata
#
# Modifié par Thierry Buisson
# 
# SPBackup.ps1 version 1.2 - Edited December 16. 2008
# TB-Backup.ps1 version 1.4 :
#   - Add farm name and smtp configuration
#   - Add <folder tag to enable zip folder
#   - one file log for each scripts in "logs" folder
# TB-Backup.ps1 version 1.5 :
#   - various corerction (folderdestination for folder backup)
#   - backupfilename starts with is tag id
# TB-Backup.ps1 version 1.6 :
#   - add functions files
# 	- Add try catch
# 	- Traduction en francais
# # TB-Backup.ps1 version 1.7 :
#	- fautes d'orthographe
#	- Ajout du computername dans le titre du fichier de logs
# # TB-Backup.ps1 version 2.0 :
#   - ajout des wildcardinclusions dans le fichier de config
##############################################################

$Host.UI.RawUI.WindowTitle = " -- Tb-Backup --"
$0 = $myInvocation.MyCommand.Definition
$dp0 = [System.IO.Path]::GetDirectoryName($0)
# $bits = Get-Item $dp0 | Split-Path -Parent

# Nom de la machine courante
$COMPUTERNAME = $env:COMPUTERNAME

#Initialize default variables
# $logtime 			=  Get-Date -Format "yyyyMMdd-HHmmss";
$LogTime = Get-Date -Format yyyy-MM-dd_h-mm
$script:LogFile = "$dp0\logs\"+$COMPUTERNAME+"_TB-backup-$LogTime.rtf"

$global:log		  	= ""
$global:jobstatus	= "Reussi"
$script:MailInfos = @()

#Récupération du fichier XML de configuration
$configfromcmd = $args[0]
if(![string]::IsNullOrEmpty($configfromcmd)){
	$ConfigurationfileName = $configfromcmd
	$Configurationfile  = ".\$configfromcmd"
}
else{
	$ConfigurationfileName = "Tb-Backup.xml"
	$Configurationfile  = $dp0 + "\" + $ConfigurationfileName 
}

$argactions = $args[1]
$ListActions = $argactions.split(";")

#Create log file
# New-Item $script:LogFile -type file -force

#Region External Functions
. "$dp0\TB-BackupFunctions.ps1"
#EndRegion

StartTracing
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
If (!$env:StartDate) {$env:StartDate = Get-Date}
Write-Host -ForegroundColor White "-----------------------------------"
Write-Host -ForegroundColor White "| Script de sauvegarde/restore Sharepoint |"
Write-Host -ForegroundColor White "| par Thierry Buisson : www.thierrybuisson.fr |"
Write-Host -ForegroundColor White "| Demarrage : $env:StartDate |"
Write-Host -ForegroundColor White "| Utilisateur : $CurrentUser |"
Write-Host -ForegroundColor White "-----------------------------------"

Try 
{
	if (!(Test-Path($Configurationfile))){
		Throw "  - Fichier de configuration $Configurationfile introuvable"
	}
	
	Write-Host -ForegroundColor white " - Le fichier de configuration est $ConfigurationfileName"
	Write-Host -ForegroundColor white " - Lancement des actions [$argactions]"
	$xmlinput       = [xml] (get-content $Configurationfile)
	$ghive = $xmlinput.configuration.farm.hive
	
	GetCurrentComputerConfiguration
	
	foreach ($action in $ListActions){
		$a = $action.ToUpper()
		Write-Host -ForegroundColor yellow " - Execution de la commande [$a]"
		
		if ($a -eq "FULL"){
			FullBackup
		}
		elseif ($a -eq "BACKUP"){
			BackupSites
		}
		elseif ($a -eq "RESTORE"){
			RestoreSites
		}
		elseif ($a -eq "FOLDERS"){
			BackupFolders
		}
		else{
			Write-Host -ForegroundColor red " - Action [$action] inconnue, merci de préciser full, backup, restore ou folders"
		}
	}
}
Catch 
{
	# WriteLine
	Write-Host -ForegroundColor Yellow " - Script arrété!"	
	If ($_.FullyQualifiedErrorId -ne $null -and $_.FullyQualifiedErrorId.StartsWith(" - ")) 
	{
		# Error messages starting with " - " are thrown directly from this script
		Write-Host -ForegroundColor Red $_.FullyQualifiedErrorId
	}
	Else
	{
		#Other error messages are exceptions. Can't find a way to make this Red
		$_ 
		# | Format-List -Force
	}
	$env:EndDate = Get-Date
	Write-Host -ForegroundColor White "-----------------------------------"
	Write-Host -ForegroundColor White "| Script de sauvegarde/restore Sharepoint |"
	Write-Host -ForegroundColor White "| par Thierry Buisson : www.thierrybuisson.fr |"
	Write-Host -ForegroundColor White "| Demarre le : $env:StartDate |"
	Write-Host -ForegroundColor White "| Arrete :    $env:EndDate |"
	Write-Host -ForegroundColor White "-----------------------------------"
}
Finally 
{
    Stop-Transcript
	SendReportEmail
	If ($ScriptCommandLine) {Exit}
	# Else {Pause}
	# Invoke-Item $LogFile
}


