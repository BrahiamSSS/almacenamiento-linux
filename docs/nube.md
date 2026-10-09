# Nube: Nextcloud + restic

## Objetivo

- En el servidor, todo guardado **comprimido sin pérdida** donde la compresión rinda.
- Al traer archivos al PC, que lleguen **normales, sin comprimir**.
- Elegir qué traer **por carpetas**, con el cliente gráfico de Nextcloud.

## Hecho clave: Nextcloud no comprime

Nextcloud guarda los archivos tal cual. Hay dos formas de comprimir:

| Dónde | Cómo | Ventaja | Requisito |
|---|---|---|---|
| **En el disco del servidor** | btrfs `compress-force=zstd` o ZFS `compression=zstd` | Transparente: se guarda comprimido y se entrega normal | El disco de datos de Nextcloud debe ser btrfs o ZFS |
| **En el cliente** | restic `--compression max` | Comprime también en tránsito; cifra; deduplica | Los datos no se ven como archivos en Nextcloud |

Antes de decidir, **mide cuánto se comprimen tus datos**. Fotos, videos y archivos ya
empaquetados no ganan casi nada; sistema, código y documentos sí:

```bash
# muestra aproximada: bytes originales vs comprimidos con zstd -3
find /ruta -type f -size +1M | shuf -n 40 | while read -r f; do head -c 8M "$f"; done \
  | tee >(wc -c >&2) | zstd -3 -c | wc -c
```

Si el servidor usa ext4 y lo grande es incompresible, convertirlo no vale la pena.
Comprime en el cliente lo que sí rinde.

## Tres canales

| Datos | Canal | Sentido | Comprimido | Visible en Nextcloud |
|---|---|---|---|---|
| Carpeta de trabajo (documentos) | `nube-sync docs` → `nextcloudcmd` | ambos | si el servidor lo hace | sí |
| Archivo, fotos de teléfonos | `nube-sync datos` → `rclone copy` | solo subida, nunca borra | si el servidor lo hace | sí |
| Sistema y backups crudos de teléfonos | `restic-nube` → SFTP | solo subida | **sí, en cliente** | no (repositorio aparte) |

Traer al PC: cliente gráfico de Nextcloud, **sincronización selectiva por carpetas**.
Desmarca la carpeta que ya maneja `nube-sync docs` para no tener dos clientes sobre la
misma carpeta.

## Configurar

```bash
sudo pacman -S nextcloud-client rclone restic
```

1. **Contraseña de aplicación**: Nextcloud → Configuración personal → Seguridad →
   "Crear nueva contraseña de aplicación". Nunca uses la contraseña principal.
2. **Guardarla sin que quede en el historial** (fish):
   ```fish
   read -s -P 'Contraseña de aplicación: ' pw
   printf 'machine nube.ejemplo.com login USUARIO password %s\n' $pw > ~/.netrc; chmod 600 ~/.netrc
   rclone config create nube webdav url=https://nube.ejemplo.com/remote.php/dav/files/USUARIO \
       vendor=nextcloud user=USUARIO pass=$pw --obscure >/dev/null
   set -e pw
   ```
3. **Servidor para restic**: una carpeta fuera de los datos de Nextcloud, dueña de tu
   usuario SSH: `sudo install -d -o USUARIO -g USUARIO /srv/restic`.
4. **Contraseña de restic**:
   ```bash
   sudo install -d -m 700 /etc/restic
   openssl rand -base64 32 | sudo tee /etc/restic/password >/dev/null; sudo chmod 600 /etc/restic/password
   sudo cat /etc/restic/password     # cópiala a tu gestor de contraseñas
   sudo restic-nube init
   ```
5. **Cuota**: lo que subas con `nube-sync` cuenta para tu cuota de Nextcloud; restic no.
   Con la imagen Docker de linuxserver.io, `occ` vuelve a separar los argumentos, así que
   escribe el valor sin espacios:
   `docker exec nextcloud occ user:setting USUARIO files quota 250GB`.

## Cliente gráfico en modo oscuro (escritorios sin GNOME/KDE)

En gestores de ventanas como niri o sway, el cliente Qt de Nextcloud puede salir en
claro aunque tu sistema prefiera oscuro. Nextcloud trae su propio modo oscuro: solo
necesita leer la preferencia del **portal** (`org.freedesktop.appearance color-scheme`).
Comprueba que tu portal la reporta:

```bash
gdbus call --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.ReadOne org.freedesktop.appearance color-scheme
# (<uint32 1>,) = oscuro
```

Nextcloud arranca por dos vías (inicio de sesión y activación D-Bus), y las dos deben
llevar `QT_QPA_PLATFORMTHEME=xdgdesktopportal`. Para eso están
[`config/nextcloud-modo-oscuro/`](../config/nextcloud-modo-oscuro/), que `install.sh` copia
a `~/.config/autostart/` y `~/.local/share/dbus-1/services/`. Así solo cambia Nextcloud y
no el resto de apps Qt.

No sirve forzar `qt6ct` con la plantilla Qt de Noctalia u otras parecidas: suelen fijar el
rol `light` en blanco y Nextcloud lo usa como fondo de sus tarjetas, así que quedan
ilegibles.

## Problemas típicos

| Síntoma | Causa | Solución |
|---|---|---|
| Subidas lentísimas con miles de archivos pequeños | Cada archivo son varias consultas a la base de datos; servidor con HDD o compartido | No subir en paralelo; programar la primera carga de noche; los archivos grandes van rápido |
| `Class "WoltLab\WebpExif\ChunkType" not found` (500) al subir `.webp` | Instalación del servidor incompleta tras una actualización | `occ maintenance:repair`; si no, actualizar el contenedor |
| `nextcloudcmd` deja `.sync_*.db` en la carpeta | Es su registro de estado | Normal; no se sube |
| `occ` dice "Too many arguments" | El atajo `occ` de linuxserver separa los argumentos con espacios | Valores sin espacios (`250GB`) |
| restic: "unable to locate cache directory" | Los servicios systemd no tienen `$HOME` | `RESTIC_CACHE_DIR=/var/cache/restic` (ya incluido) |
