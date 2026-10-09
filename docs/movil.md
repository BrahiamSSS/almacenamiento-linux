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

`movil configurar` revisa todo esto y dice qué falta.

## Automático al conectar

[`etc/udev/90-movil.rules`](../etc/udev/90-movil.rules) detecta iPhones/iPads (vendor
Apple 05ac) y Android con adb, y arranca el servicio de usuario `movil-auto.service`,
que corre `movil auto`:

- como máximo un backup cada 24 h por dispositivo;
- con prioridad baja de CPU y disco;
- con notificación de escritorio al terminar o fallar.

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
