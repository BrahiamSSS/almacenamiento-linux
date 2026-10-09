#!/bin/bash
# Instala las herramientas de este repo en su lugar. Ejecutar como usuario normal
# (usa sudo solo para los archivos de sistema).
#   ./install.sh            muestra qué haría (no cambia nada)
#   ./install.sh --apply    instala / actualiza
# No toca: fstab, btrbk.conf, smartd.conf ni secretos (ver docs/replicar.md).
set -euo pipefail
cd "$(dirname "$0")"
APPLY=false; [ "${1:-}" = --apply ] && APPLY=true
cambios=0

# copiar ORIGEN DESTINO MODO [root]
copiar() {
    local src=$1 dst=$2 mode=$3 root=${4:-}
    local estado
    if [ -d "$(dirname "$dst")" ] && [ ! -r "$(dirname "$dst")" ]; then estado="sin-acceso"   # carpeta solo de root: se instala igual con --apply
    elif [ ! -e "$dst" ]; then estado="nuevo"
    elif cmp -s "$src" "$dst"; then estado="igual"
    else estado="cambia"; fi
    printf '  %-10s %s\n' "$estado" "$dst"
    [ "$estado" = igual ] && return
    # Carpeta solo de root: no se puede comparar sin sudo; se reinstala con --apply sin contarlo como cambio.
    if [ "$estado" = sin-acceso ]; then $APPLY && sudo install -D -m "$mode" "$src" "$dst"; return 0; fi
    cambios=$((cambios + 1))
    $APPLY || return 0
    if [ -n "$root" ]; then sudo install -D -m "$mode" "$src" "$dst"
    else install -D -m "$mode" "$src" "$dst"; fi
}

echo "Usuario:"
for f in bin/*; do copiar "$f" "$HOME/.local/bin/$(basename "$f")" 755; done
for f in systemd/user/*; do copiar "$f" "$HOME/.config/systemd/user/$(basename "$f")" 644; done
copiar config/nube-exclude.lst "$HOME/.config/nube/exclude.lst" 644
copiar config/nextcloud-modo-oscuro/com.nextcloudgmbh.Nextcloud.service \
    "$HOME/.local/share/dbus-1/services/com.nextcloudgmbh.Nextcloud.service" 644
copiar config/nextcloud-modo-oscuro/Nextcloud.desktop "$HOME/.config/autostart/Nextcloud.desktop" 644

echo "Sistema (sudo):"
for f in sbin/*; do copiar "$f" "/usr/local/bin/$(basename "$f")" 755 root; done
for f in systemd/system/*; do copiar "$f" "/etc/systemd/system/$(basename "$f")" 644 root; done
copiar etc/udev/90-movil.rules /etc/udev/rules.d/90-movil.rules 644 root
copiar etc/restic-exclude /etc/restic/exclude 644 root
if [ -e /etc/almacenamiento.env ]; then
    printf '  %-10s %s\n' "existe" "/etc/almacenamiento.env (no se toca)"
else
    printf '  %-10s %s\n' "falta" "/etc/almacenamiento.env -> se copia config.env.example: EDÍTALO"
    cambios=$((cambios + 1))
    $APPLY && sudo install -m 644 config.env.example /etc/almacenamiento.env
fi

echo
if [ "$cambios" -eq 0 ]; then echo "Todo al día."; exit 0; fi
if ! $APPLY; then echo "$cambios cambio(s). Ejecuta ./install.sh --apply para aplicarlos."; exit 0; fi

systemctl --user daemon-reload
sudo systemctl daemon-reload
sudo udevadm control --reload
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null
cat <<'MSG'
Instalado. Si es la primera vez, activa los timers que uses:
  systemctl --user enable --now disk-alert.timer nube-docs.timer nube-datos.timer
  sudo systemctl enable --now disk-health-dump.timer restic-nube.timer
MSG
