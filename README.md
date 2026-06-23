# FTP Deploy Packager

A lightweight Bash tool that generates incremental FTP deployment packages from Git repositories.

It creates deployment-ready folders and ZIP archives containing only the files changed since the last deployment, making it ideal for shared hosting environments where deployments are performed via FTP.

## Features

- Single script that can be stored anywhere
- Works with any Git repository
- Creates timestamped deployment packages
- Preserves original directory structure
- Copies only changed files
- Tracks deleted files
- Generates deployment manifests
- Generates deployment metadata
- Creates ZIP archives automatically
- Tracks deployment history
- Supports `.deployignore`
- Supports `.deployinclude`
- Supports dry-run mode
- Automatically remembers the last deployed commit

## Deployment Package Structure

```text
project/

├── .deploy_last_commit
├── .deployignore
├── .deployinclude
└── deploy/
    ├── history.log
    ├── 20260617_183210.zip
    └── 20260617_183210/
        ├── deploy_info.txt
        ├── manifest.txt
        ├── deleted_files.txt
        ├── app/
        │   └── Http/
        │       └── UserController.php
        └── public/
            └── js/
                └── app.js
```

## Files Generated

### deploy_info.txt

Contains deployment metadata:

```text
Generated At : Tue Jun 17 18:32:10 UTC 2026
Branch       : main
From Commit  : a1b2c3d4
To Commit    : e5f6g7h8
```

### manifest.txt

List of files included in the deployment package:

```text
app/Http/UserController.php
public/js/app.js
resources/views/home.blade.php
```

### deleted_files.txt

List of files removed since the previous deployment:

```text
old.php
legacy/config.php
```

### history.log

Deployment history:

```text
20260617_100500 | main | a1b2c3 -> c4d5e6
20260620_093000 | main | c4d5e6 -> f7g8h9
```

## Example .deployignore

Exclude files and folders from deployment packages:

```text
# deployment exclusions

README.md
docs/
tests/
deploy/
*.sql
*.bak
*.backup
```

## Example .deployinclude

Always include these files even if they have not changed:

```text
public/.htaccess
storage/.gitignore
```

## Installation

Make the script executable:

```bash
chmod +x make_deploy.sh
```

Store it anywhere, for example:

```text
/opt/tools/make_deploy.sh
```

## Usage

### Create Deployment Package

```bash
/opt/tools/make_deploy.sh /var/www/project
```

Or from inside the project directory:

```bash
/opt/tools/make_deploy.sh .
```

### Dry Run

Preview what will be included without creating a package:

```bash
/opt/tools/make_deploy.sh /var/www/project --dry-run
```

Example output:

```text
COPY    : app/Http/UserController.php
COPY    : public/js/app.js
IGNORED : docs/api.md

Deleted Files
-------------
old.php
```


## First Run

On the first execution, no deployment history exists.

The tool will package all tracked files from the repository's first commit up to the current commit and create:

```text
.deploy_last_commit
```

Future deployments will compare against that commit automatically.


## Typical Workflow

```bash
git add .
git commit -m "feature update"

make_deploy.sh . --dry-run

make_deploy.sh .
```

Upload the generated deployment folder (or ZIP archive) via FTP and delete any files listed in:

```text
deleted_files.txt
```

## Use Cases

- Shared hosting deployments
- PHP applications
- Custom web applications
- Servers without Git access
- FTP-only deployment environments

## Roadmap

- [x] Incremental deployment packages
- [x] Deployment history
- [x] ZIP generation
- [x] Deleted file tracking
- [x] .deployignore support
- [x] .deployinclude support
- [ ] Automatic FTP upload
- [ ] SFTP support
- [ ] Git tag based deployments
- [ ] Deployment rollback packages
- [ ] Interactive deployment wizard

## License

MIT License
