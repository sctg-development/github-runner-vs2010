# docker build . --tag sctg/github-runner-vs2010:2.321.0 --tag sctg/github-runner-vs2010:latest --push
# docker run -it -e GH_TOKEN=github_pat_GN -e GH_OWNER='user_or_org' -e GH_REPOSITORY='reponame' sctg/github-runner-vs2010:2.321.0
##### BASE IMAGE INFO ######
FROM cwuensch/vs2010:vcexpress as base
# https://github.com/cwuensch/VS2010

#input GitHub runner version argument
ARG RUNNER_VERSION="2.321.0"

LABEL Author="Ronan L"
LABEL Email="ronan@sctg-development.eu.org"
LABEL GitHub="https://github.com/sctg-development/github-runner-vs2010"
LABEL BaseImage="servercore/insider:10.0.20348.1"
LABEL RunnerVersion=${RUNNER_VERSION}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

#Set working directory
WORKDIR /actions-runner

# Install .NET Framework 4.8
RUN Invoke-WebRequest -UseBasicParsing -Uri "https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe" -OutFile NDP48-x86-x64-AllOS-ENU.exe; \
    .\\NDP48-x86-x64-AllOS-ENU.exe /quiet /install /norestart
RUN Remove-Item ".\\NDP48-x86-x64-AllOS-ENU.exe" -Force

RUN $ErrorActionPreference = 'Stop'; \
        $ProgressPreference = 'SilentlyContinue'; \
        Invoke-WebRequest \
            -UseBasicParsing \
            -Uri https://dot.net/v1/dotnet-install.ps1 \
            -OutFile dotnet-install.ps1; \
        ./dotnet-install.ps1 \
            -InstallDir '/Program Files/dotnet' \
            -Channel 9.0 \ 
            -Runtime dotnet; \
        Remove-Item -Force dotnet-install.ps1 

#Install chocolatey
RUN powershell -Command Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

#Set working directory
WORKDIR /actions-runner
# We need 7z to unpack the ISOs
RUN choco install -y 7zip git vim gh



#Download GitHub Runner based on RUNNER_VERSION argument (Can use: Docker build --build-arg RUNNER_VERSION=x.y.z)
RUN Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip" -OutFile "actions-runner.zip"; \
    Expand-Archive -Path ".\\actions-runner.zip" -DestinationPath '.'; \
    Remove-Item ".\\actions-runner.zip" -Force

#Add GitHub runner configuration startup script
ADD scripts/start.ps1 .
ADD scripts/Cleanup-Runners.ps1 .
#ENTRYPOINT ["pwsh.exe", ".\\start.ps1"]

# Set MSBuild as entrypoint
ENTRYPOINT ["powershell.exe", ".\\start.ps1"]
#ENTRYPOINT ["C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"]
