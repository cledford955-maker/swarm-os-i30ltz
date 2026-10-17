# Fonts

Put **`Orbitron-Bold.ttf`** in this folder to get the intended look (title, menu and countdown).

- Source: Google Fonts, "Orbitron" (SIL Open Font License 1.1, free to use and redistribute).
- On fonts.google.com press **Get font -> Download all**, unzip, and copy **`static/Orbitron-Bold.ttf`**
  here. Use the file from the `static/` folder, not `Orbitron-VariableFont_wght.ttf`: GRUB's font
  converter only sees a variable font's default (Regular) weight.
- Then run `sudo bash swarm-grub/install.sh` again (it rebuilds the theme every time).

Without it the theme still builds and installs: `build.sh` says so and falls back to DejaVu Sans Bold
(already on Debian), which is what the screenshots in `preview.jpg` use.

The hint line and the `c` console always use DejaVu Sans, because Orbitron has no arrow glyphs and the
console wants a fixed-width face.
