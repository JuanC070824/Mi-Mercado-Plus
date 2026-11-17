# Mercado Pago dentro de MiMercado+

Flutter Web usa Checkout API Orders con Card Payment Brick y tokenización Yape.
El formulario es parte de la pantalla del pedido; no abre pestañas externas ni
incrusta la página de Checkout Pro. Android/iOS conservan la integración previa
con Checkout Pro; esta entrega del formulario integrado corresponde a web.

## Configuración y ejecución

En `.env` de la raíz de `rama-develop`, conservar las credenciales de prueba ya
utilizadas y agregar `MERCADOPAGO_TEST_PUBLIC_KEY`. Se obtiene del campo **Public
key** en Tus integraciones → aplicación → Credenciales de prueba. Debe pertenecer
a la misma aplicación y cuenta vendedora que el Access Token. El indicador
`MERCADOPAGO_PRUEBAS_ENABLED` debe estar en `true`. No pegar Access Tokens en
archivos web ni enviarlos al navegador. No se activa producción.

La aplicación de Mercado Pago debe tener habilitado Checkout API para usar sus
recursos; tener acceso a Checkout Pro no garantiza permisos para todos los
medios de pago de Checkout API. Las credenciales inválidas o permisos insuficientes
se muestran como error; nunca se simula una aprobación para continuar el flujo.

Desde `mimercado_backend`:

```powershell
.\.venv\Scripts\python.exe manage.py runserver
```

Desde `mimercado_frontend`:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_URL=http://localhost:8000
```

Crear pedido con Pago en línea, aceptar el precio final y pulsar **Completar
pago aquí** dentro de Paso 3. Tarjeta y Yape se muestran en una pantalla de pago
dentro de la aplicación, con desplazamiento propio y un botón para volver al
pedido. Al aprobarse, la pantalla se cierra automáticamente. El formulario no
se expande dentro de la lista Flutter: así evita que el iframe capture los
gestos e impida acceder a los campos inferiores. Usar exclusivamente los datos de prueba publicados para
**Checkout API vía Orders**, no tarjetas reales. El proveedor requiere conexión
a Internet. El importe se obtiene de la cotización aceptada en el servidor.

## Flujo y protección de datos

- El SDK convierte los datos de tarjeta en un token; PAN y CVV no llegan a Django.
- El código OTP de Yape se tokeniza con MercadoPago.js y se borra del formulario.
- Flutter se comunica con el formulario usando origen, ventana emisora y nonce
  por instancia. El iframe no recibe tokens de sesión ni Access Tokens.
- `POST /api/pagos/mercadopago/integrado/` recibe el token, medio de pago y datos
  mínimos del pagador. Rechaza campos adicionales como montos o tarjetas crudas.
- El servidor reserva el intento bajo bloqueo del pedido, antes de llamar a
  Mercado Pago. Solo usa PEN, la cuenta esperada y orders ORDTST de prueba.
- Antes de enviar un token de pago, valida en `/users/me` que las credenciales
  pertenezcan al vendedor de prueba esperado de Perú. No basta con el nombre
  de una variable `.env` para habilitar un cobro.
- Tras crear el pago automático, consulta su resultado por ID y registra la
  aprobación únicamente si coincide el importe íntegro acreditado.
- La misma aprobación alimenta el reparto, los avisos y acumulados existentes.
- Un timeout conserva la reserva. Las verificaciones recuperan el resultado
  por ID o referencia; no se genera otro cargo mientras exista incertidumbre.
- Un rechazo definitivo permite un token nuevo. No se almacenan tokens de
  tarjeta, correo, documento o celular del pagador en el registro de Pago.

Si existe un checkout anterior sin pagar, se muestra su estado. El botón
**Cancelar este intento de pago** permite cancelar esa operación en Mercado
Pago y abrir el nuevo formulario sin cancelar el pedido. No sirve para devolver
pagos acreditados. Las operaciones en procesamiento requieren esperar y verificar.

Este flujo es académico: no incluye cobros reales, transferencias a vendedores,
reembolsos ni resolución de desafíos bancarios 3DS para producción.

## Verificación

```powershell
# Backend: SQLite aislado, red simulada.
.\.venv\Scripts\python.exe manage.py test --settings=config.test_settings
# Desde frontend:
flutter test
node --test test/mercadopago_bridge_test.cjs
flutter build web --dart-define=API_URL=http://localhost:8000
```

Referencias oficiales:
- https://www.mercadopago.com.pe/developers/es/docs/checkout-api-orders/payment-integration/websites/cards
- https://www.mercadopago.com.pe/developers/es/docs/checkout-api-orders/payment-integration/websites/yape
- https://www.mercadopago.com.pe/developers/es/docs/checkout-api-orders/integration-test/cards
