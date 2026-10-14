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

### Ver qué hizo y cómo detenerlo

`movil-auto.service` no es un programa que se quede corriendo: arranca al conectar un
teléfono, dura lo que tarde el aviso o el backup, y termina. Por eso **no aparece** en
`systemctl --user list-units --type=service --state=running`, salvo en ese momento. Está
instalado igual: se ve con `systemctl --user list-unit-files --type=service`.

| Quiero… | Comando |
|---|---|
| Ver su estado y sus últimas líneas | `systemctl --user status movil-auto` |
| Ver qué hizo las últimas veces | `journalctl --user -u movil-auto -n 30` |
| Cancelar un aviso o un backup en curso | `systemctl --user stop movil-auto` |
| Apagarlo para **todos** los teléfonos | `movil pausar` |
| Volver a encenderlo | `movil reanudar` |
| Que un teléfono concreto no pregunte ni se respalde | `movil politica <disp> nunca` |
| Limpiar la marca `failed` | `systemctl --user reset-failed movil-auto` |

Cancelar un backup a medias no daña lo ya guardado: no se crea snapshot y el siguiente
backup copia lo que faltó.

**La pausa** es el interruptor general. Mientras está puesta, conectar un teléfono no hace
nada: ni aviso ni backup, tampoco para los que están en `siempre`. Sirve para conectar varios
teléfonos seguidos, para presentar sin avisos en pantalla o para saltarse un backup.

- Dura hasta `movil reanudar`: **no se quita sola**, ni al reiniciar. Si la olvidas puesta,
  los teléfonos dejan de respaldarse al conectar. Para que se note, `movil lista` y
  `movil politica` lo avisan en la primera línea.
- A mano, `movil` sigue respaldando lo conectado.
- Es el archivo `~/.config/movil/pausa`: existe = en pausa.

Cómo leer el registro:

| Línea | Significado |
|---|---|
| `último backup hace X, se omite` | Hay un backup de menos de 24 h: ni pregunta ni respalda |
| `ahora no` · `nadie respondió al aviso` | Preguntó y no respaldó |
| `ya se preguntó hace X, todavía no se insiste` | Pausa de 10 min tras «Ahora no» |
| `excluido` | El dispositivo está en `nunca` |
| `En pausa: no se pregunta ni se respalda al conectar` | Está puesta la pausa general |
| `No hay teléfonos conectados` | Se activó, pero en 30 s no apareció ningún teléfono: se desconectó, está bloqueado o falta tocar «Confiar» |
| `Ya hay un backup en curso, o un aviso esperando tu respuesta` | Otra ejecución de `movil` tiene el turno |

En los dos últimos casos, y al cancelarlo con `stop`, `status` lo muestra como `failed`.
No es una avería: la siguiente conexión funciona normal.

`systemctl --user mask movil-auto` **no sirve** para desactivarlo: falla con «File … already
exists» porque el archivo del servicio vive en `~/.config/systemd/user`, la misma carpeta
donde systemd pondría el bloqueo. Para eso está `movil pausar`.

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
