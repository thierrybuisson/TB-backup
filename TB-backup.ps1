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

#Region External Functions
. "$dp0\modules\TB-BackupFunctions.ps1"
. "$dp0\modules\TB-LoggingFunctions.ps1"
#EndRegion

# Region gestion des arguments
# Write-Host -nonewline " $($args.Length) arguments : ";
$gargs = @{}
$i = 0
foreach ($arg in $args)
{
  LogWrite -message "$arg |" -nonewline $true;
  $arg=[string]$arg
  if ($arg.Startswith("-")){
	
	$s = [string]$args[$i+1]
	# LogWrite -message "$arg detecté, suivant : $s";
	if ($s -eq ""){
		$gargs[$arg] = $true
	}
	elseif ($s.Startswith("-")){
		$gargs[$arg] = $true
	}else{
		$gargs[$arg] =  $($args[$i+1])
	}
  }
 $i++
}
LogWrite -message " "
#EndRegion

#Récupération du fichier XML de configuration
$configfromcmd = $gargs["-configuration"]
if(![string]::IsNullOrEmpty($configfromcmd)){
	$ConfigurationfileName = $configfromcmd
	$Configurationfile  = ".\$configfromcmd"
}
else{
	$ConfigurationfileName = "Tb-Backup.xml"
	$Configurationfile  = $dp0 + "\" + $ConfigurationfileName 
}

StartTracing
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
If (!$env:StartDate) {$env:StartDate = Get-Date}
LogWrite -message "-----------------------------------"
LogWrite -message "| Script de sauvegarde/restore Sharepoint |"
LogWrite -message "| par Thierry Buisson : www.thierrybuisson.fr |"
LogWrite -message "| Demarrage : $env:StartDate |"
LogWrite -message "| Utilisateur : $CurrentUser |"
LogWrite -message "-----------------------------------"

Try 
{
	if (!(Test-Path($Configurationfile))){
		Throw "  - Fichier de configuration $Configurationfile introuvable"
	}
	
	LogWrite -message "Le fichier de configuration est $ConfigurationfileName"
	LogWrite -message "Lancement des actions [$($gargs["-action"])]"
	$xmlinput       = [xml] (get-content $Configurationfile)
	$ghive = $xmlinput.configuration.farm.hive
	
	GetCurrentComputerConfiguration
	
	foreach ($action in $($gargs["-action"]).split(";")){
		$a = $action.ToUpper()
		LogWrite -message  "Execution de la commande [$a]" -severity 2
		
		if ($a -eq "FULL"){
			FullBackup
		}
		elseif ($a -eq "BACKUP"){
			BackupSites
		}
		elseif ($a -eq "RESTORE"){
			RestoreSites
		}
		elseif ($a -eq "FOLDER"){
			BackupFolders
		}
		else{
			LogWrite -severity 3 -message "Action [$action] inconnue, merci de préciser full, backup, restore ou folder"
		}
	}
}
Catch 
{
	# WriteLine
	LogWrite -severity 2 -message "Script arrété!"	
	If ($_.FullyQualifiedErrorId -ne $null -and $_.FullyQualifiedErrorId.StartsWith("")) 
	{
		# Error messages starting with "" are thrown directly from this script
		LogWrite -severity 3 -message $_.FullyQualifiedErrorId
	}
	Else
	{
		#Other error messages are exceptions. Can't find a way to make this Red
		$_ 
		# | Format-List -Force
	}
	$env:EndDate = Get-Date
	LogWrite -message "-----------------------------------"
	LogWrite -message "| Script de sauvegarde/restore Sharepoint |"
	LogWrite -message "| par Thierry Buisson : www.thierrybuisson.fr |"
	LogWrite -message "| Demarre le : $env:StartDate |"
	LogWrite -message "| Arrete :    $env:EndDate |"
	LogWrite -message "-----------------------------------"
}
Finally 
{
    Stop-Transcript
	SendReportEmail
	If ($ScriptCommandLine) {Exit}
	# Else {Pause}
	# Invoke-Item $LogFile
}


