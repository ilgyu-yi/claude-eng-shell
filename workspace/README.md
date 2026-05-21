# workspace/

Where target repos live — either as direct clones or symlinks to external paths.

- `scripts/clone-into.sh <upstream-url>` — clone directly into `workspace/<repo>/`.
- `scripts/register.sh <abs-path>` — register an external path and create a `workspace/<basename>` symlink.

Contents of this directory are not git-tracked (the `.gitignore` whitelist only keeps `.gitkeep` and this README).
