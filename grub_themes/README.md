# CachyOS + SWARM OS GRUB themes

Prepared 2026-09-19. Both use matching 96px icons and 24px bold text at 1920×1080. CachyOS gets the green monitor/wasp; SWARM gets METALWASP. The Cachy icon is a custom cyan C.

Activate both current installations from CachyOS:

    sudo /mnt/Lucy/70-scripts/install_dual_grub_themes.sh

Requires SWARM mounted at /mnt/swarm/@. The installer verifies filesystem UUIDs, saves originals in grub_themes/backups, validates both generated configs before activation, and restores menus/settings on failure. It changes themes and menu configuration, not partitions or EFI bootloader binaries. Existing native kernel/recovery entries remain available below the four system choices; the local OS choice opens its generated kernel submenu. Timeout boots its first kernel.

Other system entries open their existing GRUB configuration. Ventoy chains its UEFI loader. Destination boot files need real-hardware boot verification after installation; a rendering test does not establish successful cross-OS boots.

Assets: original METALWASPGRUB.jpeg; green monitor art edited using built-in imagegen to remove painted text/menu/progress graphics; icon sheet regenerated from the supplied ship/USB/triangle/wasp reference, with the triangle replaced by the requested glossy cyan C. Source assets are kept here; prepare_grub_themes.py performs GRUB packaging and stages SWARM into both profile theme directories.

Image-generation prompts: preserve green monitor/carbon fiber/wasp, remove all menu text and progress bars, clear lower area for real rows; reproduce four reference icons on transparent 2×2 sprite sheet; create an isolated angular glossy cyan CachyOS C with transparent background and legibility at 96px. Built-in tool mode used throughout.

Real GRUB screenshots: ../80-vm/grub-theme-check/cachy-final.png and swarm-final.png. Tests used harmless display-only entries, never booted or modified the host disks.
