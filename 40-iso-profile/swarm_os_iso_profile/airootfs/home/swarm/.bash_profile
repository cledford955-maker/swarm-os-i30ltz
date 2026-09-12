# SWARM OS Kiosk UI launches via swarm-ui.service (systemd, TTYPath=/dev/tty1),
# not from here. A prior version auto-exec'd cage+Flutter on login, which
# raced with swarm-ui.service for tty1 (both could claim it independently) and
# referenced binaries removed by the Slint rewrite. Don't re-add an auto-launch
# here — if swarm-ui.service gives up (StartLimitBurst), landing on a plain
# shell to debug from is more useful than a second broken launch attempt.
[[ -f ~/.bashrc ]] && . ~/.bashrc
