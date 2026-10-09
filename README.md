# almacenamiento-linux

Herramientas y guía para organizar varios discos en un PC o portátil Linux con btrfs:
roles por disco, backups en capas (local, otro disco y servidor), monitoreo de salud
accesible, backup de teléfonos por USB y sincronización con Nextcloud.

Pensado para Arch/CachyOS con systemd, pero las ideas aplican a cualquier distribución.

## Qué resuelve

| Problema | Solución |
|---|---|
| El disco del sistema se llena | Un rol por disco: sistema, máquinas virtuales, datos y backups |
| Un backup en el mismo disco no sirve si el disco muere | Tres capas: snapper (mismo disco), btrbk (otro disco), restic (otro lugar) |
| No sé si mis discos están sanos | `discos`: salud SMART y espacio en español, con veredicto Bien / Atención / Crítico |
| Me entero tarde de que un disco se llenó o falla | `disk-alert` y `smartd` mandan notificaciones de escritorio |
| Respaldar el teléfono en Linux | `movil`: backup por USB de iPhone y Android, automático al conectar |
| Llevar archivos a un servidor propio | `nube-sync` (Nextcloud) y `restic-nube` (backup cifrado y comprimido) |

## Arquitectura

```
 Disco rápido (NVMe)          Disco 2 (NVMe/SSD)          Disco grande (SSD/HDD)
 ┌──────────────────┐         ┌──────────────────┐        ┌──────────────────────┐
 │ /  y  /home      │         │ /mnt/vm          │        │ /mnt/datos           │
 │ btrfs + zstd     │         │ btrfs nodatacow  │        │ btrfs + zstd         │
 │ snapper (local)  │──btrbk─────────────────────────────▶│ btrbk/  (diario)     │
 └──────────────────┘         └──────────────────┘        │ dispositivos/ (movil)│
                                                          │ otros datos          │
                                                          └──────────┬───────────┘
                                                                     │ restic (cifrado, comprimido)
                                                                     │ nube-sync (Nextcloud)
                                                                     ▼
                                                             Servidor propio
```

El porqué de cada decisión está en [docs/decisiones.md](docs/decisiones.md).

## Herramientas

| Comando | Corre como | Para qué |
|---|---|---|
| `discos` | usuario | Salud y espacio de todos los discos. `discos plain` para lector de pantalla |
| `disk-alert` | usuario (timer) | Notifica si un disco pasa el umbral de uso |
| `movil` | usuario | Backup de iPhone/Android por USB; automático vía udev |
| `iphone-vm` | usuario | Pasa el iPhone a una VM QEMU (macOS) y de vuelta |
| `nube-sync` | usuario (timer) | `docs`: sincroniza una carpeta con Nextcloud; `datos`: solo sube |
| `restic-nube` | root (timer) | Backup cifrado del sistema y teléfonos a un servidor por SFTP |
| `disk-health-dump` | root (timer) | Guarda el estado SMART cada hora para que `discos` no pida sudo |
| `smartd-notify` | root | Convierte avisos de smartd (y fallos de backup) en notificaciones |

Referencia completa: [docs/herramientas.md](docs/herramientas.md).

## Instalación rápida

```bash
git clone https://github.com/BrahiamSSS/almacenamiento-linux
cd almacenamiento-linux
./install.sh            # muestra qué haría, sin cambiar nada
./install.sh --apply    # instala; crea /etc/almacenamiento.env desde el ejemplo
sudoedit /etc/almacenamiento.env
```

Antes, lee [docs/replicar.md](docs/replicar.md): particionado, montajes, paquetes y
secretos no los instala el script.

## Documentación

1. [Arquitectura](docs/arquitectura.md): roles de los discos y capas de backup
2. [Herramientas](docs/herramientas.md): referencia de cada comando
3. [Monitoreo](docs/monitoreo.md): salud SMART, umbrales y accesibilidad
4. [Backups](docs/backups.md): btrbk y restic, cómo restaurar
5. [Nube](docs/nube.md): Nextcloud + restic, compresión, cliente gráfico
6. [Teléfonos](docs/movil.md): backup de iPhone y Android
7. [Replicar en otra máquina](docs/replicar.md)
8. [Modificar según tus necesidades](docs/modificar.md)
9. [Decisiones](docs/decisiones.md): qué se eligió, qué se descartó y cuándo revisarlo

## Configuración y secretos

Todo lo específico de tu máquina va en `/etc/almacenamiento.env`
(ver [config.env.example](config.env.example)), fuera del repo.
Las contraseñas **nunca** van en ese archivo ni en el repo:

| Secreto | Dónde |
|---|---|
| Contraseña del repositorio restic | `/etc/restic/password` (600, root) + copia en tu gestor de contraseñas |
| Contraseña de aplicación de Nextcloud | `~/.netrc` (600) y `~/.config/rclone/rclone.conf` (ofuscada) |
| Llave SSH del servidor | `~/.ssh/` |

## Licencia

MIT
