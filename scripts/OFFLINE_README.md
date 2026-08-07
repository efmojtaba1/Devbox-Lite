Offline export/import for DevBox Lite

Overview
--------
These helper scripts package the local `devbox-lite` Docker image together with the named Docker volumes used by the compose setup so you can transfer them to an air-gapped machine.

Export (on the build machine)
--------------------------------
1. Build the `devbox-lite` image as usual (or use the image already built).
2. Run (interactive):

```bash
./scripts/export-image    # prompts for output dir and image name
```

This creates `./devbox-offline/image.tar`, volume archives `vol-<name>.tar.gz` and `manifest.txt`.

Package for transfer:

```bash
tar czf devbox-offline.tar.gz -C ./ devbox-offline
```

Import (on the offline machine)
-------------------------------
Copy `devbox-offline.tar.gz` to the offline host and run:

```bash
tar xzf devbox-offline.tar.gz
./scripts/import-image    # prompts for package path and compose file
```

The script will load the image, restore the named volumes, and attempt to run `docker compose up -d` using the provided compose file path. After that `./scripts/init-example.sh` is not required (volumes are restored), and `./scripts/new-project.sh` will be able to create projects offline.

Notes
-----
- The export/import process requires `docker` and `docker compose` available on both sides.
- Volume archives may be large; consider using an external drive or network transfer.
- You may need to run the import commands as a user with Docker privileges.
