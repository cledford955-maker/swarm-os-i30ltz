# SWARM OS — point Docker-compatible tooling at the rootless Podman socket.
# Uses $(id -u) rather than a hardcoded UID: the live ISO's desktop user is
# "swarm" (uid 1000) but install_swarm_os.sh creates "i30ltz" on installed
# systems instead, and this file is shared by both.
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
