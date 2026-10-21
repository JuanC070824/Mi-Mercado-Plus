# Vista del vendedor: avances 8–10

## Funcionalidad

- Seguimiento del pedido: diferencia la cotización que aún espera a otros puestos de la que ya espera al cliente. Actualiza cada 15 segundos cuando el detalle está visible y la aplicación está activa; también permite actualizar manualmente.
- Preparación y entrega: muestra los productos cotizados, sus cantidades exactas y la nota. Exige confirmación para marcar la bolsa lista. La entrega al repartidor requiere revisar todos los productos y confirmar el cliente y el puesto de la bolsa. No marca la entrega al cliente.
- Catálogo: búsqueda y filtros de disponibilidad, alta y edición de productos y cambio de disponibilidad mediante la API. El formulario conserva los datos si falla el guardado y bloquea solicitudes simultáneas.
- Mi puesto: información y edición del negocio, horario y contacto de billetera si están registrados. Los campos vacíos se identifican como sin registrar. Horario y billetera se consultan; su edición no se incorpora en esta entrega.
- Preferencias: letra grande, sonido y vibración persistidos en la cuenta. Las pantallas conservadas por las pestañas comparten la configuración actual. La letra grande respeta una escala del sistema superior a la de la aplicación.

No cambia el esquema SQL ni requiere migraciones. El acceso del vendedor mantiene celular y contraseña.

Ajuste final de lenguaje: se ocultan los identificadores internos de pedidos y bolsas en vendedor, comprador y repartidor. Las bolsas se identifican por cliente y puesto. Se usa «Precio enviado» y «Productos y precios finales». Los códigos de aprobación de pago y confirmación de entrega siguen disponibles como parte de esas operaciones. Se verificaron 41 pruebas de los recorridos afectados y el análisis estático de los archivos revisados.

## Ejecución local

En una terminal PowerShell:

```powershell
cd "C:\Users\JOSE MM\Desktop\Mi-MercadoPlus\2010\Mi-Mercado-Plus\mimercado_backend"
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

En otra terminal:

```powershell
cd "C:\Users\JOSE MM\Desktop\Mi-MercadoPlus\2010\Mi-Mercado-Plus\mimercado_frontend"
flutter run -d chrome --web-port=3000 --dart-define=API_URL=http://localhost:8000 --dart-define=DEVICE_PREVIEW=true
```

Si Flutter ya está ejecutándose, usar `R` mayúscula (hot restart). Django con `runserver` recarga los cambios de Python.

## Recorrido manual

1. Ingresar como vendedor y abrir Mi puesto. Activar Letra grande, cambiar Sonido y Vibración y comprobar que la configuración se conserva al cambiar de pestaña y al volver a iniciar sesión.
2. En Catálogo, crear un producto, corregir su precio, buscarlo y cambiar su disponibilidad. Probar un precio inválido y un fallo de conexión: no deben perderse los datos del formulario ni confirmarse un cambio no guardado.
3. Desde un pedido aceptado, revisar y pesar los productos. Después de cotizar, comprobar la espera correspondiente y el resumen del puesto.
4. El comprador acepta la cotización completa desde su propio flujo. El detalle del vendedor debe pasar a preparación al actualizarse.
5. Marcar la bolsa lista y confirmar. Revisar los productos con el checklist, verificar el cliente y los productos y confirmar la entrega al repartidor. La entrega al cliente sigue siendo responsabilidad del repartidor.

## Accesibilidad y usabilidad

Se incorporan estados visibles de guardado y error, recuperación sin pérdida de datos, confirmación de acciones y controles estándar utilizables por teclado. Los formularios y confirmaciones nuevos se comprueban a 320 px y texto al 200 %, con acciones de al menos 48 px en los controles verificados. La preparación dispone de botón y no exige arrastrar.

Las pruebas automatizadas no sustituyen la revisión con lectores de pantalla y usuarios reales. Sonido y vibración requieren un dispositivo y navegador compatibles; las alertas se producen al abrir el aviso de pedido, sin notificaciones push en segundo plano. La pantalla no inventa datos del repartidor ni simula llamadas o cobros.

## Pruebas

Validación de esta entrega: 63 pruebas Flutter seleccionadas aprobadas (incluyen regresión del vendedor, autenticación y repositorio de puestos), 40 pruebas del backend aprobadas, análisis estático sin incidencias en los archivos revisados y compilación web correcta con API local y DevicePreview.

Las pruebas Flutter nuevas están en `catalogo_vendedor_real_test.dart`, `preferencias_vendedor_test.dart`, `seguimiento_vendedor_test.dart` y `mi_puesto_vendedor_test.dart`. Incluyen errores, reintentos, bloqueo de acciones simultáneas y texto ampliado, además de la restauración de preferencias de la cuenta.

El backend se verifica con una base de datos de pruebas aislada:

```powershell
cd "C:\Users\JOSE MM\Desktop\Mi-MercadoPlus\2010\Mi-Mercado-Plus\mimercado_backend"
.\.venv\Scripts\python.exe manage.py test --settings=config.test_settings
```

No ejecutar las pruebas con la configuración de la base de datos real.

