<img width="3168" height="1344" alt="banner" src="https://github.com/user-attachments/assets/34726fb6-e09d-4640-b07c-24c972b221e1" />


# Mi-Mercado-Plus
Una aplicación móvil que resuelve el problema de las ventas en línea para los mercados locales

A día de 07/10/2026 presenta las siguientes características o metas:
## Requisitos Funcionales
- RF-01: Gestión de Identidad y Roles
  El sistema debe permitir el registro, inicio de sesión y gestión de perfiles diferenciados para tres roles: Cliente (comprador), Vendedor (casero) y Estibador (repartidor).
  
- RF-02: Carrito de Compras Multi-Tienda
El sistema debe permitir al usuario agregar productos de diferentes puestos (ej. verdulería y carnicería) dentro de un mismo mercado en un carrito de compras unificado y procesarlos en una sola orden.

- RF-03: Pasarela de Pagos con API Sandbox (Yape)
El sistema debe integrar la API de Culqi en modo de pruebas (Sandbox) para procesar pagos mediante el código de aprobación de Yape, permitiendo ingresar el número celular y el código de 6 dígitos sin mover dinero real.

- RF-04: Asistencia Gráfica Previa al Pago
El sistema debe mostrar una pantalla previa con un mini tutorial visual (imágenes y pasos sencillos) que guíe al adulto mayor sobre cómo generar el botón "Aprobar compras" en su app de Yape.

- RF-05: Cálculo Automático de Comisiones B2B
El sistema debe calcular y retener automáticamente una comisión del 5% por transacción destinada a la plataforma, registrando el monto neto correspondiente para el casero del mercado.

- RF-06: Asignación Logística por Estibador Autorizado
El sistema debe verificar que un estibador pertenezca activamente a un único mercado autorizado y asignarle de forma centralizada las órdenes agrupadas de ese mercado.

## Requisitos No Funcionales
- RNF-01: Accesibilidad y Usabilidad (Adultos Mayores)
La interfaz gráfica debe utilizar tipografías de gran tamaño, alto contraste visual (esquema azul y blanco limpio) y botones táctiles amplios (mínimo de 48x48 dp) para facilitar la navegación a adultos mayores de 50-60 años.
- RNF-02: Disponibilidad y Confiabilidad de la API
La comunicación entre la app móvil, el backend y los endpoints de prueba de Culqi (Sandbox) debe completarse en un tiempo menor a 3 segundos bajo una conexión estándar.
- RNF-03: Seguridad y Datos Sensibles
Los datos de prueba del entorno Sandbox y las credenciales de conexión (pk_test / sk_test) deben almacenarse de forma segura en variables de entorno del servidor, evitando la exposición en el código fuente del cliente.
- RNF-04: Portabilidad Multiplataforma
La aplicación móvil debe desarrollarse utilizando un framework multiplataforma (como React Native o Flutter) para asegurar un rendimiento fluido tanto en dispositivos Android como iOS.


