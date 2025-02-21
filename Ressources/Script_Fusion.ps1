# -----------------------------------------------------------
# Script : AllInOne-FusionInventory.ps1
# -----------------------------------------------------------

# 1) Afficher le texte d'introduction
$intro = @"
===============================================================================================================

Bonjour,

Nous nous apprêtons à collecter les caractéristiques de votre poste : âge, état de la mémoire, logiciels installés, etc. 
Les données seront intégrées à l’inventaire de votre structure. Elles ne seront accessibles qu’aux personnes dûment habilitées.

L’opération dure entre 2 et 5 minutes, et les données sont envoyées de manière sécurisée à un serveur en France. 
À la fin de notre opération, nous désinstallons tous nos outils et ne laissons aucune trace sur votre poste ; 
vous pourrez donc continuer à travailler normalement. Pour toute information, notre technicien est à votre service. 
Vous pouvez aussi nous contacter à support@rezosocial.org ou par téléphone au 01.85.08.31.25.

IMPORTANT : Aucune donnée confidentielle (documents Word, Excel, PDF, etc.) ne fait l’objet de notre inventaire.

En appuyant sur ENTRÉE, vous nous donnez votre accord pour mener à bien cette opération d’inventaire.

Merci pour le temps que vous nous accordez.

L’équipe support de RézoSocial

===============================================================================================================
"@

# Affichage de l'intro
Write-Host $intro

# Demande de confirmation
Write-Host "`nAppuyez sur ENTREE pour continuer..." -ForegroundColor Yellow
[void][System.Console]::ReadLine()

# 2) Proposer de changer le TAG si nécessaire en modifiant le config.ini
$rootPath = Split-Path -Parent $PSScriptRoot
$iniPath = "$rootPath\config.ini"

# Fonction pour lire un fichier INI
function Get-IniContent {
    param (
        [string]$filePath
    )
    $ini = @{}
    switch -regex -file $filePath {
        "^\[(.+)\]$" { 
            $section = $matches[1]
            $ini[$section] = @{}
        }
        "^(.*?)\s*=\s*(.*)$" { 
            if ($section) {
                $ini[$section][$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    return $ini
}

# Fonction pour écrire dans le fichier INI
function Set-IniValue {
    param (
        [string]$filePath,
        [string]$section,
        [string]$key,
        [string]$newValue
    )

    $content = Get-Content -Path $filePath

    # Modifier la ligne correspondant à la clé dans la bonne section
    $insideSection = $false
    for ($i = 0; $i -lt $content.Length; $i++) {
        if ($content[$i] -match "^\[$section\]$") {
            $insideSection = $true
        }
        elseif ($insideSection -and $content[$i] -match "^\[.*\]$") {
            $insideSection = $false
        }
        elseif ($insideSection -and $content[$i] -match "^\s*$key\s*=") {
            $content[$i] = "$key = $newValue"
            break
        }
    }

    # Sauvegarder les modifications
    $content | Set-Content -Path $filePath -Encoding UTF8
}

# Lecture du fichier INI
$config = Get-IniContent -filePath $iniPath
$tagValue = $config['CONFIG']['TAG']

# Afficher la valeur actuelle du TAG en jaune
Write-Host "La valeur actuelle du TAG est : " -NoNewline
Write-Host "$tagValue" -ForegroundColor Yellow

# Proposer une modification
$tagNewValue = Read-Host "Entrez un nouveau TAG (laisser vide pour conserver la valeur actuelle)"

# Mise à jour du config.ini et affichage de la confirmation en vert
if (-not [string]::IsNullOrWhiteSpace($tagNewValue)) {
    Set-IniValue -filePath $iniPath -section "CONFIG" -key "TAG" -newValue $tagNewValue
    Write-Host "TAG mis à jour." -ForegroundColor Green
	Write-Host ""
    $tagValue = $tagNewValue  
}

# 3) QOL lors du démarrage
# S'assurer que le QuickEdit n'est pas activé sur cmd pour les PC anciens pour éviter la mise en pause par erreur
$regPath = "HKCU:\Console"
$quickEditValue = "QuickEdit"
$quickEdit = (Get-ItemProperty -Path $regPath -Name $quickEditValue -ErrorAction SilentlyContinue).QuickEdit

# Si la valeur n'est pas 0, la modifier et redémarrer le script
if ($quickEdit -ne 0) {
    Write-Host "Quick Edit Mode est activé. Désactivation en cours..." -ForegroundColor Yellow

    # Désactiver Quick Edit Mode définitivement
    Set-ItemProperty -Path $regPath -Name $quickEditValue -Value 0

    # Fermer toutes les instances CMD
    Stop-Process -Name cmd -Force -ErrorAction SilentlyContinue

    # Relancer immédiatement le script
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WindowStyle Normal

    # Quitter l'instance actuelle pour éviter de continuer
    exit
}

# Bibliothèque Windows (user32.dll) pour manipuler les fenêtres de l'interface
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
        public const uint SWP_NOSIZE = 0x0001;
        public const uint SWP_NOMOVE = 0x0002;
        public const uint SWP_SHOWWINDOW = 0x0040;
		[DllImport("user32.dll")]
		public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
		
    }
"@

# Récupérer le handle de la fenêtre PowerShell et la mettre en premier plan
$hWnd = [Win32]::GetForegroundWindow()

# 4) Affectation des variables pour le reste du script
$myHome       = "$env:USERPROFILE\Desktop\"
$myURL        = $config['CONFIG']['REMOTE_SERVER']						# URL du serveur, modifiable dans le config.ini
$myInstallDir = 'FusionInventory-NoAgent'  								# Dossier où FusionInventory est installé
$myLocalDir   = 'FusionInventory-NoAgent' 								# Dossier où le fichier d'inventaire .ocs est sauvegardé
$myTAG        = $tagValue												# TAG FusionInventory, modifiable dans le config.ini ou lors du démarrage du script
$logFile      = "$myHome$myInstallDir\logs\fusioninventory-agent.log"	# Chemin d'accès du fichier de log généré lors de l'inventaire
$errorMsg     = "communication error: 500"								# Message récupéré dans le log qui indique que le serveur n'est pas joignable
$receivingMsg = "[http client] receiving"								# Message récupéré dans le log qui indique que le serveur répond bien
$deployMsg    = "Doing Deploy Maintenance"								# Message récupéré dans le log qui indique la fin de l'inventaire
	
# Variables pour l'animation du spinner et du timer
$timeout       = 360  # Temps maximum d'attente (en secondes)
$elapsed       = 0
$foundError    = $false
$foundReceiving= $false
$foundDeploy   = $false
$spinnerChars  = @('|', '/', '-', '\')
$spinnerIndex  = 0
$windowBroughtToFront = $false  # Drapeau pour éviter de répéter l'actions

# 5) Commande d'installation de FusionInventory
$HereString = @"
ressources\fusioninventory-agent_windows-x64_2.6.exe
/acceptlicense
/server='$myURL'
/tag=$myTAG
/installtasks=Full
/S
/installdir="$myHome$myInstallDir"
/execmode=Portable
/local="$myHome$myLocalDir"
/debug=2
"@

# Remplacer les retours à la ligne par un espace
$FusionInventoryCmd = $HereString -replace "(\r?\n)+", " "

# Exécuter l'installation en CMD et attendre la fin
Write-Host ""
Write-Host "Lancement de l'installation de FusionInventory." -ForegroundColor Green

# Démarrer le processus d'installation en arrière-plan
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $FusionInventoryCmd" -PassThru

# Attendre quelques instants pour s'assurer que `cmd.exe` s'affiche bien
Start-Sleep -Seconds 1

while (!$process.HasExited) {
    Start-Sleep -Milliseconds 1000  # Attendre un peu entre les mises à jour
    $elapsed++
    $spinnerChar = $spinnerChars[$spinnerIndex]
    $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Length

    # Vérifier si la fenêtre PowerShell est toujours au premier plan
    $currentForegroundWindow = [Win32]::GetForegroundWindow()

    if ($currentForegroundWindow -ne $hWnd) {
        [Win32]::ShowWindowAsync($hWnd, 5) | Out-Null  # Restaurer si elle a été minimisée
        [Win32]::SetForegroundWindow($hWnd) | Out-Null  # Remettre la fenêtre devant
    }

    # Affichage dynamique du spinner
    Write-Host -NoNewline "`rInstallation en cours vers $myHome$myInstallDir... $spinnerChar [$elapsed s]"
}

Write-Host ""
Write-Host "`nInstallation terminée." -ForegroundColor Green

# Supprimer les anciens logs pour éviter de parasiter le script
$logsPath = "$myHome$myInstallDir\logs"

if (Test-Path $logsPath) {
#    Write-Host "Suppression des anciens logs..."
    Remove-Item -Path "$logsPath\*" -Force -Recurse
#    Write-Host "Logs supprimés."
} else {
#    Write-Host "Aucun dossier logs à supprimer."
}

# 6) Lancer l'agent d'inventaire
$agentPath = "$myHome$myInstallDir\fusioninventory-agent.bat"

if (Test-Path $agentPath) {
    Write-Host "Lancement de l'inventaire..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$agentPath`"" -WindowStyle Hidden
} else {
    Write-Host "Erreur : Impossible de trouver le fichier d'agent FusionInventory : $agentPath" -ForegroundColor Red
    Pause
    exit
}

# 7) Vérifier l'envoi des données vers le serveur
Write-Host "Envoi de l'inventaire vers le serveur..."

# Boucle d'attente avec animation
while ($elapsed -lt $timeout -and -not ($foundError -or $foundReceiving -or $foundDeploy)) {
    Start-Sleep -Seconds 1
    $elapsed++
    $spinnerChar = $spinnerChars[$spinnerIndex]
    $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Length
    Write-Host -NoNewline "`rAttente de la réponse du serveur GLPI... $spinnerChar  [$elapsed s]"
    
    # Vérifier la présence des motifs dans le fichier log
    $foundError     = Select-String -Path $logFile -Pattern $errorMsg -SimpleMatch -ErrorAction SilentlyContinue
    $foundReceiving = Select-String -Path $logFile -Pattern $receivingMsg -SimpleMatch -ErrorAction SilentlyContinue
    $foundDeploy    = Select-String -Path $logFile -Pattern $deployMsg -SimpleMatch -ErrorAction SilentlyContinue
}
Write-Host ""

# Vérifier si le serveur a répondu avant de poursuivre
if ($foundReceiving) {
    Write-Host "`nLe serveur GLPI a répondu. Veuillez patienter le temps que l'inventaire se termine." -ForegroundColor Green

    while (-not ($foundDeploy -or $foundError)) {
        Start-Sleep -Seconds 1
        $elapsed++
        $spinnerChar = $spinnerChars[$spinnerIndex]
        $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Length

        # Affichage dynamique avec retour chariot `r pour éviter un affichage en cascade
        Write-Host -NoNewline "`rEn attente de la fin du traitement... $spinnerChar [$elapsed s]"

        # Re-vérifier si $foundDeploy ou $foundError deviennent true
        $foundDeploy = Select-String -Path $logFile -Pattern $deployMsg -SimpleMatch -ErrorAction SilentlyContinue
        $foundError  = Select-String -Path $logFile -Pattern $errorMsg -SimpleMatch -ErrorAction SilentlyContinue
    }
    Write-Host "" # Passe à la ligne après la boucle
}

# Une fois $foundDeploy ou $foundError détecté, afficher le message final
if ($foundError) {
    $message = "Le serveur GLPI est injoignable. Un fichier .OCS d'inventaire a été généré dans $myHome$myLocalDir\..."
    Write-Host "`n$message" -ForegroundColor Red
} elseif ($foundDeploy) {
    $message = "L'inventaire a bien été envoyé vers le serveur GLPI"
    Write-Host "`n$message" -ForegroundColor Green
}

# 8) Supprimer le dossier FusionInventory
Write-Host "----------------------------------------------------------------------"
Write-Host "Appuyez sur n'importe quelle touche pour désinstaller FusionInventory."
Write-Host "Sinon fermez la fenêtre manuellement."
Write-Host "----------------------------------------------------------------------"
Write-Host "En attente d'une touche..." -ForegroundColor Yellow

# Vider le buffer du clavier avant d'attendre une touche (important !)
while ([System.Console]::KeyAvailable) { [System.Console]::ReadKey($true) | Out-Null }

# Attendre qu'une touche soit pressée
[System.Console]::ReadKey($true) | Out-Null  # Capture la touche sans l'afficher

# Lancer la désinstallation
Write-Host "`nDésinstallation de FusionInventory en cours..."

# Désinstallation de FusionInventory (pas nécessaire en mode portable, mais je le laisse en cas de changement)
$UninstallCmd = '"' + "$myHome$myInstallDir\uninstall.exe" + '" /S'
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $UninstallCmd" -Wait

# Suppression du dossier après désinstallation
Remove-Item -Path "$myHome$myInstallDir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "FusionInventory a été désinstallé avec succès."