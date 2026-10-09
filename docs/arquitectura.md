# Arquitectura

## Un rol por disco

Con varios discos de distinto tamaño y velocidad, conviene asignar a cada uno un rol
en lugar de unirlos. El patrón que usa este repo:

| Rol | Disco ideal | Sistema de archivos | Montaje | Contenido |
|---|---|---|---|---|
| **Sistema** | El más rápido (NVMe) | btrfs, `compress=zstd:1` | `/`, `/home` (subvolúmenes `@`, `@home`…) | SO, programas, home, proyectos activos |
| **Máquinas virtuales** | Segundo NVMe/SSD | btrfs, subvolumen `@vm` con `nodatacow` | `/mnt/vm` | Discos de VMs (qcow2) |
| **Datos y backups** | El más grande, aunque sea lento | btrfs, `compress=zstd:3` | `/mnt/datos` | Destino de btrbk, backups de teléfonos, archivo frío |

¿Por qué así?

- **El sistema en el disco más rápido**: es lo que más se lee al usar el PC.
- **Las VMs aparte**: sus imágenes son enormes y se reescriben todo el tiempo.
  `nodatacow` evita la fragmentación del copy-on-write. Como contrapartida, btrfs no
  verifica checksums en esos archivos: los backups de las VMs son tu única protección.
- **Los backups en otro disco físico**: un snapshot en el mismo disco no te salva si
  ese disco muere.
- **El disco lento para datos fríos**: los SSD SATA sin DRAM y los HDD caen a 80–100 MB/s
  en escrituras largas. Para backups nocturnos da igual.

### ¿Y RAID?

No se usa. Con discos de tamaños y buses distintos:

- **RAID0** queda limitado al disco más lento, y si falla uno se pierde todo.
- **RAID1** desperdicia la mitad del espacio, y el disco lento frena todas las escrituras.
- **btrfs multi-disco "single"** solo suma capacidad, con el mismo riesgo.

Un rol por disco más backups en otro disco y en otro lugar da más protección real.
Revisa esta decisión si algún día tienes **dos discos iguales**: ahí un RAID1 btrfs sí
tiene sentido para el rol de datos.

## Backups en capas

```
 Capa 1: snapper          Capa 2: btrbk               Capa 3: restic
 mismo disco              otro disco                  otro lugar (servidor)
 rollback rápido          si muere el disco           si se pierde/roba el equipo
 tras actualizar          del sistema                 o hay incendio/robo
 ─────────────            ─────────────               ─────────────
 al instalar paquetes     diario 00:00                diario 01:00
 máx. 10                  14 d + 8 sem + 6 meses      7 d + 4 sem + 6 meses
                          (sin cifrar, btrfs send)    (cifrado, comprimido, deduplicado)
```

Cada capa cubre un fallo que la anterior no cubre. Detalles y cómo restaurar en
[backups.md](backups.md).

## Mantenimiento automático

| Qué | Cómo | Frecuencia |
|---|---|---|
| Limpiar caché de pacman | `paccache.timer` (deja 3 versiones) | Semanal |
| Limitar snapshots de snapper | `NUMBER_LIMIT=10` en `/etc/snapper/configs/root` | En cada cambio de paquetes |
| Estado SMART para `discos` | `disk-health-dump.timer` | Cada hora |
| Alerta de espacio | `disk-alert.timer` (usuario) | Cada 6 h |
| Salud de discos | `smartd` | Continuo |

Ojo: cada `pacman -Rns` crea un par de snapshots "pre/post". Hasta que se borran,
**retienen el espacio** de lo desinstalado. Si liberas espacio y `df` no baja, revisa
`sudo snapper list`.
