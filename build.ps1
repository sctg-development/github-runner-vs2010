# Commentaires
# In Visual studio VS2010 x86 prompt
# %comspec% /k ""C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"" x86
param (
    [string[]]$configurations = @("Release", "Release Verbose", "Release No Hardware"),
    [string]$workspace = "C:\novasulf-ii",
    [bool]$dism = $true
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Output "Le script nécessite des privilèges d'administrateur. Relancez le script avec des privilèges élevés."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd $workspace ; .\build.ps1`"" -Verb RunAs
    exit
}

# Exécuter le script vcvarsall.bat dans cmd.exe et capturer les variables d'environnement
$vcvarsall = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
cmd /c " `"$vcvarsall`" x86 && set" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Vérifier que msbuild est disponible
if (-not (Get-Command msbuild -ErrorAction SilentlyContinue)) {
    Write-Error "msbuild n'est pas disponible. Assurez-vous que l'environnement Visual Studio est correctement configur�."
    exit 1
}

# Vérifier  que les variables d'environnement sont correctement configur�es et contiennent les valeurs suivantes:
#VCINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\
#VS100COMNTOOLS=C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\Tools\
#VSINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio 10.0\
#WindowsSdkDir=C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\
if (-not $env:VCINSTALLDIR -or -not $env:VS100COMNTOOLS -or -not $env:VSINSTALLDIR -or -not $env:WindowsSdkDir) {
    Write-Error "Les variables d'environnement Visual Studio ne sont pas correctement configurées."
    exit 1
}

if ( $env:VCINSTALLDIR -notlike "*10.0\VC*") {
    Write-Error "VCINSTALLDIR n'est pas correctement configuré."
    exit 1
}

if ( $env:VS100COMNTOOLS -notlike "*10.0\Common7\Tools\") {
    Write-Error "VS100COMNTOOLS n'est pas correctement configuré."
    exit 1
}

if ( $env:VSINSTALLDIR -notlike "*\Microsoft Visual Studio 10.0\") {
    Write-Error "VSINSTALLDIR n'est pas correctement configuré."
    exit 1
}

if ( $env:WindowsSdkDir -notlike "*\v7.0A\") {
    Write-Error "WindowsSdkDir n'est pas correctement configuré."
    exit 1
}

# Construire la solution avec différentes configurations
Write-Output "Build Solution pour les configurations: $configurations"

# Construire la solution avec différentes configurations
foreach ($config in $configurations) {
    Write-Output "Building $config"
    msbuild "$workspace\myapp_qt4.sln" /p:Configuration="$config" /p:Platform=Win32
    if ($dism) {
        Write-Output "Création de l'image dans: $workspace"
        # Vérifier que les chemins existent
        $imagePath = "$workspace\prebuild\image.wim"
        $mountPath = "$workspace\mount"
        if (-not (Test-Path $imagePath)) {
            Write-Error "Le chemin de l'image n'existe pas: $imagePath"
            exit 1
        }
        # Clean up the mount directory
        if (Test-Path "$workspace\mount") {
            Remove-Item -Path "$workspace\mount" -Force -Recurse
            mkdir "$workspace\mount"
        }
        Copy-Item "$workspace\prebuild\image.wim" -Destination "$workspace\$config\image.wim"
        Mount-WindowsImage -ImagePath "$workspace\$config\image.wim" -Path "$mountPath" -Index 1
        Copy-Item -Path "$workspace\$config\Application\*" -Destination "$mountPath\Application\" -Force -Recurse
        Dismount-WindowsImage -Path "$mountPath" -Save
    }
}
