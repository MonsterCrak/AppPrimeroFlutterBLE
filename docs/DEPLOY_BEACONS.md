# Despliegue Físico de las Radiobalizas

> Guía de despliegue físico de las 3 balizas FSC-BP104D.
> Documento espejo de `E:\Obsidian\Tesis\Emulador BLE Indoor\Distribucion Radiobalizas.md` (ese es la fuente de verdad; este es un resumen in-repo).

## Reglas básicas

- **Altura:** 1.5-2.5 m del piso.
- **Separación:** 3-10 m entre balizas (óptimo 5-7 m), formando triángulo.
- **Línea de vista:** sin obstrucciones metálicas grandes entre baliza y zonas caminadas.
- **Alejar de:** routers Wi-Fi, microondas, espejos grandes, electrodomésticos metálicos.
- **Orientación:** cara plana contra la pared, antena apuntando al centro del ambiente.

## Distribución objetivo

3 balizas formando un **triángulo** que cubra toda el área caminable de la casa. Una en la zona más usada (sala), una en zona de transición (pasillo), una en el extremo (dormitorio lejano).

## Pendiente: esquema de la casa del usuario

Para terminar de ajustar el código (`HouseMap`, `BeaconConfig.defaultPositions`, waypoints del simulador) necesitamos:

- Plano de planta de la casa (foto, screenshot o ASCII art).
- Dimensiones aproximadas de cada ambiente.
- Ubicación propuesta de las 3 balizas, o confirmación de las coordenadas placeholder.

## Hardware ya está OK para iOS

> [!important] Nota iOS
> Las balizas FSC-BP104D emiten tramas iBeacon estándar de Apple. **No hay que tocar nada físico** para que funcionen en iPhone/iPad. Lo único que cambia entre Android e iOS es el **software y los permisos** (Apple obliga a usar CoreLocation en lugar de CoreBluetooth). Esto se maneja desde WU-11 en adelante.

## Referencias

- Plan maestro: `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md`
- Guía completa: `E:\Obsidian\Tesis\Emulador BLE Indoor\Distribucion Radiobalizas.md`
- Config actual: `lib/config/beacon_config.dart`