<#
.SYNOPSIS
    Build script for VS2010 projects with optional Windows DISM Image creation.

.DESCRIPTION
    This script builds a Visual Studio 2010 solution with specified configurations.
    It sets up the necessary VS2010 environment variables, validates the environment,
    and optionally mounts a Windows image to copy build artifacts.

.PARAMETER configurations
    An array of build configurations to process (e.g. "Debug", "Release").
    Default: "Release" and "Debug"

.PARAMETER workspace
    The root directory where the solution and associated files are located.
    Default: "C:\my_src"

.PARAMETER dism
    Specifies whether to perform Windows image DISM creation.
    Default: $true

.PARAMETER help
    Displays help information about the script.

.EXAMPLE
    .\build.ps1 -configurations @("Debug","Release") -workspace "C:\my_project" -dism $false

.NOTES
    Requires VS2010 and administrator privileges for image mounting operations.
    Ensure the Visual Studio environment is correctly configured before running this script.
    <#
.SYNOPSIS
    Build script for VS2010 projects with optional Windows DISM Image creation.

.DESCRIPTION
    This script builds a Visual Studio 2010 solution with specified configurations.
    It sets up the necessary VS2010 environment variables, validates the environment,
    and optionally mounts a Windows image to copy build artifacts.

.PARAMETER configurations
    An array of build configurations to process (e.g. "Debug", "Release").
    Default: "Release" and "Release Verbose"

.PARAMETER workspace
    The root directory where the solution and associated files are located.
    Default: "C:\my_src"

.PARAMETER dism
    Specifies whether to perform Windows image DISM creation.
    Default: $true

.PARAMETER help
    Displays help information about the script.

.EXAMPLE
    .\build.ps1 -configurations @("Debug","Release") -workspace "C:\my_project" -dism $false

.NOTES
    Requires VS2010 and administrator privileges for image mounting operations.
    Ensure the Visual Studio environment is correctly configured before running this script.

    Copyright (C) 2025 Ronan Le Meillat
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
    
    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

param (
    [string[]]$configurations = @("Release","Debug"),
    [string]$workspace = "C:\my_src",
    [bool]$dism = $true,
    [Alias("h")]
    [switch]$help
)

# Display help if requested
if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Set output encoding to UTF-8 for proper character display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    Checks if the current PowerShell session has administrator privileges.
.DESCRIPTION
    Creates a WindowsPrincipal object for the current user and checks if it's in the Administrator role.
.OUTPUTS
    Boolean - True if the current user has administrator privileges, otherwise False.
#>
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for administrator privileges and elevate if needed
if (-not (Test-Administrator)) {
    Write-Output "This script requires administrator privileges. Relaunching with elevated privileges."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd $workspace ; .\build.ps1`"" -Verb RunAs
    exit
}

# Initialize Visual Studio 2010 build environment
# Run vcvarsall.bat script in cmd.exe and import all environment variables into current session
$vcvarsall = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
cmd /c " `"$vcvarsall`" x86 && set" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Verify that MSBuild is available in the environment path
if (-not (Get-Command msbuild -ErrorAction SilentlyContinue)) {
    Write-Error "msbuild is not available. Make sure Visual Studio environment is properly configured."
    exit 1
}

# Validate critical Visual Studio 2010 environment variables
# Expected environment variables:
#   VCINSTALLDIR - Visual C++ directory
#   VS100COMNTOOLS - Common tools directory
#   VSINSTALLDIR - Visual Studio installation root
#   WindowsSdkDir - Windows SDK directory
if (-not $env:VCINSTALLDIR -or -not $env:VS100COMNTOOLS -or -not $env:VSINSTALLDIR -or -not $env:WindowsSdkDir) {
    Write-Error "Visual Studio environment variables are not correctly configured."
    exit 1
}

# Ensure the Visual Studio version is correct (VS2010)
if ( $env:VCINSTALLDIR -notlike "*10.0\VC*") {
    Write-Error "VCINSTALLDIR is not correctly configured."
    exit 1
}

if ( $env:VS100COMNTOOLS -notlike "*10.0\Common7\Tools\") {
    Write-Error "VS100COMNTOOLS is not correctly configured."
    exit 1
}

if ( $env:VSINSTALLDIR -notlike "*\Microsoft Visual Studio 10.0\") {
    Write-Error "VSINSTALLDIR is not correctly configured."
    exit 1
}

if ( $env:WindowsSdkDir -notlike "*\v7.0A\") {
    Write-Error "WindowsSdkDir is not correctly configured."
    exit 1
}

# Begin the build process
Write-Output "Building Solution for configurations: $configurations"

# Process each specified build configuration
foreach ($config in $configurations) {
    # Build the solution with the current configuration
    Write-Output "Building $config"
    msbuild "$workspace\myapp.sln" /p:Configuration="$config" /p:Platform=Win32
    
    # Handle image creation if dism parameter is enabled
    if ($dism) {
        Write-Output "Creating image in: $workspace"
        
        # Define paths for image operations
        $imagePath = "$workspace\prebuild\image.wim"
        $mountPath = "$workspace\mount"
        
        # Verify source image exists
        if (-not (Test-Path $imagePath)) {
            Write-Error "Image path doesn't exist: $imagePath"
            exit 1
        }
        
        # Ensure mount directory exists
        if (-not (Test-Path $mountPath)) {
            mkdir $mountPath
        }
        
        # Clean the mount directory if it exists to avoid conflicts
        if (Test-Path "$workspace\mount") {
            Remove-Item -Path "$workspace\mount" -Force -Recurse
            mkdir "$workspace\mount"
        }
        
        # Copy the base image to configuration-specific location
        Copy-Item "$workspace\prebuild\image.wim" -Destination "$workspace\$config\image.wim"
        
        # Mount the Windows image
        Mount-WindowsImage -ImagePath "$workspace\$config\image.wim" -Path "$mountPath" -Index 1
        
        # Copy build artifacts to the mounted image
        Copy-Item -Path "$workspace\$config\Application\*" -Destination "$mountPath\Application\" -Force -Recurse
        
        # Unmount the image and save changes
        Dismount-WindowsImage -Path "$mountPath" -Save
    }
}