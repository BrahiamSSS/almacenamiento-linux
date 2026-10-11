# Registro de decisiones

Formato: contexto → decisión → alternativas descartadas → cuándo revisarla.

## 1. Un rol por disco, sin RAID
- **Contexto**: varios discos de distinto tamaño, bus y velocidad.
- **Decisión**: sistema / VMs / datos+backups, cada uno en su disco.
- **Descartado**: RAID0 (limitado por el disco lento y frágil), RAID1 (pierde la mitad del
  espacio y lo frena el disco lento), btrfs multi-disco "single" (mismo riesgo, sin ventaja).
- **Revisar si**: tienes dos discos iguales para el rol de datos (RAID1 btrfs).

## 2. btrfs con compresión zstd en todo
- **Decisión**: `zstd:1` en el sistema (rápido) y `zstd:3` en datos (más ahorro, se escribe poco).
- **Por qué**: menos espacio y menos escritura, lo que alarga la vida de los SSD; snapshots baratos.
- **Excepción**: imágenes de VM con `nodatacow`, porque el copy-on-write las fragmenta.

## 3. Tres capas de backup
- **Decisión**: snapper (mismo disco) + btrbk (otro disco) + restic (otro lugar).
- **Descartado**: solo snapper (no sobrevive a la muerte del disco); solo nube (restaurar
  cientos de GB por internet es lento).
- **Revisar si**: cambias de sistema de archivos (btrbk y snapper requieren btrfs).

## 4. restic por SFTP, fuera de Nextcloud
- **Contexto**: hay un Nextcloud propio.
- **Decisión**: el backup del sistema va con restic por SFTP a una carpeta fuera de los
  datos de Nextcloud.
- **Por qué**: WebDAV es lento con muchos archivos pequeños; el versionado y la papelera de
  Nextcloud duplicarían cada paquete del repositorio; restic cifra, comprime y deduplica.
- **Descartado**: restic → rclone → WebDAV de Nextcloud; subir snapshots btrfs como archivos.

## 5. Compresión en el cliente, no convertir el servidor
- **Contexto**: servidor con ext4 (sin compresión transparente) compartido con otros usuarios.
- **Decisión**: comprimir con restic lo que rinde; subir a Nextcloud tal cual lo que ya
  viene comprimido (fotos, videos, archivos empaquetados).
- **Por qué**: medido con muestras de zstd, lo voluminoso suele ser incompresible;
  convertir el disco del servidor arriesga los datos de todos para ganar casi nada.
- **Revisar si**: el servidor pasa a btrfs/ZFS, o si subes datos compresibles grandes
  (activa `compress-force=zstd` en el servidor).

## 6. Dos herramientas para Nextcloud: nextcloudcmd y rclone
- **Decisión**: `nextcloudcmd` (bidireccional) solo para la carpeta de trabajo; `rclone copy`
  (solo subida) para archivo y teléfonos.
- **Por qué**: en un respaldo, una sincronización bidireccional propaga los borrados;
  `rclone copy` nunca borra.
- **Descartado**: rsync + `occ files:scan` (exige permisos del usuario del contenedor y
  reescanear; además la compresión en tránsito no aporta con datos incompresibles).

## 7. restic lee el snapshot de btrbk, no el sistema en vivo
- **Por qué**: datos consistentes (nada cambia mientras se copia) y ruta fija
  (`/run/restic-src`) para que restic reconozca el backup anterior y solo lea cambios.

## 8. `discos` en vez de un TUI genérico
- **Contexto**: btop/dysk muestran espacio y velocidad, pero no la salud.
- **Decisión**: reporte propio en español con SMART, veredictos en palabras y modo plano.
- **Por qué**: accesibilidad (nunca solo color; lector de pantalla), explica cada número,
  códigos de salida para scripts. Root guarda SMART cada hora para no pedir sudo.
- **Descartado**: btop con configuración de discos; TUIs en Rust no empaquetados en los repos.

## 9. Modo oscuro de Nextcloud solo para Nextcloud
- **Decisión**: `QT_QPA_PLATFORMTHEME=xdgdesktopportal` solo en sus lanzadores (autostart y D-Bus).
- **Descartado**: `qt6ct` global con plantillas del shell (rol `light` fijo en blanco:
  tarjetas ilegibles), puente gtk3 (no transmite el modo oscuro en Qt 6).

## 10. Configuración fuera del repo
- **Decisión**: todo lo específico de la máquina en `/etc/almacenamiento.env`; secretos en
  archivos 600 aparte.
- **Por qué**: repo público y reutilizable; el mismo código sirve en otra máquina cambiando
  solo un archivo.

## 11. Preguntar antes de respaldar un teléfono, con un aviso con botones
- **Contexto**: respaldar solo al conectar copiaba también teléfonos ajenos (uno prestado,
  uno que solo se enchufa a cargar).
- **Decisión**: `movil auto` pregunta con una notificación con acciones (Respaldar / Siempre /
  Ahora no / Nunca) y recuerda «Siempre» y «Nunca» por dispositivo. Valor por defecto y ante
  cualquier fallo: preguntar; sin respuesta no se respalda.
- **Por qué un aviso y no un menú central**: no roba el teclado (el aviso puede salir hasta
  30 s después de conectar, cuando ya estás escribiendo otra cosa), es el patrón habitual de
  "dispositivo conectado" y funciona en cualquier escritorio con el estándar de
  notificaciones, sin depender de un lanzador concreto.
- **Descartado**: menú tipo dmenu del shell (toma el foco; ata la herramienta a un escritorio);
  diálogos zenity/kdialog (dependencia nueva).
- **Simplificación**: tras «Ahora no» no se insiste durante 10 min, por tiempo. Revisar si
  molesta: la alternativa es rastrear la desconexión real con udev.
