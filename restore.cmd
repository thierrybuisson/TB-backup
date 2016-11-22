
::Script de lancement de TB-Backup

::Exemple de lancement :
powershell.exe -command "& .\TB-Backup.ps1 '.\TB-backup-ER-CERIB-DEV.xml' 'restore'"

::Exemple de lancement, dans ce cas le fichier de configuration par défaut est TB-Backup.xml:
:: powershell.exe -command "& .\TB-Backup.ps1"

::Commentez la ligne suivante si vous lancez en tache planifiée
::pause