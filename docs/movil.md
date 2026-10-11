# Backup de teléfonos (`movil`)

Backup por USB de iPhone/iPad y Android, sin servicios en la nube del fabricante.

## Qué guarda

Cada dispositivo es un **subvolumen btrfs** en `$MOVIL_DIR/<nombre>-<id>/`:

```
<dispositivo>/
  backup-ios/<UDID>/   backup crudo de Apple (idevicebackup2), restaurable al teléfono
  archivos/            vista legible: en iOS, por app y dominio (las fotos en "carrete")
                       creada con reflinks, así que no ocupa espacio extra;
                       en Android, copia de /sdcard (incremental por tamaño y fecha)
.snapshots/<dispositivo>/<fecha>   snapshot de solo lectura tras cada backup
```

Retención: 7 diarios + 4 semanales, gestionada por el propio `movil`.

## Requisitos

- iPhone: `libimobiledevice` (`idevicebackup2`, `idevice_id`) y emparejar una vez
  (desbloquear el teléfono → "Confiar").
  - El **backup cifrado debe estar desactivado**: `idevicebackup2 -i encryption off <contraseña>`.
    Así el backup queda legible y la vista `archivos/` funciona. Protege el disco de otra
    forma si te preocupa la privacidad.
- Android: `android-tools` (adb) con la **depuración USB** activada.
- `$MOVIL_DIR` en btrfs, montado con `user_subvol_rm_allowed` para que `movil` pueda
  borrar sus snapshots viejos sin root.
- `notify-send` (libnotify 0.7.10 o superior) para el aviso con botones.

`movil configurar` revisa todo esto y dice qué falta.

## Al conectar: pregunta antes de respaldar

[`etc/udev/90-movil.rules`](../etc/udev/90-movil.rules) detecta iPhones/iPads (vendor
Apple 05ac) y Android con adb, y arranca el servicio de usuario `movil-auto.service`,
que corre `movil auto`. Por cada teléfono muestra un aviso de escritorio con cuatro botones:

| Botón | Ahora | La próxima vez que lo conectes |
|---|---|---|
| **Respaldar** | hace el backup | vuelve a preguntar |
| **Siempre** | hace el backup | respalda sin preguntar |
| **Ahora no** (o no responder en 2 min) | nada | vuelve a preguntar, pero no antes de 10 min |
| **Nunca** | excluye el dispositivo | ni pregunta ni respalda; `movil` a mano también lo salta |

- Solo pregunta (o respalda) si el último backup tiene **más de 24 h** (`MOVIL_AUTO_HORAS`):
  así no molesta cada vez que enchufas el teléfono a cargar.
- Un teléfono que nunca se había conectado también pregunta: nada se respalda sin tu permiso.
- Tras «Siempre» o «Nunca» llega un aviso que confirma lo guardado y cómo cambiarlo.
- El backup corre con prioridad baja de CPU y disco, y avisa al terminar o fallar.

### Ver y cambiar lo decidido

```bash
movil politica                        # qué hace cada dispositivo al conectarse
movil politica pixel siempre          # por parte del nombre…
movil politica 1a2b3c4d preguntar     # …o por el final del id que muestra la lista
```

Valores: `preguntar` (por defecto), `siempre`, `nunca`. Se guardan en
`~/.config/movil/dispositivos.json`; si ese archivo se borra o se daña, todo vuelve a
`preguntar`, que es el valor seguro.

### Requisito: avisos con botones

El servidor de notificaciones debe admitir acciones (casi todos: GNOME, KDE, mako, dunst,
swaync, Noctalia…). Compruébalo; debe aparecer `actions`:

```bash
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.GetCapabilities
```

Si el tuyo no las admite, el aviso no tendrá botones y nada se respaldará solo: fija la
decisión a mano con `movil politica <disp> siempre`.

## Restaurar

```bash
movil lista
movil restaurar <dispositivo>            # el más reciente
movil restaurar <dispositivo> <snapshot> # uno concreto
```

Para sacar un archivo suelto, cópialo desde `archivos/` o desde un snapshot.

## Con una VM de macOS (`iphone-vm`)

Para compilar con Xcode en una VM QEMU hace falta el iPhone dentro de la VM:

```bash
iphone-vm on     # detiene movil-auto y pasa el iPhone a la VM
iphone-vm off    # lo devuelve al host
```

Requiere que la VM exponga su monitor QEMU en `VM_MONITOR`
(`-monitor unix:/tmp/mac-monitor.sock,server,nowait`) y `socat`.

## Subir a la nube

- Los `backup-ios/` van cifrados con restic (`restic-nube`).
- Las vistas `archivos/` se suben a Nextcloud con `nube-sync datos` (`NUBE_CELULARES`).
- Los stickers `.webp` de WhatsApp pueden fallar si el servidor tiene el error de WebP
  descrito en [nube.md](nube.md#problemas-típicos).
