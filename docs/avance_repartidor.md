# Repartidor y pago de demostración

Entrega del 21/10/2026 en `vendedor-vista-jm`. Los commits los realiza el estudiante.

## Alcance

Flujo conectado a Django y al esquema SQL existente: comprador, cotización de cada vendedor, aceptación del precio, pago local opcional con Yape, oferta a repartidores del mismo mercado, aceptación, recojo ordenado y entrega. No se integra Culqi. El simulador no llama a Yape, pasarelas ni bancos y no verifica cuentas o tarjetas reales.

El PDF de contexto describe Culqi como requisito original; para esta entrega prevalece la indicación posterior de dejar esa integración a otro integrante.

## Ejecutar

Desde la raíz del repositorio, en una terminal PowerShell:

```powershell
cd mimercado_backend
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

En otra terminal, también desde la raíz:

```powershell
cd mimercado_frontend
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_URL=http://127.0.0.1:8000 --dart-define=DEVICE_PREVIEW=true
```

La conexión entre perfiles requiere `API_URL`. El repartidor requiere esa opción para iniciar sesión y consultar la base. Si falta, se informa que no está configurada la conexión: no se entra al prototipo ni se muestran pedidos ficticios. El prototipo histórico del repartidor se conserva únicamente para pruebas aisladas. Al probar los tres perfiles simultáneamente, abre sesiones independientes de la aplicación; otra alternativa es cerrar sesión y cambiar de rol. No hace falta instalar dependencias nuevas ni modificar el esquema de base de datos para este avance.

En el `.env` de la raíz:

```dotenv
PAYMENT_MODE=mock
MOCK_YAPE_CODE=123456
```

Si cambias `.env`, reinicia Django. Para recargar los cambios de Flutter, pulsa `R` mayúscula en su terminal (hot restart). Si cambias `API_URL` o el puerto, detén Flutter y vuelve a ejecutarlo con el comando anterior.

## Preparar al repartidor una sola vez

1. Registra o inicia sesión con una cuenta de rol Repartidor.
2. En Inicio selecciona un mercado, una movilidad y solicita autorización.
3. El responsable con acceso al backend autoriza la solicitud. Desde `mimercado_backend`, sustituye el celular por el de esa cuenta:

```powershell
.\.venv\Scripts\python.exe manage.py autorizar_repartidor --celular 9XXXXXXXX
```

El comando conserva el mercado y la movilidad solicitados. No se ha ejecutado contra la base compartida durante el desarrollo. El acceso a la app no permite autorizarse a sí mismo ni cambiarse a otro mercado por petición HTTP.

También se puede indicar un mercado concreto:

```powershell
.\.venv\Scripts\python.exe manage.py autorizar_repartidor --celular 9XXXXXXXX --mercado 1 --movilidad bicicleta
```

El número de mercado es ilustrativo; utiliza uno existente. Las opciones son `a_pie` (Estibador a pie), `carretilla`, `bicicleta`, `moto`, `mototaxi` y `otro`. Para `otro`, agrega `--descripcion "Descripción de la movilidad"`. En Perfil puedes cambiar la movilidad para el próximo reparto y añadir placa si corresponde. El sistema bloquea cambios durante una entrega activa.

## Recorrido para probar

1. **Cliente:** agrega productos de dos puestos del mismo mercado y envía el pedido con Yape o efectivo.
2. **Cada vendedor:** acepta, revisa disponibilidad, pesa y envía su precio final. El total solo queda listo cuando terminan los puestos activos.
3. **Cliente, Mi pedido:** revisa y acepta el precio final. Con Yape aparece la demostración local: usa un celular ficticio de 9 números que empiece con 9 y el código `123456`. Otro código de 6 números permite probar el rechazo y corregirlo. No abras Yape ni uses códigos reales. Con efectivo, el cobro se confirma al entregar.
4. **Repartidor, Inicio:** la tarjeta Mi mercado asignado muestra el mercado de la base; si no está afiliado aparece Sin mercado autorizado y, si solicitó afiliación, Mi mercado solicitado con autorización pendiente. Actualiza y activa Disponible. Recibe únicamente ofertas elegibles del mercado autorizado: cliente, dirección, puestos, distancia aproximada cuando hay coordenadas y ganancia. Puede aceptar o elegir Ahora no. El pedido solo se asigna al aceptar y no puede quedar en dos repartidores.
5. **Vendedores:** marcan sus bolsas listas. El repartidor ve cuándo cada una está en preparación o lista.
6. **Repartidor, Ruta:** confirma cada bolsa en el orden indicado. Solo se habilita ir a entregar cuando todas están recogidas. Si el vendedor confirma la entrega de la bolsa, esa parada también queda recogida. El cambio a En camino lo realiza el repartidor al salir.
7. **Avisos:** Estoy recogiendo y Llegué a tu dirección quedan guardados y aparecen en el seguimiento del comprador. Las pantallas visibles actualizan cada 10 segundos; también tienen Actualizar. No son notificaciones push con la aplicación cerrada.
8. **Entrega:** pide al cliente el código de 4 números de Mi pedido. Un código incorrecto muestra un error y permite corregir. En efectivo debes marcar que recibiste el total. La confirmación pide revisar antes de terminar.
9. **Ganancias:** la entrega completada suma al resumen del día. La ganancia sale de la cotización, no del total de productos; en cotizaciones nuevas de vendedores se fija el envío y ganancia de demostración en S/ 5. No hay desembolsos reales. Las cotizaciones previas conservan sus valores.
10. **Perfil:** información personal, mercado, movilidad y preferencias guardadas de letra grande, sonido y vibración. Al terminar la entrega se puede elegir otra movilidad.

## Accesibilidad y límites

Se conserva el esquema azul/blanco y la navegación Inicio, Ruta, Ganancias y Perfil del diseño. Se usan acciones con texto, estados con icono y descripción, confirmaciones, avisos legibles, errores recuperables y áreas táctiles de al menos 48 dp en las nuevas acciones. Las pruebas de pantalla comprueban recorrido a 320 px y letra al 200%. Esto es una verificación técnica parcial, no una certificación de cumplimiento completo de WCAG o Nielsen.

La distancia se calcula en línea recta entre las coordenadas del mercado y de la entrega. No representa kilómetros por carretera ni tiempo de viaje; sin coordenadas se informa que no está disponible. Contactar muestra/copia el teléfono, no simula una llamada real. Soporte conserva el número de demostración del proyecto.

Compatibilidad SQL: `pagos.canal` conserva su valor heredado `culqi_sandbox`, permitido por el CHECK de la base original. Es solo una etiqueta interna del esquema: el procesador de este avance es exclusivamente local, devuelve `simulado=true` y no contiene llamadas a Culqi ni carga llaves de pasarela.

## Verificación

Backend, con base SQLite aislada; no ejecutar pruebas con la configuración de la base compartida:

```powershell
cd mimercado_backend
.\.venv\Scripts\python.exe manage.py test mvp_back --settings=config.test_settings
```

Frontend, pruebas nuevas:

```powershell
cd mimercado_frontend
flutter test --no-pub test/pedidos_api_repository_test.dart test/repartidor_operaciones_test.dart
```

La suite completa `flutter test --no-pub` incluye pruebas antiguas del vendedor (`flujo_casero_test.dart` y `casero_catalogo_test.dart`) que todavía esperan el prototipo mock y pantallas/códigos anteriores. Se mantienen sin ocultarlas ni omitirlas automáticamente. Las pruebas específicas de los vendedores conectados a la API están en archivos como `revision_productos_casero_test.dart`, `pesaje_casero_real_test.dart`, `seguimiento_vendedor_test.dart` y `catalogo_vendedor_real_test.dart`.

## Preparar un solo commit

Desde la raíz y comprobando que estás en `vendedor-vista-jm`:

```powershell
git branch --show-current
git add -- .env.example README.md docs/avance_repartidor.md
git add -- mimercado_backend/config/settings.py mimercado_backend/config/test_settings.py mimercado_backend/mvp_back/payments.py mimercado_backend/mvp_back/urls.py mimercado_backend/mvp_back/views.py mimercado_backend/mvp_back/tests.py mimercado_backend/mvp_back/operaciones.py mimercado_backend/mvp_back/operaciones_views.py mimercado_backend/mvp_back/test_reparto.py mimercado_backend/mvp_back/management/commands/autorizar_repartidor.py
git add -- mimercado_frontend/lib/core/router/app_router.dart mimercado_frontend/lib/data/models/pedido.dart mimercado_frontend/lib/data/models/repartidor.dart mimercado_frontend/lib/data/repositories/pago_repository.dart mimercado_frontend/lib/data/repositories/pedido_repository.dart mimercado_frontend/lib/data/repositories/pedidos_api_repository.dart mimercado_frontend/lib/data/repositories/pedidos_vendedor_api_repository.dart
git add -- mimercado_frontend/lib/features/auth/screens/cliente_login_screen.dart mimercado_frontend/lib/features/canasta/screens/entrega_pago_screen.dart mimercado_frontend/lib/features/canasta/screens/pedido_enviado_screen.dart mimercado_frontend/lib/features/pedido mimercado_frontend/lib/features/perfil/screens/perfil_screen.dart mimercado_frontend/lib/features/repartidor
git add -- mimercado_frontend/test/login_roles_test.dart mimercado_frontend/test/alerta_pedido_real_test.dart mimercado_frontend/test/flujo_cliente_test.dart mimercado_frontend/test/flujo_entrega_cliente_test.dart mimercado_frontend/test/flujo_seguimiento_test.dart mimercado_frontend/test/pedidos_vendedor_vista_test.dart mimercado_frontend/test/pedidos_api_repository_test.dart mimercado_frontend/test/repartidor_operaciones_test.dart mimercado_frontend/test/helpers/reparto_fixture.dart
git diff --cached --stat
git diff --cached
git commit -m "Implementar reparto por mercado y pago simulado local"
git push origin vendedor-vista-jm
```

Todos los `git add` preparan el mismo commit, no crean commits separados. Estos comandos excluyen `.env` y los archivos generados de plugins de Linux, macOS y Windows. El asistente no ejecuta `add`, `commit` ni `push`.
