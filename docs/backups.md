# Backups

Tres capas, cada una para un tipo de desastre distinto.

| Capa | Herramienta | Dónde | Protege de | Retención |
|---|---|---|---|---|
| 1 | snapper | mismo disco | actualización que rompe el sistema, borrado accidental reciente | 10 snapshots |
| 2 | btrbk | disco de datos | muerte del disco del sistema | 14 diarios, 8 semanales, 6 mensuales |
| 3 | restic | servidor remoto | robo, incendio, pérdida del equipo completo | 7 diarios, 4 semanales, 6 mensuales |

## Capa 2: btrbk (al disco de datos)

Configuración: [`etc/btrbk.conf`](../etc/btrbk.conf) → `/etc/btrbk/btrbk.conf`.

- Toma snapshots de `@` y `@home` y los **envía** con `btrfs send` al disco de datos.
  Los envíos después del primero son incrementales: solo los cambios.
- Necesita la raíz btrfs del sistema montada en `/mnt/btr_pool` (`subvolid=5`), ver
  [`etc/fstab.ejemplo`](../etc/fstab.ejemplo).
- Los subvolúmenes anidados (como `.snapshots` de snapper) **no** se incluyen: es lo deseado.
- En el disco del sistema solo se guardan 2 días de snapshots, para que no retengan espacio.

```bash
sudo btrbk dryrun                 # qué haría
sudo btrbk run --progress         # ejecutar ya (la primera vez envía todo)
sudo btrbk list backups           # backups guardados
sudo systemctl enable --now btrbk.timer
```

### Restaurar desde btrbk

**Un archivo**: los backups son carpetas normales de solo lectura:

```bash
ls /mnt/datos/btrbk/
cp -a /mnt/datos/btrbk/@home.20261008T0000/<usuario>/ruta/archivo ~/
```

**El sistema completo** (disco nuevo): arranca desde un USB live, crea un btrfs en el
disco nuevo y envía el backup:

```bash
sudo btrfs send /mnt/datos/btrbk/@.<fecha> | sudo btrfs receive /mnt/nuevo/
sudo btrfs subvolume snapshot /mnt/nuevo/@.<fecha> /mnt/nuevo/@     # copia escribible
# repetir con @home; ajustar fstab (UUID nuevos) y reinstalar el bootloader
```

## Capa 3: restic (al servidor)

Script: `restic-nube` (ver [herramientas.md](herramientas.md#restic-nube-root)).

- **Cifrado**: el servidor solo ve datos ilegibles. Sin la contraseña
  (`/etc/restic/password`) **no hay restauración posible**: guarda una copia en tu
  gestor de contraseñas.
- **Comprimido** (`--compression max`) y **deduplicado**: los archivos repetidos se guardan
  una vez. Datos de sistema y home se comprimen típicamente un 50 % o más.
- Lee el **último snapshot de btrbk** montado en una ruta fija (`/run/restic-src`), no el
  sistema en vivo: así los datos son consistentes y restic reconoce el backup anterior
  (si la ruta cambiara cada día, releería todo).
- Va por **SFTP directo** al servidor, no a través de Nextcloud (ver
  [decisiones.md](decisiones.md)).

### Restaurar desde restic

```bash
sudo restic-nube cmd snapshots
# un archivo o carpeta
sudo restic-nube cmd restore latest --include /run/restic-src/home/<usuario>/Documents/x --target /tmp/r
# explorar como carpetas con el gestor de archivos
sudo mkdir -p /mnt/restic && sudo restic-nube cmd mount /mnt/restic
```

Las rutas dentro del backup empiezan por `/run/restic-src/root` (sistema) y
`/run/restic-src/home` (homes).

### Verificación

Los domingos `restic-nube` revisa al azar el 5 % de los datos (`check --read-data-subset 5%`).
Prueba una restauración real de vez en cuando: un backup que nunca se probó no es un backup.
