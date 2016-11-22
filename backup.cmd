
::Script de lancement de TB-Backup
cd %~dp0

::Exemple de lancement :
powershell.exe -command "& .\TB-Backup.ps1 -configuration '.\TB-backup-ER-CERIB-DEV.test.xml' -action 'backup;folder'"

::Exemple de lancement, dans ce cas le fichier de configuration par défaut est TB-Backup.xml:
:: powershell.exe -command "& .\TB-Backup.ps1"

::Exemple de lancement, pour une action de backup complète (spbr000)
:: powershell.exe -command "& .\TB-Backup.ps1 -configuration '.\mamachine.xml' -action 'full'"
