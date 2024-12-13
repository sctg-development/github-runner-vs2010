# GitHub Runner with Visual Studio 2010

This repository provides a Docker image `sctg/github-runner-vs2010:2.321.0` for running a self-hosted GitHub runner with Visual Studio 2010 and Windows SDK 7.1a. The main purpose is to enable building Windows XP-compatible applications, as GitHub's standard runners no longer support Visual Studio 2010 and Microsoft has ended Windows XP support.

## Prerequisites

- Docker installed on your host machine
- A GitHub account with appropriate permissions
- A Personal Access Token (PAT) from GitHub
- Windows Server 2019 (for running Windows containers)

## Setting Up Self-Hosted Runners in GitHub

Before running the Docker container, you need to configure your GitHub repository to accept self-hosted runners:

1. Go to your GitHub repository settings
2. Navigate to "Settings" → "Actions" → "Runners"
3. Click on "New self-hosted runner"
4. Note down the repository URL and token (you'll need these later)

Important security considerations:
- Self-hosted runners should only be used in private repositories by default
- If using in public repositories, enable the "Require approval for all outside collaborators" setting
- Set up runner groups to control access to runners
- Configure allowed actions and workflows in repository settings

Runner labels:
- Add relevant labels to your runner (e.g., 'windows-2019', 'vs2010')
- These labels are used in workflow files to target specific runners

## Running Windows Docker Containers on Windows Server 2019

### Prerequisites
1. Install Windows Server 2019 with Desktop Experience
2. Enable Containers and Hyper-V features:
```powershell
Install-WindowsFeature Containers
Install-WindowsFeature Hyper-V
Restart-Computer -Force
```

3. Install Docker:
```powershell
# Install Docker
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/master/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -OutFile install-docker-ce.ps1
.\install-docker-ce.ps1

# Start Docker service
Start-Service docker

# Switch to Windows containers
& $Env:ProgramFiles\Docker\Docker\DockerCli.exe -SwitchDaemon

# Test Docker installation
docker version
```

4. Configure Docker for Windows containers:
```powershell
# Set Docker to use Windows containers by default
[Environment]::SetEnvironmentVariable("DOCKER_DEFAULT_PLATFORM", "windows", "Machine")
```

### Running the Container
When running Windows containers, ensure you use the correct isolation mode:
```powershell
docker run --isolation=process -it -e GH_TOKEN='your_github_token' -e GH_OWNER='your_github_owner' -e GH_REPOSITORY='your_github_repo' sctg/github-runner-vs2010:2.321.0
```

[Rest of the README continues as before...]

## Building the Docker Image

To build the Docker image, run the following command:

```sh
docker build . --tag sctg/github-runner-vs2010:2.321.0 --tag sctg/github-runner-vs2010:latest --push
```

## Running the Docker Container

To run the Docker container, you need to provide the following environment variables:

- `GH_TOKEN`: Your GitHub Personal Access Token with the minimum required scopes: `repo`, `read:org`.
- `GH_OWNER`: The owner of the repository (user or organization).
- `GH_REPOSITORY`: The name of the repository.

Run the container with the following command:

```sh
docker run -it -e GH_TOKEN='your_github_token' -e GH_OWNER='your_github_owner' -e GH_REPOSITORY='your_github_repo' sctg/github-runner-vs2010:2.321.0
```

## Using the Runner in GitHub Workflows

To use this runner in your GitHub workflows, you need to specify the `runs-on` field with your self-hosted runner label.  
Without modification the labels self-hosted, windows, vs2010 and self-hosted-vs2010 are defined.  
Here's a sample real workflow that builds a Windows XP-compatible application:

```yaml
name: Build Windows XP App

on:
  workflow_dispatch:
  release:
    types: [published]

permissions:
    contents: write
    pages: write
    id-token: write
    packages: write
    attestations: write

jobs:
  build:
    runs-on: self-hosted-vs2010  # Use https://github.com/sctg-development/github-runner-vs2010
    
    steps:
    - uses: actions/checkout@v4
      with:
         fetch-depth: 1
    
    - name: Restore Qt487
      shell: bash
      run: |
        _PWD=$(pwd)
        echo "Running in $_PWD"
        ./big-restore.sh
        cd /c/
        7z x -y "$_PWD/Qt487static.zip"

    - name: Build Release
      continue-on-error: true
      shell: powershell
      run: |
        ./build.ps1 -Configurations "Release" -workspace $PWD -dism 0

    # - name: Setup MSBuild
    #   shell: cmd
    #   run: |
    #     call "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat" x86
        
    - name: Build Solution
      shell: cmd
    # This is or real build
    # build.ps1 is provided as an example in the repo
    - name: Build Release Verbose
      continue-on-error: true
      shell: powershell
      run: |
        ./build.ps1 -Configurations "Release Verbose" -workspace $PWD -dism 0
            
    - name: Upload Release Artifacts
      uses: actions/upload-artifact@v4
      with:
        name: windows-xp-build Release
        path: "./Release/Application/**"

    - name: Upload Realease Verbose Artifacts
      uses: actions/upload-artifact@v4
      with:
        name: windows-xp-build Release Verbose
        path: "./Release Verbose//Application/**"
    
    - name: Upload full build
      uses: actions/upload-artifact@v4
      with:
        name: windows-xp-build
        path: "./"

    - name: Create zip file with built files
      shell: bash
      run: |
        7z a -tzip myapp-Release.zip "./Release/Application/**"
        7z a -tzip myapp-Release-Verbose.zip "./Release Verbose/Application/**"

    - name: Create Release with gh
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      shell: powershell
      run: |
        $version = Get-Item -Path "./Release/Application/myapp.exe" | Select-Object -ExpandProperty VersionInfo
        $revision = $version.FileVersionRaw.Revision
        $major = $version.FileVersionRaw.Major
        $minor = $version.FileVersionRaw.Minor
        $build = $version.FileVersionRaw.Build
        $TAG_NAME = "v$major.$minor.$build.$revision"

        Write-Output $TAG_NAME
    
        try {
            gh release create $TAG_NAME -t "$TAG_NAME" -n "$TAG_NAME"
        } catch {
            Write-Output "Release may already exist, continuing..."
        }
        
        gh release upload $TAG_NAME novasulf-ii-Release.zip --clobber
        gh release upload $TAG_NAME novasulf-ii-Release-Verbose.zip --clobber

```

Note: Replace `YourSolution.sln` and paths with your actual project files and build output locations.

## How it Works

The Dockerfile sets up the environment with:
- Visual Studio 2010
- .NET Framework 4.8
- Windows SDK 7.0
- Windows SDK 7.1a
- GitHub runner (version 2.321.0 by default)

The `start.ps1` script handles the container initialization by:
1. Authenticating with GitHub using the provided `GH_TOKEN`
2. Obtaining a registration token for the GitHub runner
3. Registering the runner with the specified repository
4. Starting the runner process

## Troubleshooting

Common issues and solutions:

1. **Runner Registration Fails**:
   - Verify your PAT has the correct permissions
   - Ensure the repository exists and you have access to it

2. **Build Failures**:
   - Check that your solution targets Visual Studio 2010 toolset
   - Verify Windows SDK 7.1a paths are correct

3. **Docker Container Issues**:
   - Ensure you're using process isolation mode on Windows Server 2019
   - Verify Docker is configured for Windows containers
   - Check container logs for startup errors

## Cleanup

When the Docker container is stopped, the runner registration is automatically removed from GitHub. However, if you encounter stale runners, you can use the provided `Cleanup-Runners.ps1` script:

```powershell
.\Cleanup-Runners.ps1 -Owner your_github_owner -Repository your_github_repo -Token your_github_token
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

- **Ronan L**
- Email: [ronan@sctg-development.eu.org](mailto:ronan@sctg-development.eu.org)
- GitHub: [sctg-development/github-runner-vs2010](https://github.com/sctg-development/github-runner-vs2010)

## License

This project is licensed under the GNU Affero General Public License version 3.
