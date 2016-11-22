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
	
	if (![string]::IsNullOrEmpty($smtpserver))
	{
		Try{
			# Write-Host -ForegroundColor gray "$suj  "
			# Write-Host -ForegroundColor gray "$htmlBody "
			
			LogWrite -message "Envoie du rapport par email de $fromemail à $toemail Statut $status" -nonewline $true
	
			Send-MailMessage -To $toAddress -SmtpServer $smtpserver -subject $suj -From $fromemail -Body $htmlBody -BodyAsHtml -Encoding $encodingMail -Attachments $script:LogFile
			LogWrite -message  "Réussi" -severity 4
		}
		Catch{
			$global:jobstatus	= "Echec"
			LogWrite -severity 3 -message " echec !"
			LogWrite -severity 3 -message " $_"
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
		LogWrite -message "Windows Server 2008 ou Vista detecté"
	}

	If ($QueryOS.contains("2003"))
	{
		LogWrite -message "Windows Server 2003 detecté"
	}
}

# Method de zip via l'outil en ligne de command 7zip
function Create-7zip([String] $aDirectory, [String] $OutPutName){
    $pathToZipExe =  $xmlinput.configuration.farm.zipFolder + "\7z.exe";
	$aZipfile = $OutPutName
    $arguments = @("a", "-tzip", "$aZipfile", "$aDirectory")
	# $arguments
	LogWrite -message "7Zip de $aDirectory dans $OutPutName ..." -severity 5
	
    & $pathToZipExe $arguments
}


#Sauvegarde des sites ayant le tag <site ....
function BackupSites(){
	#Go through each site-configuration in the file
	$backupmethod  =  $xmlinput.configuration.farm.backupMethod
	LogWrite -severity 2 -message "Début de la sauvegarde des collections de sites. Method $backupmethod"
	
	$nodelist = $xmlinput.configuration.backup
	
	foreach ($item in $nodelist) {
	   #Read this site parameters
	   
	   $id = $item.name
	   $sitecollectionbackup = $item.sitecollectionbackup
	   $sitecollectionurl = $item.sitecollectionurl
	   $managedpath = $item.managedpath
	   
	   $backupdestination = $item.backupdestination.replace("{dp0}",$dp0)
	   $backupdestinationmaxkeepdays = $item.backupdestinationmaxkeepdays
	   $zipbackup = $item.zipbackup
	   
	   $backupfilename = $id
	    
	   #Print the configuration parameter-details
	   LogWrite -message "Sauvegarde du site name=""$id"" "

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
			LogWrite -message "Fichiers plus vieux de $backupdestinationmaxkeepdays jours dans $backupdestination supprimés" 
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 LogWrite -message "Erreur : Le chemin de sauvegarde $backupdestination n'existe pas pour le site $id" -severity 3
		  }
	   }

	   #  ---
	   #  --- Do a site collection crawl and backup if sitecollectionbackup=1 ---
	   #  ---
	   If ([string]::Compare($sitecollectionbackup, "0", $True)) 
	   {
		  LogWrite -message "Démarrage de la sauvegarde de $sitecollectionurl"
			
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
			 LogWrite -severity 3 -message "Erreur: Le dossier $backupdestination n'existe pas pour le site $id"
			 $script:MailInfos += ,("ERREUR","Le dossier $backupdestination n'existe pas pour le site $id.")
		  }
	   }
	   else
	   {
			LogWrite -severity 3 -message "Pas de backup de la collection de site $sitecollectionurl"
	   }
	}
}

# recupère la liste des collections de site en fonction d'un managed path
function GetSiteCollectionList ($backupmethod,$sitecol,$managedpath){
	
	$a=@()
	try{

		if ($managedpath -eq "/"){
			$a+=$sitecol
		}
		else{
			LoadPowershellForSharepoint
			$SPSiteFilter =$sitecol+$managedpath
			LogWrite -severity 2 -message "récupération des collections de site de $SPSiteFilter"
			$Allsites = Get-SPWebApplication $sitecol | Get-SPSite -Limit ALL | Select URL

			foreach ($spsite in $Allsites){
				$u = $spsite.Url
				if (($u.StartsWith($SPSiteFilter)) -and ($u -ne $sitecol)){
					# LogWrite -severity 4 -message "ajout de $u"
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
		LogWrite -severity 3 -message "$_"
	}
		
	return $a

}

function BackupASiteCollection($backupmethod, $sitecollectionurl, $backupfile){
		if ($backupmethod -eq "hive"){
			& $ghive\BIN\stsadm.exe -o backup -url $sitecollectionurl -filename $backupfile -overwrite
			LogWrite -message "Sauvegarde du site $sitecollectionurl via stsadm terminé." -severity 4 
		}
		else{
			LoadPowershellForSharepoint
			try{
				LogWrite -message "début de Sauvegarde de $sitecollectionurl dans $backupfile via powershell" -severity 4
				Backup-SPSite $sitecollectionurl -Path $backupfile -force -ea Stop
				LogWrite -message "Sauvegarde de $sitecollectionurl dans $backupfile via powershell terminé." -severity 4
				$script:MailInfos += ,("INFO","Sauvegarde du site $sitecollectionurl dans $backupfile terminé.")
			}
			catch{
				$global:jobstatus	= "Echec"
				$script:MailInfos += , ("ERREUR","Erreur lors de la sauvegarde de $sitecollectionurl")
				$script:MailInfos += , ("DESCRIPTION","$_")
				LogWrite -severity 3 -message " $_"
			}
		}
}

function RestoreSites{
	LogWrite -severity 3 -message "Début de la restauration des sites... "
	
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
	   # LogWrite -message "Restauration du site $id"
	  
	   #  ---
	   #  --- Do a site collection crawl and backup if sitecollectionbackup=1 ---
	   #  ---
	   If ([string]::Compare($sitecollectionrestore, "0", $True)) 
	   {
		  LogWrite -message "Démarrage de la restauration de $backupfile dans $sitecollectionurl  "
			
		  #Perform backup if backup destination path is valid
		  if(test-path $backupfile)  
		  { 
			
			if ($backupmethod -eq "hive"){
				LogWrite -severity 3 -message "methode non implémentée !!!!!."
			}
			else{
				
				Try{
					LoadPowershellForSharepoint
					Restore-SPSite $sitecollectionurl -Path $backupfile -force -ea Stop
					LogWrite -severity 4 -message "Restauration du site via powershell terminé." 
							
					$tabadmins = $sitecollectionadmins.split(";")
					
					foreach ($scadmin in $tabadmins) {
						Set-SPSite -Identity $sitecollectionurl -SecondaryOwnerAlias $scadmin
						LogWrite -message "Affectation de l'administrateur de collection de site $scadmin."
					}
					$script:MailInfos += , ("INFO","Restauration du site $sitecollectionurl terminé.")
				}
				Catch{
					$global:jobstatus	= "Echec"
					LogWrite -severity 3 -message " $_"
					$script:MailInfos += ,("ERREUR","Erreur de restauration du site $sitecollectionurl")
					$script:MailInfos += ,("DESCRIPTION","$_")
				}

			}
			
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 LogWrite -severity 3 -message "Erreur: Le fichier $backupfile n'existe pas pour restaurer le site $id"
			 $script:MailInfos += ,("ERREUR","Le fichier $backupfile n'existe pas pour restaurer le site $id")
		  }
	   }
	   else
	   {
			LogWrite -severity 3 -message "Pas de restauration de la collection de site $sitecollectionurl"
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
			  LogWrite -severity 3 -message "Début de la sauvegarde complète. Method $backupmethod Destination $backupdestination"
			  
			  #Perform backup if backup destination path is valid
			  if(Test-Path $backupdestination)  
			  { 
				#added by TBUISSON - Remove directory content before backup
				#Find all directories starting with spbr* then delete it recursively
				LogWrite -message "Suppression des dossiers commencant par spbr* dans $backupdestination\"
				get-childitem $backupdestination"\" -include spbr* -recurse -force | Where-Object { $_.PSIsContainer } | Where-Object { $_.LastWriteTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays)} | Remove-Item -Force –Recurse
				
				LogWrite -message "Lancement de la sauvegarde de ferme complète $catastrophicmethod dans $backupdestination\"
				if ($backupmethod -eq "hive"){			
					Try{
						& $ghive\BIN\stsadm.exe -o backup -directory $backupdestination"\" -backupmethod $catastrophicmethod -overwrite > $null
						LogWrite -message "Sauvegarde de ferme stsadm effectué ! Dossier de destination $backupdestination\"
					}
					Catch{
						LogWrite -severity 3 -message " &_"
					}
				}
				else{
					Try{
						LoadPowershellForSharepoint
						
						Backup-SPFarm -Directory $backupdestination"\" -BackupMethod $catastrophicmethod -ea Stop
						LogWrite -message "Sauvegarde de ferme powershell effectué ! Dossier de destination $backupdestination\"
						$script:MailInfos += , ("INFO","Backup complet de la ferme terminé.")
					}
					catch{
						$global:jobstatus	= "Echec"
						$script:MailInfos += , ("ERREUR","Erreur lors de la sauvegarde complète")
						$script:MailInfos += , ("DESCRIPTION","$_")
						LogWrite -severity 3 -message " $_"
					}
				}
				
			  }  
			  else 
			  {  
				 $global:jobstatus="Erreur"
				 LogWrite -severity 3 -message "Erreur : Le dossier de sauvegarde $backupdestination n'existe pas"
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
	
	LogWrite -severity 3 -message "Début de la sauvegarde de(s) $nbr dossier(s) "
	
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
	   
	   LogWrite -message "Chargement de $id"
	   # $item
			   
	   #  --- Delete old files from backupdestination if backupdestinationmaxkeepdays<>0 ---
	   If ([string]::Compare($backupdestinationmaxkeepdays, "0", $True)) 
	   {
		  #Perform deletion if backup destination path is valid
		  if(test-path $backupdestination)  
		  { 
			& dir $backupdestination |? {$_.CreationTime -lt (get-date).AddDays(-$backupdestinationmaxkeepdays) -and $_.name.StartsWith($backupfilename)} | del -force
			LogWrite -message "Fichiers plus vieux de $backupdestinationmaxkeepdays jours supprimés"
		  }  
		  else 
		  {  
			 $global:jobstatus="Erreur"
			 LogWrite -severity 3 -message "Erreur : Le dossier de backup $backupdestination n'existe pas pour le dossier $id"
		  }
	   }
	
		#  --- Do a folder backup ---
		LogWrite -message "Début de sauvegarde du dossier $path dans $backupdestination\$fullfilename"
		if(test-path $backupdestination)  
		{ 
			if(test-path $path)  
			{ 
				# gi $path | out-zip $backupdestination"\"$fullfilename $_ 
				LogWrite -severity 4 -message " Sauvegarde terminée !" 
				$dest = "$backupdestination\$fullfilename"
				Create-7zip $path $dest
				
				$script:MailInfos += , ("INFO","Sauvegarde du dossier $path terminé dans $dest")
			}  
			else 
			{  
				   $global:jobstatus="Erreur"
				   LogWrite -severity 3 -message "Erreur : The folder Path $path doesn't exists for folder $id"
			}
		}
		else 
		{  
			$global:jobstatus="Erreur"
			LogWrite -severity 3 -message "Erreur : Le dossier de backup $backupdestination n'existe pas pour le dossier $id"
		}	  
   }
}

