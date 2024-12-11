# GitHub Runner with Visual Studio 2010

This repository provides a Docker image `sctg/github-runner-vs2010:2.321.0` for running a self-hosted GitHub runner with Visual Studio 2010 and Windows SDK 7.1a. The main purpose is to create a Windows XP x86 capable runner.

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

## How it Works

The Dockerfile sets up the environment with Visual Studio 2010, .NET Framework 4.8, and other necessary tools. It downloads and configures the GitHub runner based on the specified version (default is `2.321.0`).

The `start.ps1` script is used as the entry point for the Docker container. It performs the following tasks:

1. Logs into GitHub using the provided `GH_TOKEN`.
2. Retrieves a registration token for the GitHub runner.
3. Registers the runner with the specified repository (`GH_OWNER/GH_REPOSITORY`).
4. Starts the runner to listen for jobs.

## Cleanup

When the Docker container is stopped, the runner registration is removed from GitHub. However, due to a known issue, manual cleanup of stale runners may be required using `Cleanup-Runners.ps1`.

## Author

- **Ronan L**
- Email: [ronan@sctg-development.eu.org](mailto:ronan@sctg-development.eu.org)
- GitHub: [sctg-development/github-runner-vs2010](https://github.com/sctg-development/github-runner-vs2010)

## License

This project is licensed under the GNU Affero General Public License version 3.
