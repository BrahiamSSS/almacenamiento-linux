# Modificar según tus necesidades

Regla general: cambia el repo, prueba y ejecuta `./install.sh --apply`. Así tu máquina
y el repo no se desincronizan. Lo específico de la máquina va en `/etc/almacenamiento.env`.

## Recetas

| Quiero… | Dónde | Cómo |
|---|---|---|
| Vigilar otro disco con `disk-alert` | `/etc/almacenamiento.env` | Agrega el montaje a `MONTAJES_VIGILADOS` |
| Cambiar el umbral de aviso de espacio | `/etc/almacenamiento.env` | `ALERTA_UMBRAL=90` |
| Cambiar los umbrales de salud de `discos` | `bin/discos` | Funciones `level_life`, `level_space`, `level_temp`; ajusta también `selftest()` y corre `discos --selftest` |
| Subir otra carpeta a la nube (solo subida) | `/etc/almacenamiento.env` | Agrega `"ruta:Destino"` a `NUBE_SUBIR` (rutas sin espacios) |
| Sincronizar otra carpeta en ambos sentidos | `systemd/user/` | Copia `nube-docs.*` con otro nombre y otra variable; o usa el cliente gráfico |
| Excluir más carpetas de la sincronización | `config/nube-exclude.lst` | Una entrada por línea; comodines permitidos |
| Excluir más rutas del backup restic | `etc/restic-exclude` | Rutas bajo `/run/restic-src/{root,home}` |
| Cambiar la retención de restic | `/etc/almacenamiento.env` | `RESTIC_RETENCION="--keep-daily 14 --keep-monthly 12"` |
| Cambiar la retención de btrbk | `/etc/btrbk/btrbk.conf` | `target_preserve` |
| Cambiar horarios | `systemd/*/*.timer` | `OnCalendar=` (ver `man systemd.time`); después `systemctl daemon-reload` |
| Cambiar de servidor | `/etc/almacenamiento.env` | `SERVIDOR_SSH`, `RESTIC_RUTA`, `NUBE_URL`; `sudo restic-nube init` en el nuevo; nuevo remoto rclone y `.netrc` |
| Respaldar otro teléfono | — | Conéctalo: `movil` lo detecta y crea su subvolumen |
| Cambiar la carpeta de los teléfonos | `/etc/almacenamiento.env` | `MOVIL_DIR`; mueve los subvolúmenes existentes con `btrfs subvolume snapshot` + borrar |
| Notificar a otro usuario | `/etc/almacenamiento.env` | `NOTIFY_UID` |
| Agregar un disco nuevo | [arquitectura.md](arquitectura.md) + [replicar.md](replicar.md#2-discos-y-montajes) | Asígnale un rol, agrégalo a fstab con `nofail` y a `MONTAJES_VIGILADOS` |

## Probar sin romper nada

```bash
bash -n bin/<script>                 # sintaxis
discos --selftest; movil --selftest   # pruebas internas
DISCOS_DATA=/tmp/smart discos plain   # discos con datos SMART de prueba
disk-alert 1                          # forzar avisos
sudo btrbk dryrun
sudo restic-nube cmd backup --dry-run /etc   # restic sin escribir
./install.sh                          # qué cambiaría
```

## Al actualizar el sistema

- Si `pacman` actualiza el **kernel**, reinicia antes de montar sistemas de archivos que
  usen módulos (exFAT, NTFS…): los módulos del kernel en uso se borran con la actualización.
- `nextcloud-client`, `restic` y `rclone` se actualizan con `pacman -Syu`. Los archivos de
  este repo están en tu home y en `/usr/local` / `/etc`, así que las actualizaciones no
  los tocan.
