# FTP Deploy Packager

A lightweight Bash tool that generates incremental FTP deployment packages from Git repositories.

It creates deployment-ready folders and ZIP archives containing only the files changed since the last deployment, making it ideal for shared hosting environments where deployments are performed via FTP.

## Requirement

- lftp (required for FTP deployment)
    ```text
    brew install lftp
    ```

## Installation & configuration:

- Step1: Clone or download the script
- Step2: Make it executable
    ```text
    chmod +x make_deploy.sh`
    ```
  
- Step3: Ensure Git upstream is set

    ```text
    git remote add origin <repo-url>
    git branch --set-upstream-to=origin/main
    ```

- Set FTP Configuration on .deploy.env

## Usage:

Run deployment from outside or anywhere:

```text
./make_deploy.sh <repo-path> <unpushed|since-push> [--deploy] [site-name]
```

Example:

```text
./make_deploy.sh ../repo-path since-push

./make_deploy.sh ../repo-path since-push --deploy folermela
```

## Features:

- Preserves full Git folder structure
- Detects modified files
- Detects untracked files
- Tracks deleted files
- Generates timestamp-based deploy folders
- Maintains deployment history log
- Safe inside project deploy/ directory
- Works from external script location
- No framework dependency

## Deployment Package Structure:

```text
project/
└── deploy/
    ├── history.log
    ├── 20260617_183210/
    │   ├── deploy_info.txt
    │   ├── manifest.txt
    │   ├── deleted_files.txt
    │   ├── app/
    │   │   └── Http/
    │   │       └── UserController.php
    │   └── public/
    │       └── js/
    │           └── app.js
```

- history.log contains:
    - Deployment timestamp
    - Package name (folder)
    - Git branch
    - Git commit hash
    - Deployment mode (unpushed / since-push)
    - Execution time log of each deployment

- deleted_files.txt contains:
    - List of files deleted since last deployment
    - One file path per line
    - Relative path from project root

- manifest.txt contains:
    - List of all files included in deployment package
    - Preserves folder structure
    - Only files that exist and were copied



## Notes:

- This tool does NOT deploy automatically
- It only prepares deployment packages
- Safe for FTP / SFTP / manual deployment
- Works with any PHP / Laravel / Node / static project
- Recommended to keep script outside project directory

## License

MIT License
