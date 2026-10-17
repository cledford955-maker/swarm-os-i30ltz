#!/usr/bin/env python3
"""Package supplied/generated art for GRUB. Run from the LUCILLE checkout."""
from pathlib import Path
import shutil, subprocess
root = Path(__file__).resolve().parents[1]
themes = root / 'grub_themes'
for name, title, color, top, height in [('cachyos','CachyOS','#8dffad',43,43),('swarm_os','SWARM OS','#8befff',16,45)]:
    dest=themes/name
    (dest/'icons').mkdir(exist_ok=True)
    # Format/size conversion only; artwork is produced by imagegen.
    for icon, offset in [('endeavouros','+0+0'),('ventoy','+640+0'),('cachyos','+0+640'),('swarm_os','+640+640')]:
        subprocess.run(['magick',str(themes/'reference-icons.png'),'-crop','640x640'+offset,'+repage','-resize','96x96','PNG32:'+str(dest/'icons'/f'{icon}.png')],check=True)
    subprocess.run(['magick',str(themes/'cachyos-c-source.png'),'-resize','96x96','PNG32:'+str(dest/'icons/cachyos.png')],check=True)
    for alias in ['swarm','swarm-live','swarm-install','swarm-safe','arch','archlinux','gnu-linux']:
        shutil.copy2(dest/'icons'/('swarm_os.png' if name=='swarm_os' else 'cachyos.png'),dest/'icons'/f'{alias}.png')
    for alias in ['endeavour','endeavor','endeavour os']:
        shutil.copy2(dest/'icons/endeavouros.png',dest/'icons'/f'{alias}.png')
    subprocess.run(['grub-mkfont','-s','24','-o',str(dest/'menu.pf2'),'/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'],check=True)
    # Simple code-native selection frame, not a replacement for artwork.
    for piece,size in [('c','8x8'),('n','8x2'),('s','8x2'),('e','2x8'),('w','2x8'),('nw','2x2'),('ne','2x2'),('sw','2x2'),('se','2x2')]:
        subprocess.run(['magick','-size',size,'xc:'+('#06151be6' if piece=='c' else color),'PNG32:'+str(dest/f'select_{piece}.png')],check=True)
    (dest/'theme.txt').write_text(f'''# Matching 96px icons; 108px rows. Designed for 1920x1080.
desktop-image: "background.png"
desktop-color: "#05090d"
title-text: ""
terminal-font: "DejaVu Sans Bold 24"
+ label {{
 left = 28%
 top = {9 if name=='cachyos' else top-5}%
 width = 44%
 align = "center"
 text = "{title}"
 color = "{color}"
 font = "DejaVu Sans Bold 24"
}}
+ boot_menu {{
 left = 28%
 top = {top}%
 width = 44%
 height = {height}%
 item_font = "DejaVu Sans Bold 24"
 selected_item_font = "DejaVu Sans Bold 24"
 item_color = "{color}"
 selected_item_color = "#ffffff"
 icon_width = 96
 icon_height = 96
 item_height = 108
 item_padding = 4
 item_spacing = 4
 item_icon_space = 20
 selected_item_pixmap_style = "select_*.png"
}}
+ label {{
 left = 18%
 top = 92%
 width = 64%
 align = "center"
 text = "Up / Down: choose     Enter: open / boot     Esc: back"
 color = "{color}"
 font = "DejaVu Sans Bold 24"
}}
+ progress_bar {{
 id = "__timeout__"
 left = 30%
 top = 89%
 width = 40%
 height = 12
 show_text = false
 fg_color = "{color}"
 bg_color = "#071019"
 border_color = "{color}"
}}
''')
for relative in ['airootfs/boot/grub/themes/swarm_os','grub/themes/swarm_os']:
    dest=root/'40-iso-profile/swarm_os_iso_profile'/relative
    assert dest.resolve().is_relative_to(root), 'Refusing external theme symlink'
    shutil.copytree(themes/'swarm_os',dest,dirs_exist_ok=True)
