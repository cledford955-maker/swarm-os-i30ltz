# SWARM OS Kiosk UI launches via swarm-ui.service (systemd, TTYPath=/dev/tty1)
# as the `swarm` user, not root, and not from here. See the swarm user's
# .bash_profile for why the old auto-exec fallback was removed.
[[ -f ~/.bashrc ]] && . ~/.bashrc
