# PP5PK installer technical map

Reviewed source: `PP5PK/XLX_Installer`

Commit: `865c0ea7abf736b89086fcd4684639f075a02d94`

Review findings included package operations, repository downloads, systemd integration, permissions, use of HTTP for a DMR database download, unsafe `chmod 777` in a reset-permissions template, and recursive deletion in the uninstaller. The modified project does not execute the original installer.
