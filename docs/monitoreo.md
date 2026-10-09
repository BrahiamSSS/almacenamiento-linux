# Monitoreo de discos

## Qué mira `discos` y por qué

| Métrica | Fuente SMART | Atención | Crítico | Por qué importa |
|---|---|---|---|---|
| Estado SMART | `smart_status.passed`, NVMe `critical_warning` | — | falla | Es el autodiagnóstico del propio disco |
| Vida útil | NVMe `percentage_used`; SATA atributos 202/231/177/169 | ≤ 20 % | ≤ 10 % | Las celdas flash se gastan con las escrituras |
| Reserva (NVMe) | `available_spare` vs `available_spare_threshold` | — | ≤ mínimo | Bloques de repuesto; al acabarse, el disco falla rápido |
| Espacio | `lsblk` FSUSED/FSSIZE | ≥ 80 % | ≥ 90 % | btrfs rinde mal y puede bloquearse casi lleno |
| Temperatura | `temperature.current`; límite `op_limit_max` del fabricante si existe | límite − 10 °C | límite (o 70 °C) | Calor sostenido = desgaste y bajada de velocidad |
| Errores | NVMe `media_errors`; SATA 5, 187, 197, 198, 199 | > 0 | — | Sectores dañados o datos ilegibles: respaldar ya |
| Apagados bruscos | NVMe `unsafe_shutdowns`; SATA 174/192 | ≥ 20 % de los arranques | — | Cortes o apagados forzados: riesgo de corrupción |

Los umbrales de vida útil siguen la práctica habitual en servidores: planificar el
cambio al pasar el 80 % de uso y reemplazar al acercarse al 100 %. Ojo: la reserva se
consume de forma no lineal; el último 10 % puede irse en semanas.

### Particularidades conocidas

- **Unidades de escritura**: el atributo 241/246 viene en sectores de 512 B, en bloques
  de 32 MiB o en GiB, según el fabricante. `discos` lo deduce del nombre del atributo
  (`Host_Writes_32MiB`, `..._GiB`).
- **Vida útil doble**: algunos SSD (por ejemplo, los de controladora Silicon Motion)
  reportan un valor normalizado (100) y otro bruto (92) distintos. `discos` usa el
  normalizado. Si importa, mira ambos con `smartctl -A`.
- **Discos USB**: solo se ven si la carcasa deja pasar SMART (chips ASMedia y JMicron sí;
  muchas carcasas baratas no). Con carcasa: `smartctl -d sat`.
- **Apagados bruscos altos en discos USB** son normales si se desenchufan sin apagarlos:
  usa `udisksctl power-off -b /dev/sdX`.

## Accesibilidad y usabilidad (decisiones de diseño)

Basado en [clig.dev](https://clig.dev) y en guías de accesibilidad para CLI:

- **Nunca solo color**: cada estado lleva una palabra (Bien / Atención / Crítico) y un
  símbolo distinto (✔ ▲ ✖). El color solo refuerza; ~5 % de la población no distingue
  bien los colores.
- **`NO_COLOR`, `TERM=dumb` o salida redirigida** activan el modo plano automáticamente.
- **Modo plano para lectores de pantalla**: una frase completa por línea, sin símbolos
  ni barras ("Bien. Temperatura: 46 °C. Normal bajo 60 °C.").
- **Sin animaciones** ni refresco automático: los spinners son un problema para los
  lectores de pantalla.
- **Lo importante primero**: veredicto general en la primera línea, luego el disco del
  sistema, y dentro de cada disco: estado → vida → espacio → temperatura → errores.
- **Cada número se explica**: qué es y desde cuándo preocuparse.
- **Opción desconocida = error con ayuda**, nunca se ignora en silencio.
- **Pantallas estrechas**: las barras se ocultan bajo 70 columnas.

## Avisos automáticos

| Aviso | Herramienta | Cuándo |
|---|---|---|
| Disco casi lleno | `disk-alert` | ≥ `ALERTA_UMBRAL` (85 %), revisado cada 6 h |
| Disco con fallas, temperatura alta | `smartd` → `smartd-notify` | Continuo; temperatura informativa a 60 °C, crítica a 70 °C |
| Backup al servidor falló | `restic-nube-fallo.service` | Al fallar `restic-nube` |
| Sincronización falló | `nube-sync` | Al fallar `docs` o `datos` |

Configurar smartd: ver [`etc/smartd.conf.linea`](../etc/smartd.conf.linea).

## Otras herramientas útiles

| Herramienta | Uso |
|---|---|
| `dysk` | Tabla rápida de discos montados |
| `gdu /ruta` | Navegar carpetas y ver qué ocupa (con `d` borra) |
| `btop` | Lectura y escritura por disco en vivo |
| `compsize /ruta` | Cuánto ahorra la compresión de btrfs |
| `sudo btrfs filesystem usage /` | Uso real en btrfs (incluye lo que retienen los snapshots) |
