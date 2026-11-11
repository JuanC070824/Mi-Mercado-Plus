# Base de datos de MiMercado+ (Supabase)

La base vive en el esquema `mimercadoplus` de un proyecto de Supabase. El backend se conecta con
un usuario propio (`mimercado_app`) que solo tiene acceso a ese esquema. Los datos de conexión van
en el `.env` de la raíz (nunca en el repositorio).

## Instalar desde cero

1. En el **SQL Editor** de Supabase ejecuta la sección 1 de `mimercadoplus_v2_supabase.sql`
   (crea el usuario `mimercado_app`; cambia `CAMBIA_ESTA_CLAVE`).
2. Ejecuta las secciones 2 y 3 conectado como `mimercado_app` (o con `SET ROLE mimercado_app;`).
   Crean el esquema oficial v1 (28 tablas, 2 vistas, 4 triggers) y cargan el catálogo y las cuentas de prueba.
3. En `.env`: `DB_USER=mimercado_app.<ref-del-proyecto>`, `DB_HOST=<pooler de sesión>`,
   `DB_NAME=postgres`, `DB_PORT=5432`, `DB_PASSWORD=<la clave del paso 1>`.
4. Desde `mimercado_backend`: `python manage.py migrate` (tablas internas de Django).

## Comandos de datos

| Comando | Qué hace |
|---|---|
| `python manage.py cargar_catalogo` | Carga los 9 mercados, 34 puestos y 68 productos del catálogo del equipo (lee `catalogo_repository.dart`). No duplica. |
| `python manage.py cargar_demo` | Cuentas de prueba y 2 pedidos listos para repartir. Solo con `PAYMENT_MODE=mock`. No duplica. |
| `python manage.py medir_consultas` | Cuenta consultas SQL y tiempo de las pantallas que más se refrescan. |
| `python manage.py autorizar_repartidor --celular 9XXXXXXXX` | Autoriza a un repartidor en su mercado. |

Cuentas de prueba (contraseña `DemoSegura!42`): cliente `900000001`, repartidor `900000090`,
caseros `900000011` y `900000012`; caseros del catálogo `910000001` a `910000034`.

## Rendimiento

Cada consulta viaja hasta el servidor de la base (~100 ms desde Lima hasta Canadá). Por eso las
pantallas arman los pedidos por lotes y la conexión se reutiliza (`DB_CONN_MAX_AGE`, 60 s por defecto).
La prueba `test_consultas_no_crecen_con_cada_pedido` falla si alguna pantalla vuelve a consultar pedido por pedido.
