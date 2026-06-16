# WSL snapshot / backup

A rollback net for the **archlinux WSL2** distro so a bad `pacman -Syu` (partial
upgrade, glibc/systemd skew, broken userspace) can't leave the box unrecoverable.
On bare metal you'd fix a bricked upgrade from a live USB; WSL has no live USB and
no boot menu. But the whole distro is a single `ext4.vhdx` file, so shutting it
down and copying/exporting that file is a full-system snapshot.

A running distro **cannot snapshot itself** (`wsl --export` needs the distro
stopped, and `wsl --shutdown` kills the shell you ran it from), so the script is
**Windows-side** and run by hand from Windows PowerShell before a risky upgrade.

## Layout

- **Canonical (run from here):** `C:\Users\evan\wsl-backup\`
  - `wsl-snapshot.ps1` - the script
  - `backups\` - exported `archlinux-<timestamp>.vhdx` snapshots land here
- **This dir** (`~/dotfiles/wsl-backup/`) is the version-controlled copy + these
  docs. It is **not** a stow package (don't `stow wsl-backup`); it's a repo
  artifact like `bootstrap.sh`. On a fresh machine, copy `wsl-snapshot.ps1` to
  `C:\Users\<you>\wsl-backup\`.

## Take a snapshot

From a **Windows** PowerShell / Terminal (not from inside WSL):

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\evan\wsl-backup\wsl-snapshot.ps1
```

What it does:
1. `wsl --shutdown`
2. `wsl --export --vhd archlinux C:\Users\evan\wsl-backup\backups\archlinux-<timestamp>.vhdx`
3. prunes the folder to the newest **3** snapshots (each is ~15 GB)

Then back in WSL: `sudo pacman -Syu`.

Params (defaults shown): `-Distro archlinux`, `-Dest "$env:USERPROFILE\wsl-backup\backups"`, `-Keep 3`.

## Restore (swap the live disk back to a snapshot)

```powershell
wsl --shutdown
# optional: keep the current state in case you want it back
Copy-Item 'C:\Users\evan\AppData\Local\wsl\{1e81723e-3a02-4e9f-93df-8e7447404747}\ext4.vhdx' "$env:USERPROFILE\wsl-backup\backups\ext4-before-restore.vhdx"
# restore the chosen snapshot over the live disk
Copy-Item 'C:\Users\evan\wsl-backup\backups\archlinux-YYYYMMDD-HHMMSS.vhdx' 'C:\Users\evan\AppData\Local\wsl\{1e81723e-3a02-4e9f-93df-8e7447404747}\ext4.vhdx' -Force
wsl -d archlinux   # boots the restored state
```

The exported `.vhdx` and the live `ext4.vhdx` are the same kind of artifact (the
distro's root disk), so copying one over the other is a clean swap. It keeps the
distro registration + default user intact, unlike `wsl --import`, which resets the
default user to root. WSL must be fully shut down first or the copy hits a sharing
violation.

## Notes / caveats

- **Run from Windows, never from inside WSL** - the `wsl --shutdown` would kill the
  launching shell.
- **vhdx path / GUID** above is current as of 2026-06-16. If it changes, re-read it:
  `Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*' | Select DistributionName, BasePath`
  (the disk is `<BasePath>\ext4.vhdx`).
- There's a second `docker-desktop` WSL distro; this only touches `archlinux`.
- Backups live on `C:`, so they do **not** survive a dead `C:` drive. This covers
  the `-Syu` footgun, not off-machine disaster recovery (the dotfiles repo + git
  remotes cover rebuilding the box).
- Requires WSL >= 2.0.4 for `--export --vhd` (this box runs 2.6.1.0).
