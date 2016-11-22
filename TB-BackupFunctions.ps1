#Log events function
function Logging { 
 $logmsg = $args[0]
 $mylogtime = Get-Date -Format "yyyyMMdd-HHmmss"; 
 Write-Host $logmsg 
 $strLog = "[" + $mylogtime + "]	"+ $logmsg
 $global:log+=$strLog + "<br>";
}

#Region Start logging to user's desktop
Function StartTracing{
    Start-Transcript -Path $script:LogFile -Force
}
#EndRegion


#Will send email report
function SendReportEmail{
#  ---
#  --- Report to e-mail if email and smtpserver is defined ---
#  ---

	$farmName		= $xmlinput.configuration.farm.name
	$smtpserver 	= $xmlinput.configuration.farm.smtpserver
	$fromemail 		= $xmlinput.configuration.farm.fromemail
	$toemail 		= $xmlinput.configuration.farm.toemail
	$hive 			= $xmlinput.configuration.farm.hive
	$datemail 		= (Get-Date -Format "yyyyMMdd-HHmmss")
	# $xmlinput.configuration.farm
	#Encodage UTF8
	$encodingMail = [System.Text.Encoding]::UTF8
	$status = $global:jobstatus
	$suj ="$farmName / $status / Sauvegarde termine sur $COMPUTERNAME à $datemail"
		
	$toAddress = $toemail.Split(";")
	$htmlBody="<html>"
	$htmlBody+="<body>"
	$htmlBody+="<p>Bonjour,</p>"
	$htmlBody+="<br/>"
	$htmlBody+="<p>Le backup/restore s'est terminé à l'etat $status</p>"
	$htmlBody+="<br/>"
	$tabs= $script:MailInfos
	if ($tabs.length -gt 0){
		$htmlBody+="<p><u>Informations de traitement :</u></p>"
		$htmlBody+="<ul>"
			foreach ($line in $tabs){
				if($line -is [system.array]){
					$ltype = $($line[0]).ToUpper()
					$description = $line[1]
					if ($ltype -eq "INFO"){
						$htmlBody+="<li><span style='color:green'>$ltype : $description</span></li>"
					}
					elseif ($ltype -eq "ERREUR"){
						$htmlBody+="<li><span style='color:red'>$ltype : $description</span></li>"
					}
					else{
						$htmlBody+="<li><span style='color:gray'>$ltype : $description</span></li>"
					}
				}else
				{
					$htmlBody+="<li>$line</li>"
				}
			}
		$htmlBody+="</ul>"
	}
	$htmlBody+="<br/><br/>"
	$htmlBody+="$datemail version $($xmlinput.configuration.version)"
	$htmlBody+=""
	$htmlBody+="</body>"
	$htmlBody+="</html>"
	
	# Send-MailMessage -To $toAddress -SmtpServer $smtpserver -subject "$farmName / $status / sauvegarde termine sur $COMPUTERNAME" -From $fromemail -Body "TEST" -BodyAsHtml -Encoding $encodingMail -Attachments $script:LogFile
	If (![string]::IsNullOrEmpty($smtpserver))
	{
		Try{
			# Write-Host -ForegroundColor gray " - $suj  "
			# Write-Host -ForegroundColor gray " - $htmlBody "
			
			Write-Host -ForegroundColor White -nonewline " - Envoie du rapport par email de $fromemail à $toemail Statut $status"
	
			Send-MailMessage -To $toAddress -SmtpServer $smtpserver -subject $suj -From $fromemail -Body $htmlBody -BodyAsHtml -Encoding $encodingMail -Attachments $script:LogFile
			Write-Host -ForegroundColor green " Réussi"
		}
		Catch{
			$global:jobstatus	= "Echec"
			Write-Host -ForegroundColor red  " echec !"
			Write-Host -ForegroundColor red  " $_"
		}
   }
}

function out-zip { 
 $path = $args[0] 
 $files = $input 

 if (-not $path.EndsWith('.zip')) {$path += '.zip'} 

 if (-not (test-path $path)) 
 { 
	set-content $path ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) 
 } 

 $zipfile = (new-object -com shell.application).NameSpace($path) 
 $files | foreach {$zipfile.CopyHere($_.fullname) } 
} 

function GetCurrentComputerConfiguration{
	
	$QueryOS = Gwmi Win32_OperatingSystem -Comp localhost 
	$QueryOS = $QueryOS.Caption 

	If ($QueryOS.contains("2008") -or $QueryOS.contains("Vista"))
	{
		Write-Host -ForegroundColor White " - Windows Server 2008 ou Vista detecté"
	}

	If ($QueryOS.contains("2003"))
	{
		Write-Host -ForegroundColor White " - Windows Server 2003 detecté"
	}
}

# Method de zip via l'outil en ligne de command 7zip
function Create-7zip([String] $aDirectory, [String] $OutPutName){
    $pathToZipExe =  $xmlinput.configuration.farm.zipFolder + "\7z.exe";
	$aZipfile = $OutPutName
    $arguments = @("a", "-tzip", "$aZipfile", "$aDirectory")
	# $arguments
	Write-Host -ForegroundColor White " - 7Zip de $aDirectory dans $OutPutName ..."
	
    & $pathToZipExe $arguments
}


#Sauvegarde des sites ayant le tag <site ....
function BackupSites(){
	#Go through each site-configuration in the file
	$backupmethod  =  $xmlinput.configuration.farm.backupMethod
	Write-Host -ForegroundColor Yellow " - Début de la sauvegarde des collections de sites. Method $backupmethod"
	
	$nodelist = $xmlinput.configuration.backup
	
	foreach ($item in $nodelist) {
	   #Read this site parameters
	   
	   $id = $item.name
	   $sitecollectionbackup = $item.sitecollectionbackup
	   $sitecollectionurl = $item.sitecollectionurl
	   $managedpath = $item.managedpath
	   
	   $backupdestination = $item.backupdestination
	   $backupdestinationmaxkeepdays = $item.backupdestinationmaxkeepdays
	   $zipbackup = $item.zipbackup
	   
	   $backupfilename = $id
	    
	   #Print the configuration parameter-details
	   Write-Host -ForegroundColor White " - Sauvegarde du site $id"

	   #  ---
	   #  --- Delete old files from backupdestination if backupdestinationmaxkeepdays<>0 ---
	   #  ---
	   If ([string]::Compare($backupdestinationmaxkeepdays, "0", $True)) 
	   {
		  #Perform deletion if backup destination path is valid
		  if(test-path $backupdestination)  
		  { 
			& dir $backupdestination |? {$_.CreationTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays) -and $_.name.StartsWith($backupfilename)} | del -force
			# & dir $backupdestination |? {$_.CreationTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays) -and $_.name.EndsWith('.bak')} | del -force
			Write-Host -ForegroundColor White "  - Fichiers plus vieux de $backupdestinationmaxkeepdays jours dans $backupdestination supprimés" 
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 Write-Host -ForegroundColor red "  - Erreur : Le chemin de sauvegarde $backupdestination n'existe pas pour le site $id"
		  }
	   }

	   #  ---
	   #  --- Do a site collection crawl and backup if sitecollectionbackup=1 ---
	   #  ---
	   If ([string]::Compare($sitecollectionbackup, "0", $True)) 
	   {
		  Write-Host -ForegroundColor White " - Démarrage de la sauvegarde de $sitecollectionurl"
			
		  #Perform backup if backup destination path is valid
		  if(test-path $backupdestination)  
		  { 
				# Backup de la collection de site principale
				$guid = (Get-Date -Format "yyyyMMdd-HHmmss")
				$backupfile = "$backupdestination\$backupfilename-$guid.bak"
				BackupASiteCollection $backupmethod $sitecollectionurl $backupfile

				If ([string]::Compare($zipbackup, "0", $True)) {
					if(test-path $backupfile){
						Create-7zip "$backupfile" "$backupfile.zip"
						Remove-item $backupfile
					}
				}

				#recupération des collections de site et backup si il existe des "managed paths" spécifiés "
				if ($managedpath){
					foreach ($mp in $managedpath.split(";")){
						$sites = GetSiteCollectionList $backupmethod $sitecollectionurl $mp

						foreach ($sitecourl in $sites){
							$s = Split-Path $sitecourl -Leaf
							$guid = (Get-Date -Format "yyyyMMdd-HHmmss")
							$backupfile = "$backupdestination\$backupfilename-$mp-$s-$guid.bak"
							BackupASiteCollection $backupmethod $sitecourl $backupfile

							# Zip du backup si demandé
							If ([string]::Compare($zipbackup, "0", $True)) {
								if(test-path $backupfile){
									Create-7zip "$backupfile" "$backupfile.zip"
									Remove-item $backupfile
								}
							}
						}
					}
				}
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 Write-Host -ForegroundColor red "  - Erreur: Le dossier $backupdestination n'existe pas pour le site $id"
			 $script:MailInfos += ,("ERREUR","Le dossier $backupdestination n'existe pas pour le site $id.")
		  }
	   }
	   else
	   {
			Write-Host -ForegroundColor red "   - Pas de backup de la collection de site $sitecollectionurl"
	   }
	}
}

function GetSiteCollectionList ($backupmethod,$sitecol,$managedpath){
	
	$a=@()
	# $a+=$sitecol
	
	try{

		if ($managedpath -eq "/"){
			$a+=$sitecol
		}
		else{
			LoadPowershellForSharepoint
			$SPSiteFilter =$sitecol+$managedpath
			Write-Host -ForegroundColor Yellow " - récupération des collections de site de $SPSiteFilter"
			$Allsites = Get-SPWebApplication $sitecol | Get-SPSite -Limit ALL | Select URL

			foreach ($spsite in $Allsites){
				$u = $spsite.Url
				if (($u.StartsWith($SPSiteFilter)) -and ($u -ne $sitecol)){
					# Write-Host -ForegroundColor Yellow " - ajout de $u"
					$a+=$u
				}
			}

		}
		
		$script:MailInfos += ,("INFO","récuperation des collections de site de $sitecol")
	}
	catch{
		$global:jobstatus	= "Echec"
		$script:MailInfos += , ("ERREUR","Erreur lors de la récuperation des  $sitecollectionurl")
		$script:MailInfos += , ("DESCRIPTION","$_")
		Write-Host -ForegroundColor red  " $_"
	}
		
	return $a

}

function BackupASiteCollection($backupmethod,$sitecollectionurl,$backupfile){
		if ($backupmethod -eq "hive"){
			& $ghive\BIN\stsadm.exe -o backup -url $sitecollectionurl -filename $backupfile -overwrite
			Write-Host -ForegroundColor White "  - Sauvegarde du site $sitecollectionurl via stsadm terminé." 
		}
		else{
			LoadPowershellForSharepoint
			try{
				Backup-SPSite $sitecollectionurl -Path $backupfile -force -ea Stop
				Write-Host -ForegroundColor green "  - Sauvegarde de $sitecollectionurl dans $backupfile via powershell terminé."
				$script:MailInfos += ,("INFO","Sauvegarde du site $sitecollectionurl dans $backupfile terminé.")
			}
			catch{
				$global:jobstatus	= "Echec"
				$script:MailInfos += , ("ERREUR","Erreur lors de la sauvegarde de $sitecollectionurl")
				$script:MailInfos += , ("DESCRIPTION","$_")
				Write-Host -ForegroundColor red  " $_"
			}
		}
}

function RestoreSites{
	Write-Host -ForegroundColor Yellow " - Début de la restauration des sites... "
	
	$nodelist = $xmlinput.configuration.restore
	
	foreach ($item in $nodelist) {
	   #Read this site parameters
	   
	   $id = $item.name
	   $sitecollectionrestore = $item.sitecollectionrestore
	   $sitecollectionurl 	 = $item.sitecollectionurl   
	   $sitecollectionadmins 	 = $item.administrators   

	   $backupfile = $item.backupsource
	   $backupfile = $backupfile.replace("{dp0}",$dp0)

	   #Print the configuration parameter-details
	   # Write-Host -ForegroundColor White " - Restauration du site $id"
	  
	   #  ---
	   #  --- Do a site collection crawl and backup if sitecollectionbackup=1 ---
	   #  ---
	   If ([string]::Compare($sitecollectionrestore, "0", $True)) 
	   {
		  Write-Host -ForegroundColor White "  - Démarrage de la restauration de $backupfile dans $sitecollectionurl  "
			
		  #Perform backup if backup destination path is valid
		  if(test-path $backupfile)  
		  { 
			
			if ($backupmethod -eq "hive"){
				Write-Host -ForegroundColor red "  - methode non implémentée !!!!!."
			}
			else{
				
				Try{
					LoadPowershellForSharepoint
					Restore-SPSite $sitecollectionurl -Path $backupfile -force -ea Stop
					Write-Host -ForegroundColor green "  - Restauration du site via powershell terminé."
							
					$tabadmins = $sitecollectionadmins.split(";")
					
					foreach ($scadmin in $tabadmins) {
						Set-SPSite -Identity $sitecollectionurl -SecondaryOwnerAlias $scadmin
						Write-Host -ForegroundColor white "  - Affectation de l'administrateur de collection de site $scadmin."
					}
					$script:MailInfos += , ("INFO","Restauration du site $sitecollectionurl terminé.")
				}
				Catch{
					$global:jobstatus	= "Echec"
					Write-Host -ForegroundColor red  " $_"
					$script:MailInfos += ,("ERREUR","Erreur de restauration du site $sitecollectionurl")
					$script:MailInfos += ,("DESCRIPTION","$_")
				}

			}
			
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 Write-Host -ForegroundColor red "  - Erreur: Le fichier $backupfile n'existe pas pour restaurer le site $id"
			 $script:MailInfos += ,("ERREUR","Le fichier $backupfile n'existe pas pour restaurer le site $id")
		  }
	   }
	   else
	   {
			Write-Host -ForegroundColor red "   - Pas de restauration de la collection de site $sitecollectionurl"
	   }

	  
	}
}

function FullBackup{
		$backupmethod  =  $xmlinput.configuration.farm.backupMethod
	
	   $catastrophicbackup = $xmlinput.configuration.full.catastrophicbackup
	   $catastrophicmethod = $xmlinput.configuration.full.catastrophicmethod
	   $backupdestination = $xmlinput.configuration.full.backupdestination
	   $backupdestinationmaxkeepdays = $xmlinput.configuration.full.backupdestinationmaxkeepdays
	   $BackupName	= $item.name
	   
	   #  --- Do a farm backup if backupdestination exists ---
	   If (![string]::IsNullOrEmpty($backupdestination)){
		   If ([string]::Compare($catastrophicbackup, "0", $True)) 
		   {
			  Write-Host -ForegroundColor yellow " - Début de la sauvegarde complète. Method $backupmethod Destination $backupdestination"
			  
			  #Perform backup if backup destination path is valid
			  if(Test-Path $backupdestination)  
			  { 
				#added by TBUISSON - Remove directory content before backup
				#Find all directories starting with spbr* then delete it recursively
				Write-Host -ForegroundColor White "  - Suppression des dossiers commencant par spbr* dans $backupdestination\"
				get-childitem $backupdestination"\" -include spbr* -recurse -force | Where-Object { $_.PSIsContainer } | Where-Object { $_.LastWriteTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays)} | Remove-Item -Force –Recurse
				
				Write-Host -ForegroundColor White "  - Lancement de la sauvegarde de ferme complète $catastrophicmethod dans $backupdestination\"
				if ($backupmethod -eq "hive"){			
					Try{
						& $ghive\BIN\stsadm.exe -o backup -directory $backupdestination"\" -backupmethod $catastrophicmethod -overwrite > $null
						Write-Host -ForegroundColor White "  - Sauvegarde de ferme stsadm effectué ! Dossier de destination $backupdestination\"
					}
					Catch{
						Write-Host -ForegroundColor Red " &_"
					}
				}
				else{
					Try{
						LoadPowershellForSharepoint
						
						Backup-SPFarm -Directory $backupdestination"\" -BackupMethod $catastrophicmethod -ea Stop
						Write-Host -ForegroundColor White "  - Sauvegarde de ferme powershell effectué ! Dossier de destination $backupdestination\"
						$script:MailInfos += , ("INFO","Backup complet de la ferme terminé.")
					}
					catch{
						$global:jobstatus	= "Echec"
						$script:MailInfos += , ("ERREUR","Erreur lors de la sauvegarde complète")
						$script:MailInfos += , ("DESCRIPTION","$_")
						Write-Host -ForegroundColor red  " $_"
					}
				}
				
			  }  
			  else 
			  {  
				 $global:jobstatus="Erreur"
				 Write-Host -ForegroundColor Red " - Erreur : Le dossier de sauvegarde $backupdestination n'existe pas"
			  }
	   }
	}
}

function LoadPowershellForSharepoint
{
	# if ((Get-PSSnapin -Name Microsoft.Sharepoint.Powershell -ErreurAction SilentlyContinue) -eq $null ){
		 # Add-PsSnapin Microsoft.Sharepoint.Powershell 
	# }
	$ver = $host | select version
	if ($ver.Version.Major -gt 1) {$host.Runspace.ThreadOptions = "ReuseThread"} 
	if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null) 
	{
		Add-PSSnapin "Microsoft.SharePoint.PowerShell"
	}
}
#Backup folders
function BackupFolders(){
	$nodelist = $xmlinput.configuration.folder
	$nbr = $nodelist.length
	
	Write-Host -ForegroundColor Yellow " - Début de la sauvegarde de(s) $nbr dossier(s) "
	
	foreach ($item in $nodelist) {
	   #Read this folder parameters
	   $id 					= $item.name
	   $path 				= $item.path
	   $backupdestination 	= $item.backupdestination
	   $backupdestinationmaxkeepdays = $item.backupdestinationmaxkeepdays
	   
	   $backupfilename = $id
	   $guid = "-" + (Get-Date -Format "yyyyMMdd-HHmmss")
	   
	   #Full backup file name
	   $fullfilename = $backupfilename+"-folder"+$guid+".zip"
	   
	   Write-Host -ForegroundColor white "  - Chargement de $id"
	   # $item
			   
	   #  --- Delete old files from backupdestination if backupdestinationmaxkeepdays<>0 ---
	   If ([string]::Compare($backupdestinationmaxkeepdays, "0", $True)) 
	   {
		  #Perform deletion if backup destination path is valid
		  if(test-path $backupdestination)  
		  { 
			& dir $backupdestination |? {$_.CreationTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays) -and $_.name.StartsWith($backupfilename)} | del -force
			Write-Host -ForegroundColor white "   - Fichiers plus vieux de $backupdestinationmaxkeepdays jours supprimés"
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 Write-Host -ForegroundColor red "   - Erreur : Le dossier de backup $backupdestination n'existe pas pour le dossier $id"
		  }
	   }
	
		#  --- Do a folder backup ---
		Write-Host -ForegroundColor white "   - Début de sauvegarde du dossier $path dans $backupdestination\$fullfilename"
		if(test-path $backupdestination)  
		{ 
			if(test-path $path)  
			{ 
				# gi $path | out-zip $backupdestination"\"$fullfilename $_ 
				Write-Host -ForegroundColor green "   - Sauvegarde terminée !" 
				$dest = "$backupdestination\$fullfilename"
				Create-7zip $path $dest
				
				$script:MailInfos += , ("INFO","Sauvegarde du dossier $path terminé dans $dest")
			}  
			else 
			{  
				   $global:jobstatus="Erreur"
				   Write-Host -ForegroundColor red  "   - Erreur : The folder Path $path doesn't exists for folder $id"
			}
		}
		else 
		{  
			$global:jobstatus="Erreur"
			Write-Host -ForegroundColor red "   - Erreur : Le dossier de backup $backupdestination n'existe pas pour le dossier $id"
		}	  
   }
}

