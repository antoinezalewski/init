function Get-RestartRequired {
    # Clé dans le registre qui indique si un redémarrage est nécessaire
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
    )

    $restartNeeded = $false

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $restartNeeded = $true
            break
        }
    }

    return $restartNeeded
}

$Global:needRestart = Get-RestartRequired

Clear-Host
Write-Host "### SCRIPT D'ADMINISTRATION WINDOWS SERVER ###`n              Antoine Zalewski`n" -ForegroundColor Magenta

function Test-IsAdmin { # Vérification du mode administrateur
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Host "`nErreur lors de la vérification du mode administrateur" -ForegroundColor Red
        Set-InitDisplay
    }
}

function Start-Sysprep {

    Clear-Host
    Write-Host "### SYSPREP ###" -ForegroundColor Magenta
    Write-Host "`nUn redémarrage sera nécessaire pour généraliser l'image" -ForegroundColor Yellow

    $choice = Set-ChoicePrompt
    switch ($choice) {
        "o" {
            Write-Host "`nRedémarrage" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
            C:\Windows\System32\Sysprep\Sysprep.exe /generalize /reboot /oobe
        }
        "n" {
            Write-Host "`nLa généralisation par SYSPREP n'a pas été effectuée" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
    
            Set-HomeDisplay
        }
    }
}

# Bureau à distance

function Set-InitDisplay { # Initialisation du script avec affichage info dynamique
    function Show-Progress {
        param (
            [string]$Message
        )
        Write-Host "$Message..." -NoNewline
        Start-Sleep -Milliseconds $(Get-Random -Minimum 200 -Maximum 700)
        Write-Host "[OK]" -ForegroundColor Green
    }
    
    function Get-ServerInformation {
        Show-Progress "Récupération du nom du serveur"
        $serverName = try {
            (Get-WmiObject Win32_ComputerSystem).Name
        }
        catch {
            "Unknown"
        }
    
        Show-Progress "Récupération de la version de Windows"
        $windowsVersion = try {
            (Get-WmiObject Win32_OperatingSystem).Caption
        }
        catch {
            "Unknown"
        }
    
        Show-Progress "Récupération de l'adresse IP"
        $ipAddress = try {
            (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -ne 'Loopback Pseudo-Interface 1' }).IPAddress
        }
        catch {
            "Unknown"
        }
    
        Show-Progress "Récupération de l'espace disque disponible"
        $disks = try {
            Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, @{Name="FreeSpaceGB";Expression={"{0:N1}" -f ($_.FreeSpace / 1GB)}}
        }
        catch {
            "Unknown"
        }

        Write-Host "`nCompilation des informations" -NoNewline -ForegroundColor Magenta
        Set-WaitingScreen -color Magenta
        Write-Host
    
        # Retourner les informations collectées sous forme d'objet
        return @{
            ServerName = $serverName
            WindowsVersion = $windowsVersion
            IPAddress = $ipAddress
            Disks = $disks
        }
    }
    
    function Show-ServerInformation {
        param (
            [hashtable]$ServerInfo
        )
    
        Clear-Host
        Write-Host "### Informations du serveur ###`n" -ForegroundColor Magenta
        Write-Host "Nom du serveur         : $($ServerInfo.ServerName)" -ForegroundColor Green
        Write-Host "Version de Windows     : $($ServerInfo.WindowsVersion)" -ForegroundColor Green
        Write-Host "Adresse IP             : $($ServerInfo.IPAddress)" -ForegroundColor Green
        Write-Host "`nEspaces Disques :" -ForegroundColor Green
    
        foreach ($disk in $ServerInfo.Disks) {
            Write-Host " - Disque $($disk.DeviceID) : $($disk.FreeSpaceGB) GB disponibles" -ForegroundColor Green
        }
        
        Read-Host "`n::  Le script est initialisé, appuyer sur ENTREE pour continuer  :"
        Set-HomeDisplay

    }

    $serverInfo = Get-ServerInformation
    Show-ServerInformation -ServerInfo $serverInfo
}

function Set-HomeDisplay { # Affichage du menu d'accueil avec les options disponibles
    Clear-Host
    Write-Host "### MENU ###`n" -ForegroundColor Magenta

    Write-Host "#1 - SYSPREP`n`n#2 - Renommer le serveur`n#3 - Configurer le réseau`n" -ForegroundColor Green
    
    if ($Global:needRestart) {
        Write-Host "#4 - Installer des rôles - EN DEV" -ForegroundColor Yellow
    } else {
        Write-Host "#4 - Installer des rôles - EN DEV" -ForegroundColor Green
    }

    Write-Host "#5 - Supprimer des rôles - EN DEV" -ForegroundColor Green
    # if ($Global:needRestart) {
    #     Write-Host "#5 - Supprimer des rôles" -ForegroundColor Yellow
    # } else {
    #     Write-Host "#5 - Supprimer des rôles" -ForegroundColor Green
    # }
    
    Write-Host "`n#0 - Sortir`n" -ForegroundColor Red
    $selectedOption = Read-Host "`nSélectionner une option "

    switch ($selectedOption) {
        1 {Start-Sysprep}
        2 {Set-ServerName}
        3 {Set-Network}
        <# 4 {
            if ($Global:needRestart) {
                Write-Host "Un redémarrage est en attente sur le serveur" -ForegroundColor Yellow
                $choice = Set-ChoicePrompt

                switch ($choice) {
                    "o" {
                        Write-Host "Redémarrage" -ForegroundColor Yellow -NoNewline
                        Set-WaitingScreen -color Yellow
                        Restart-Computer
                    }
                    "n" {
                        $Global:needRestart = $true
                        Write-Host "`nUn redémarrage est nécessaire avant d'installer des rôles sur le serveur" -ForegroundColor Yellow -NoNewline
                        Set-WaitingScreen -color Yellow
                
                        Set-HomeDisplay
                    }
                }
            } else {Install-Roles}
        } #>
        # 5 {
        #     if ($Global:needRestart) {
        #         Write-Host "Un redémarrage est en attente sur le serveur" -ForegroundColor Yellow
        #         $choice = Set-ChoicePrompt

        #         switch ($choice) {
        #             "o" {
        #                 Write-Host "Redémarrage" -ForegroundColor Yellow -NoNewline
        #                 Set-WaitingScreen -color Yellow
        #                 Restart-Computer
        #             }
        #             "n" {
        #                 $Global:needRestart = $true
        #                 Write-Host "`nUn redémarrage est nécessaire avant de supprimer des rôles sur le serveur" -ForegroundColor Yellow -NoNewline
        #                 Set-WaitingScreen -color Yellow
                
        #                 Set-HomeDisplay
        #             }
        #         }
        #     } else {Uninstall-Roles}
        # }
        <# 5 {Uninstall-Roles} #>
        0 {
            Write-Host "Bye ;)" -ForegroundColor Magenta
            Start-Sleep 2
            Clear-Host
            exit
        }
        Default {
            Write-Host "Cette option n'existe pas" -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
            Set-HomeDisplay
        }
    }
}

function Set-ServerName { # Module de configuration du nom du serveur

    Clear-Host
    Write-Host "### RENOMMER LE SERVEUR ###`n" -ForegroundColor Magenta
    $newServerName = Read-Host "Entrer le nouveau nom du serveur "

    if (!$newServerName) {
        Write-Host "`nLe nom du serveur ne peut pas être vide" -ForegroundColor Red -NoNewline
        Set-WaitingScreen -color Red
        Set-ServerName
    }

    try {
        Rename-Computer -NewName $newServerName -Force -WarningAction SilentlyContinue
    } catch {
        Write-Host "Erreur lors de la modification du nom du serveur" -ForegroundColor Red -NoNewline
        Set-WaitingScreen -color Red
        Set-HomeDisplay
    }

    Write-Host "Modification effectuée. Le système doit redémarrer" -ForegroundColor Green

    $choice = Set-ChoicePrompt

    switch ($choice) {
        "o" {
            Write-Host "Redémarrage" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
            Restart-Computer
        }
        "n" {
            $Global:needRestart = $true
            Write-Host "`nUn redémarrage est nécessaire pour appliquer les modifications" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
    
            Set-HomeDisplay
        }
    }
}

function Set-Network { # Module de configuration des cartes réseaux du serveur

    $networkAdapters = @()
    $adapterIndex = 0

    Clear-Host
    Write-Host "### Configurer le réseau ###`n" -ForegroundColor Magenta
    Write-Host "--- Interface    : $($interface.Name)`n--- Adresse IP   : $ip/$mask`n--- Gateway      : $gateway`n" -ForegroundColor Green

    if (!$interface) {

        try {
            $networkAdapters += Get-NetAdapter | Select-Object Name, InterfaceDescription
        }
        catch {
            Write-Host "Erreur lors de la récupération des interfaces" -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
            Set-HomeDisplay
        }
        
        foreach ($adapter in $networkAdapters) {
            Write-Host "#$adapterIndex - $($adapter.Name) - $($adapter.InterfaceDescription)"
            $adapterIndex++
        }

        Write-Host
        $selectedAdapter = Read-Host "Interface à modifier "

        if ($selectedAdapter -match '^\d+$' -and [int]$selectedAdapter -lt $networkAdapters.Count) {
            try {
                $interface = $networkAdapters[$selectedAdapter]
                $netAdapterIndex = (Get-NetAdapter $interface.Name).ifIndex
            }
            catch {
                Write-Host "Erreur lors de la récupération de l'interface" -ForegroundColor Red -NoNewline
                Set-WaitingScreen -color Red
                Set-HomeDisplay
            }
            
            Set-Network

        } else {
            Write-Host "Le numéro de l'interface n'existe pas ou n'est pas valide." -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
            Set-Network
        }
    }

    if (!$ip) {
        Write-Host
        $ipPrompt = Read-Host "Adresse IP du serveur "
        if ($ipPrompt -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
            $ip = $ipPrompt
        } else {
            Write-Host "Adresse IP invalide" -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
        }
        Set-Network
    }

    if (!$mask) {
        Write-Host
        $maskPrompt = Read-Host "Entrez un nombre entre 1 et 32"
        if ([int]$maskPrompt -ge 1 -and [int]$maskPrompt -le 32) {
            $mask = $maskPrompt
        } else {
            Write-Host "Masque invalide. Veuillez entrer un nombre entre 1 et 32" -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
        }
        Set-Network
    }

    if (!$gateway) {
        Write-Host
        $gatewayPrompt = Read-Host "Gateway du serveur "
        if ($gatewayPrompt -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
            $gateway = $gatewayPrompt
        } else {
            Write-Host "Adresse IP de la gateway invalide" -ForegroundColor Red -NoNewline
            Set-WaitingScreen -color Red
        }
        Set-Network
    }

    $choice = Set-ChoicePrompt -text "Les paramètres réseaux sont-ils exacts ? (o/n) "

    switch ($choice) {
        "o" {
            try {
                New-NetIPAddress -IPAddress $ip -PrefixLength $mask -InterfaceIndex ($netAdapterIndex) -DefaultGateway $gateway
                Write-Host "`nModifications réseaux effectuées" -ForegroundColor Green
            }
            catch {
                Write-Host "`nErreur lors de l'application des paramètres réseaux" -ForegroundColor Red -NoNewline
                Set-WaitingScreen -color Red
            }
            Set-HomeDisplay
        }
        "n" {
            $ip = $interface = $mask = $gateway = $null
            Write-Host "`nRéinitialisation des paramètres" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
            Set-Network
        }
    }
}

function Install-Roles {
    function Show-Menu {
        Clear-Host
        Write-Host "### Installation des rôles ###`n" -ForegroundColor Magenta
    
        # Boucle sur les rôles pour afficher l'état de sélection
        for ($i = 0; $i -lt $roles.Count; $i++) {
            $role = $roles[$i]
    
            if ($role.Selected) {
                Write-Host "#$($i + 1) - $($role.Name) (sélectionné)" -ForegroundColor Green
            } elseif ($role.Installed) {
                Write-Host "#$($i + 1) - $($role.Name) (déjà installé)" -ForegroundColor Yellow
            } else {
                Write-Host "#$($i + 1) - $($role.Name)"
            }
        }
        Write-Host "`n#4 - Terminer la sélection" -ForegroundColor Red
    }
    
    # Vérifier si un rôle est déjà installé
    function Get-Role {
        param ($roleName)
    
        # Utiliser Get-WindowsFeature pour vérifier si le rôle est installé
        $role = Get-WindowsFeature -Name $roleName
        return $role.Installed
    }

    function Set-RolesDiplay {

        $role = $roles[$choice - 1]
    
        if ($role.Installed) {
            Write-Host "$($role.Name) est déjà installé" -ForegroundColor Yellow
            Start-Sleep 1
        } elseif ($role.Selected) {
            $role.Selected = $false
        } else {
            $role.Selected = $true
        }
    }
    
    # Lancer le programme de configuration si nécessaire
    function Start-PostConfig {
        param ($role)

        switch ($role.Feature) {
            "DHCP" {
                Write-Host "Lancement de la configuration du DHCP Server..." -ForegroundColor Cyan
                Invoke-Command -ScriptBlock { Start-Process "dhcpmgmt.msc" }
            }
            "AD-Domain-Services" {
                Write-Host "Lancement de la configuration Active Directory..." -ForegroundColor Cyan
                Install-ADDSForest -DomainName "yourdomain.com"
            }
            # Ajouter d'autres rôles si nécessaire
            default {
                Write-Host "Aucune configuration supplémentaire requise pour $($role.Name)" -ForegroundColor Yellow
            }
        }
    }

    # Liste des rôles disponibles
    $roles = @(
        @{Name = "DHCP Server"; Feature = "DHCP"; Selected = $false; Installed = (Get-Role "DHCP")},
        @{Name = "DNS Server"; Feature = "DNS"; Selected = $false; Installed = (Get-Role "DNS")},
        @{Name = "Active Directory Domain Services"; Feature = "AD-Domain-Services"; Selected = $false; Installed = (Get-Role "AD-Domain-Services")}
    )
    
    do {
        Clear-Host
        Show-Menu
        $choice = Read-Host "`n`nSélectionnez un rôle (1-4)"
    
        switch ($choice) {
            1 {Set-RolesDiplay}
            2 {Set-RolesDiplay}
            3 {Set-RolesDiplay}
            4 {break}
            default {
                Write-Host "Option invalide. Veuillez entrer un numéro entre 1 et 4." -ForegroundColor Red
                Start-Sleep 2
            }
        }
    } while ($choice -ne 4)

    if (!$($roles | Where-Object { $_.Selected })) {
        Write-Host "`nAucun rôle n'a été installé" -NoNewline -ForegroundColor Yellow
        Set-WaitingScreen -color Yellow
        Set-HomeDisplay
    }
    
    Write-Host "`nInstallation des rôles sélectionnés..." -ForegroundColor Green
    
    # Installation des rôles sélectionnés
    foreach ($role in $roles | Where-Object { $_.Selected }) {
        Install-WindowsFeature -Name $role.Feature -IncludeManagementTools -WarningAction SilentlyContinue
        Start-PostConfig -role $role
    }
    
    Write-Host "`nInstallation et configuration terminées" -ForegroundColor Green
    Set-WaitingScreen -color Green
    Set-HomeDisplay
}

function Uninstall-Roles {
    function Show-RemoveMenu {
        Clear-Host
        Write-Host "### Suppression des rôles ###`n" -ForegroundColor Magenta
    
        # Boucle sur les rôles pour afficher l'état de suppression
        for ($i = 0; $i -lt $roles.Count; $i++) {
            $role = $roles[$i]
    
            if ($role.Selected) {
                Write-Host "#$($i + 1) - $($role.Name) (sélectionné pour suppression)" -ForegroundColor Red
            } elseif ($role.Installed) {
                Write-Host "#$($i + 1) - $($role.Name) (installé)" -ForegroundColor Green
            } else {
                Write-Host "#$($i + 1) - $($role.Name)"
            }
        }
        Write-Host "`n#4 - Terminer la sélection" -ForegroundColor Red
    }
    
    # Vérifier si un rôle est installé
    function Get-Role {
        param ($roleName)
    
        # Utiliser Get-WindowsFeature pour vérifier si le rôle est installé
        $role = Get-WindowsFeature -Name $roleName
        return $role.Installed
    }

    # Modifier l'état des rôles pour la suppression
    function Set-RolesDisplay {
    
        $role = $roles[$choice - 1]
    
        if (-not $role.Installed) {
            Write-Host "$($role.Name) n'est pas installé." -ForegroundColor Yellow
            Start-Sleep 1
        } elseif ($role.Selected) {
            $role.Selected = $false
        } else {
            $role.Selected = $true
        }
    }
    
    # Liste des rôles disponibles pour suppression
    $roles = @(
        @{Name = "DHCP Server"; Feature = "DHCP"; Selected = $false; Installed = (Get-Role "DHCP")},
        @{Name = "DNS Server"; Feature = "DNS"; Selected = $false; Installed = (Get-Role "DNS")},
        @{Name = "Active Directory Domain Services"; Feature = "AD-Domain-Services"; Selected = $false; Installed = (Get-Role "AD-Domain-Services")}
    )
    
    do {
        Clear-Host
        Show-RemoveMenu
        $choice = Read-Host "`n`nSélectionnez un rôle à supprimer (1-4)"
    
        switch ($choice) {
            1 {Set-RolesDisplay}
            2 {Set-RolesDisplay}
            3 {Set-RolesDisplay}
            4 {break}
            default {
                Write-Host "Option invalide. Veuillez entrer un numéro entre 1 et 4." -ForegroundColor Red
                Start-Sleep 2
            }
        }
    } while ($choice -ne 4)
    
    if (!$($roles | Where-Object { $_.Selected })) {
        Write-Host "`nAucun rôle n'a été désinstallé" -NoNewline -ForegroundColor Yellow
        Set-WaitingScreen -color Yellow
        Set-HomeDisplay
    }

    Write-Host "`nSuppression des rôles sélectionnés..." -ForegroundColor Green
    
    # Suppression des rôles sélectionnés avec leurs modules et outils de gestion
    foreach ($role in $roles | Where-Object { $_.Selected }) {
        Remove-WindowsFeature -Name $role.Feature -WarningAction SilentlyContinue
        Write-Host "$($role.Name) et ses modules associés ont été supprimés." -ForegroundColor Red
    }
    
    Write-Host "`nSuppression des rôles terminée" -ForegroundColor Green
    $choice = Set-ChoicePrompt

    switch ($choice) {
        "o" {
            Write-Host "Redémarrage" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
            Restart-Computer
        }
        "n" {
            $Global:needRestart = $true
            Write-Host "`nUn redémarrage est nécessaire pour appliquer les modifications" -ForegroundColor Yellow -NoNewline
            Set-WaitingScreen -color Yellow
    
            Set-HomeDisplay
        }
    }
}

function Set-ChoicePrompt { # Affichage d'un choix o/n
    param (
        [string]$text = "Voulez-vous redémarrer maintenant (o/n) "
    )

    Write-Host
    do {
        $x = Read-Host $text
        
        switch ($x) {
            "o" { return "o" }
            "n" { return "n" }
            Default {
                Write-Host "Sélectionner une option valide" -ForegroundColor Red
            }
        }
    } while ($true)
}

function Set-WaitingScreen { # Affichage d'un message dynamique d'attente
    param(
        [string]$color = "Grey"
    )
    for ($i = 0; $i -lt 3; $i++) {
        Write-Host "." -ForegroundColor $color -NoNewline
        Start-Sleep 0.7
    }
}

if (-not (Test-IsAdmin)) {
    Write-Host "Relancer le script en tant qu'administrateur`n" -ForegroundColor Yellow -NoNewline
    Start-Sleep 3
    exit
} else {
    Set-InitDisplay
}