    $TargetFile = "powershell"
    $ShortcutFile = "C:\Users\$env:Username\Desktop\docker-docker.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.Arguments ="-noexit e:\docker\utils\environ.ps1 docker docker"
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
