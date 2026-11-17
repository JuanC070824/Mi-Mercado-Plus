# Mercado Pago: piloto de Checkout Pro (Orders API)

Integración para **pruebas en Perú**, desactivada por defecto. Django lee
la cotización aceptada y crea una order de prueba en Mercado Pago. Flutter abre
el checkout y consulta su estado mediante Django. El Access Token permanece en
el servidor; el navegador nunca lo recibe. No hace falta Public Key para este
checkout alojado por Mercado Pago.

## Alcance y limitaciones

- No modifica tablas ni el esquema. Sí guarda y concilia registros `Pago` en
  Supabase para habilitar el flujo normal de vendedores y repartidores.
- No hay migraciones, despliegues ni cambios en `render.yaml`.
- Solo una order `ORDTST` verificada con `processed/accredited`, cuenta receptora,
  moneda PEN, referencia, cotización e importe íntegro correctos registra un pago
  aprobado. Los datos del navegador o de una URL de retorno nunca lo aprueban.
- El checkout creado se guarda como pago pendiente. Consultar y confirmar usa un
  POST autenticado y vuelve a verificar con el proveedor. Repetirlo no duplica el
  pago. El GET de estado conserva su comportamiento de solo lectura.
- Al registrarse la aprobación, el pedido aparece al repartidor disponible de
  su mercado. El vendedor entrega la bolsa después de la asignación. Se conservan
  las comprobaciones de recogida, salida, propiedad y código de entrega.
- El piloto aparece en el paso donde actualmente se muestra el simulador Yape,
  después de aceptar el precio final; con la bandera activa, la opción se muestra
  como Pago en línea · Mercado Pago. No añade un método a los catálogos de la BD.
- El pago en línea tiene una pantalla propia después de aceptar el precio final:
  mientras no está aprobado, se muestra el paso de pago en lugar del seguimiento
  del reparto. La order se prepara automáticamente y el botón muestra `Pagar S/ X`.
- La presentación conserva un aviso breve `Demostración académica · sin dinero real`;
  los nombres de variables, credenciales y validaciones siguen limitados a pruebas.
- Efectivo y Plin permanecen como pagos al recibir. Plin no se envía a Mercado Pago:
  el repartidor debe confirmar el cobro y el código del cliente antes de entregar.
  Ese cobro manual se registra con método `plin` y canal `transferencia`, sin validar
  automáticamente una operación bancaria de Plin.
- Compatibilidad temporal: los CHECK de la base solo permiten métodos
  `efectivo/yape/plin` y canales heredados. Se conserva `metodo=yape` y
  `canal=culqi_sandbox` para este piloto; el proveedor efectivo se identifica
  mediante `proveedor_transaccion_id=mp_test_ORDTST...` y se presenta como
  Mercado Pago de prueba. No se llama a Culqi ni al simulador Yape para verificar
  estas operaciones. Para producción debe normalizarse el modelo con el dueño
  de la base; esta compatibilidad no representa la red real de la tarjeta.
- Solo el comprador propietario puede operar. El importe incluye productos y
  envío, calculados por Django; el cliente envía únicamente el ID del pedido.
- Para iniciar: pedido en preparación o listo para recoger, cotización aceptada
  hace menos de 24 horas y sin pago interno aprobado o procesando.
- Una referencia e idempotencia estables por cotización evitan duplicar la
  creación al reintentar tras un corte. La referencia y el ID externo quedan
  guardados en `Pago`, sin depender de memoria de un proceso de Render.
- Se busca en los últimos 29 días, dentro del límite de 30 días de la API.
  Consultas posteriores a esa ventana no sustituyen un historial persistente.
  Una order terminal no se reemplaza automáticamente: revisar el panel.
- No se envían nombres, teléfonos, direcciones ni correos del comprador de
  MiMercado+. Los datos de prueba se introducen directamente en el checkout.
- No se implementan cobros reales, reparto de dinero a vendedores ni comisiones
  de plataforma. Una devolución notificada deja de considerarse aprobada; no se
  ejecutan reembolsos desde MiMercado+ ni se revierten entregas automáticamente.

## Datos que debes configurar localmente

En el `.env` de la raíz de **rama-develop**, junto a las variables ya necesarias
de Django y de tu conexión existente a la BD, añade:

```dotenv
MERCADOPAGO_PRUEBAS_ENABLED=true
MERCADOPAGO_TEST_ACCESS_TOKEN=TU_ACCESS_TOKEN_DEL_ENTORNO_PRUEBA
MERCADOPAGO_TEST_USER_ID=ID_NUMERICO_DEL_VENDEDOR_DE_PRUEBA
MERCADOPAGO_WEBHOOK_SECRET=
MERCADOPAGO_RETURN_URL=
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

El token y el ID deben corresponder a la **misma cuenta vendedora de prueba de
Perú**. Obtén el ID en los datos de la cuenta de prueba del panel de Mercado Pago;
no es el Application ID ni la Public Key. Si el panel no lo muestra, el recurso
autenticado `GET https://api.mercadopago.com/users/me` permite verificar el `id`
del titular del token localmente. No pegues el token en el chat ni en Flutter.
El prefijo `APP_USR` por sí solo no determina si la credencial es de prueba.

Mantén vacías las dos variables opcionales para esta primera prueba en localhost.
Si luego usas retorno automático, configura una URL pública HTTPS del frontend;
una URL de retorno o sus parámetros **nunca** son comprobantes de pago.
Mantén estable `DJANGO_SECRET_KEY`: participa en la referencia de recuperación.

## Ejecutar en Chrome local, puerto 3000

Desde `mimercado_backend`, con las dependencias de `requirements.txt` instaladas:

```powershell
.venv/Scripts/python.exe manage.py runserver 127.0.0.1:8000
```

Desde `mimercado_frontend`, en otra terminal con Flutter disponible:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_URL=http://localhost:8000 --dart-define=MERCADOPAGO_PRUEBAS=true
```

Este comando apunta al backend **local con estos cambios**. El backend desplegado
actualmente en Render todavía no tiene estas rutas. No ejecutes migraciones ni
comandos de carga de datos contra la base compartida para probar esta integración.

1. Inicia sesión como comprador y abre un pedido propio con Pago en línea y precio aceptado,
   que cumpla las condiciones indicadas arriba. Las operaciones normales para
   crear/cotizar/aceptar pedidos siguen teniendo los efectos habituales en la BD.
2. Después de aceptar el precio final aparece **Paso 3 · Paga tu pedido**. La pantalla
   prepara o recupera la order antes de habilitar el botón.
3. Pulsa **Pagar S/ X** para abrir Mercado Pago con un clic directo, sin esperar
   una solicitud HTTP antes de abrir la ventana. También puedes copiar el enlace.
4. Usa una ventana de incógnito sin sesión personal de Mercado Pago, tarjetas y
   datos de prueba del panel. En esta prueba se logró la aprobación con el correo
   de la cuenta compradora de prueba de Mercado Pago, distinto del vendedor.
   Si el checkout pide sesión, usa ese comprador ficticio. Nunca uses tarjetas reales.
5. Vuelve a `http://localhost:3000`. Se comprueba el resultado al regresar; si hace
   falta, pulsa **Ya pagué, verificar**.
   Solo `processed/accredited` con importe íntegro se presenta como aprobado
   y registrado internamente. Una espera, devolución parcial o rechazo no lo son.
   La pantalla también confirma al abrirse o volver del checkout y, mientras hay
   un checkout abierto pendiente, vuelve a comprobarlo cada 15 segundos si está visible.
6. El repartidor disponible acepta el pedido. Cada vendedor marca su bolsa lista
   y la entrega en el orden de recogida. El repartidor sale a entregar y finaliza
   con el código mostrado al comprador. No hace falta simular un segundo pago.
7. Un pedido que ya estaba pagado externamente antes de esta integración (como
   el pedido 4) se recupera y registra desde el mismo botón, sin volver a pagar.

Para volver al simulador anterior, inicia Flutter sin
`--dart-define=MERCADOPAGO_PRUEBAS=true`. Para desactivar el servicio externo,
establece `MERCADOPAGO_PRUEBAS_ENABLED=false` y reinicia Django.

## Rutas y webhook opcional

| Método y ruta | Uso |
|---|---|
| GET `/api/pagos/mercadopago/configuracion/` | Configuración pública para comprador autenticado; no expone secretos. |
| POST `/api/pagos/mercadopago/checkout/` | JSON `{"pedido_id": 25}`. El total proviene de la cotización. |
| POST `/api/pagos/mercadopago/confirmar/` | JSON `{"pedido_id": 25}`. Verifica con el proveedor y concilia el pago. |
| GET `/api/pagos/mercadopago/pedidos/25/estado/` | `25` es el ID interno del pedido del comprador. |
| POST `/api/pagos/mercadopago/webhook/` | Firma HMAC; consulta al proveedor y concilia una order vinculada. |

La consulta manual basta para localhost. Mercado Pago no puede notificar a
`localhost`: para el webhook necesitarás una dirección pública HTTPS del backend
con estos cambios y el secreto de firma del panel en
`MERCADOPAGO_WEBHOOK_SECRET`. Configura el evento de **order** de prueba.
Se valida la firma con `data.id`, `x-request-id`, `ts` y `v1`, y se consulta
la order directamente al proveedor. El estado del cuerpo no determina aprobación.
Las notificaciones repetidas no duplican pagos. El ID externo guardado permite
vincular la notificación al pedido sin aceptar identificadores internos del body.
Orders antiguas sin registro se recuperan desde la confirmación del comprador.

## Verificación automatizada

La suite de Django usa SQLite aislado y respuestas HTTP simuladas; no necesita
credenciales de Mercado Pago ni conexión a Supabase:

```powershell
# En mimercado_backend
.venv/Scripts/python.exe manage.py test --settings=config.test_settings
```

Incluye permisos y propiedad del pedido, cálculo del importe, idempotencia,
validación de cuenta/moneda/entorno/URL, estados de pago, errores de red, firma
del webhook, confirmación idempotente y el recorrido completo hasta la entrega.

```powershell
# En mimercado_frontend
flutter test test/mercadopago_pruebas_test.dart
flutter analyze
```

Las pruebas de Flutter cubren autenticación y cuerpo de la solicitud, validación
del enlace, apertura por clic, confirmación del registro y configuración incompleta.
La transición del paso de pago al seguimiento se prueba con:

```powershell
flutter test test/pago_integrado_flow_test.dart --dart-define=API_URL=http://localhost:8000 --dart-define=MERCADOPAGO_PRUEBAS=true
```

## Referencias oficiales

- [Crear order y obtener checkout_url](https://www.mercadopago.com.pe/developers/es/docs/checkout-pro-orders/create-order)
- [Búsqueda de orders y ventana de fechas](https://www.mercadopago.com.pe/developers/es/reference/online-payments/checkout-pro/search-orders/get)
- [Consultar una order](https://www.mercadopago.com.pe/developers/es/reference/online-payments/checkout-pro/get-order/get)
- [Notificaciones y firma](https://www.mercadopago.com.pe/developers/es/docs/checkout-pro-orders/notifications)
- [Prueba de compra con tarjeta](https://www.mercadopago.com.pe/developers/es/docs/checkout-pro-orders/integration-test/test-purchase-with-card?scope=prod)


### Avisos y acumulados internos

Mercado Pago aparece por defecto en Flutter. Ya no es necesario pasar
`--dart-define=MERCADOPAGO_PRUEBAS=true`; el valor explícito `false` conserva
la demostración anterior. Esto no activa cobros reales: el servidor sigue
requiriendo sus credenciales y habilitación de prueba.

Los vendedores ven el pago confirmado en Inicio y en el detalle del pedido.
Inicio refresca cada 15 segundos mientras está visible. Su resumen de hoy
incluye solamente pagos íntegros de la cotización aceptada; muestra además
el neto acumulado de bolsas recogidas y el neto pagado pendiente de recoger.
Las ganancias del repartidor se acumulan después de validar la entrega,
siempre que exista un pago aprobado por el total. Se incluyen sus entregas
completadas de anteriores asignaciones de mercado. Los importes se calculan
desde los registros existentes, sin migraciones ni incrementos duplicables.

Son avisos dentro de la aplicación y acumulados informativos: no hay push,
transferencias bancarias ni distribución automática de fondos. Plin y efectivo
solo aparecen pagados cuando el repartidor confirma el cobro al entregar.
Los pagos reembolsados dejan de contribuir al acumulado cuando su estado
interno se actualiza; no se implementa aquí una operación de reembolso.
