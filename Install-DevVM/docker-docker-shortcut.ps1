    $TargetFile = "e:\docker\utils\environ.cmd"
    $ShortcutFile = "C:\Users\$env:Username\Desktop\docker-docker.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.Arguments ="docker docker"
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
