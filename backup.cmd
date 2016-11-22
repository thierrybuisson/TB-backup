
::Script de lancement de TB-Backup
cd %~dp0

:: Lancement du script TB-backup
:: -configuration '<filename>' : nom du fichier de configuration dans le dossier courant
:: -action '<listeactions>' (liste séparée par des ;) : 
::      backup : lance le backup des collections de site
::      restore : lance la restauration des collections de site
::      full : backup de la ferme sharepoint
::      folder : zip de dossier
powershell.exe -command "& .\TB-Backup.ps1 -configuration '.\TB-backup-ER-CERIB-DEV.test.xml' -action 'folder'"

::Exemple de lancement, dans ce cas le fichier de configuration par défaut est TB-Backup.xml:
:: powershell.exe -command "& .\TB-Backup.ps1"

::Exemple de lancement, pour une action de backup complète (spbr000)
:: powershell.exe -command "& .\TB-Backup.ps1 -configuration '.\mamachine.xml' -action 'full'"
