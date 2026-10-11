# Referencia de herramientas

Todas leen `/etc/almacenamiento.env` (ver [config.env.example](../config.env.example)).
Las de usuario se instalan en `~/.local/bin`, las de root en `/usr/local/bin`.

## discos

Salud y espacio de todos los discos, en español.

```
discos              tarjetas con colores, símbolos y barras
discos plain        sin colores ni símbolos (también -p, --plain, NO_COLOR, o salida redirigida)
discos --help       ayuda
discos --selftest   prueba interna de umbrales y lectura SMART
```

- **Lee**: `/var/lib/disk-health/*.json` (lo escribe `disk-health-dump` cada hora) y `lsblk`.
- **Código de salida**: 0 todo bien, 1 algo en Atención, 2 algo Crítico. Sirve en scripts:
  `discos plain >/dev/null || notify-send "Revisar discos"`.
- **Variable**: `DISCOS_DATA` cambia la carpeta de datos SMART (útil para pruebas).
- Python 3, solo biblioteca estándar.

## disk-alert

Notificación de escritorio si algún montaje de `MONTAJES_VIGILADOS` supera `ALERTA_UMBRAL`.

```
disk-alert          usa el umbral configurado
disk-alert 10       umbral 10 %: sirve para probar que las notificaciones llegan
```

Timer: `disk-alert.timer` (usuario), 10 min después de arrancar y cada 6 h.

## movil

Backup por USB de iPhone/iPad (libimobiledevice) y Android (adb). Ver [movil.md](movil.md).

```
movil                          respalda todo lo conectado (menos lo excluido)
movil lista                    dispositivos, último backup, snapshots
movil politica                 qué pasa al conectar cada dispositivo
movil politica <disp> preguntar|siempre|nunca
movil restaurar <disp> [snap]  devuelve un backup al teléfono
movil configurar               revisa dependencias y prepara el aviso al conectar
movil auto                     lo que ejecuta udev al conectar: pregunta con un aviso
movil --selftest
```

- **Al conectar** muestra un aviso con botones (Respaldar / Siempre / Ahora no / Nunca) y
  recuerda «Siempre» y «Nunca» por dispositivo en `~/.config/movil/dispositivos.json`.
- **Variables**: `MOVIL_DIR` (carpeta raíz) y `MOVIL_AUTO_HORAS` (horas mínimas entre
  backups al conectar, 24 por defecto).

## iphone-vm

Pasa el iPhone conectado a una VM QEMU (por ejemplo macOS con Xcode) a través del
monitor de QEMU, y lo devuelve al host.

```
iphone-vm on | off | status
```

Usa `VM_MONITOR`, `IPHONE_HOSTBUS` e `IPHONE_HOSTPORT`. Para saber bus y puerto:
`lsusb -t`. Al pasar el iPhone detiene `movil-auto` para que no se pelee por el dispositivo.

## nube-sync

```
nube-sync docs     NUBE_DOCS_LOCAL <-> NUBE_DOCS_REMOTO   (bidireccional, nextcloudcmd)
nube-sync datos    NUBE_SUBIR y teléfonos -> Nextcloud      (solo subida, rclone copy)
```

- `docs` sincroniza en ambos sentidos: **borrar en un lado borra en el otro**. La papelera
  de Nextcloud guarda lo borrado unos 30 días.
- `datos` nunca borra nada, ni local ni remoto: es una copia de respaldo.
- Si falla, manda una notificación. Timers: `nube-docs.timer` (cada hora) y
  `nube-datos.timer` (02:00).
- Credenciales: `~/.netrc` (para nextcloudcmd) y remoto rclone `NUBE_REMOTO`.
- Exclusiones de `docs`: `~/.config/nube/exclude.lst`.

## restic-nube (root)

```
sudo restic-nube                   backup + limpieza (+ verificación parcial los domingos)
sudo restic-nube init              crea el repositorio en el servidor
sudo restic-nube cmd snapshots     cualquier comando de restic
sudo restic-nube cmd restore latest --include <ruta> --target /tmp/r
sudo restic-nube cmd mount /mnt/r  explorar backups como carpetas
```

Respalda el snapshot btrbk más reciente de `@` y `@home` (montado en `/run/restic-src`)
y los `backup-ios` de los teléfonos. Exclusiones: `/etc/restic/exclude`.
Timer: `restic-nube.timer` a las 01:00 (después de btrbk). Si falla,
`restic-nube-fallo.service` manda una notificación.

## disk-health-dump (root)

Guarda `smartctl -j -a` de cada disco en `/var/lib/disk-health/<disco>.json` (644).
Timer: `disk-health-dump.timer`, cada hora. Para actualizar ya:
`sudo systemctl start disk-health-dump`. Los discos USB aparecen mientras estén conectados.

## smartd-notify (root)

Lo llama `smartd` (`-M exec`) cuando detecta un problema, y lo usa
`restic-nube-fallo.service`. Manda la notificación al usuario `NOTIFY_UID`.
Lee `SMARTD_SUBJECT` y `SMARTD_MESSAGE`. Prueba:

```
sudo env SMARTD_SUBJECT=Prueba SMARTD_MESSAGE=Hola /usr/local/bin/smartd-notify
```

## Timers

| Timer | Tipo | Cuándo |
|---|---|---|
| `disk-alert.timer` | usuario | arranque + 10 min, cada 6 h |
| `nube-docs.timer` | usuario | arranque + 5 min, cada hora |
| `nube-datos.timer` | usuario | 02:00 |
| `disk-health-dump.timer` | sistema | arranque + 2 min, cada hora |
| `btrbk.timer` | sistema (paquete btrbk) | 00:00 |
| `restic-nube.timer` | sistema | 01:00 |
| `paccache.timer` | sistema (paquete pacman-contrib) | semanal |

Ver estado: `systemctl --user list-timers` y `systemctl list-timers`.
Los timers de usuario solo corren con la sesión abierta, lo normal en un equipo de escritorio.
