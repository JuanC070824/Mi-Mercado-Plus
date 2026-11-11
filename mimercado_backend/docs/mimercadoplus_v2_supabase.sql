-- =====================================================================
-- MiMercado+ | Base de datos actualizada para Supabase | 10/11/2026
-- Contenido:
--   1. Preparación en Supabase (usuario de la app y permisos)
--   2. Esquema oficial v1 (mimercadoplus_v1.sql, sin cambios salvo crear el esquema solo si falta)
--   3. Datos: catálogo del equipo y cuentas de prueba
-- Después de ejecutarlo: `python manage.py migrate` crea las tablas internas de Django.
-- Las contraseñas de las cuentas de prueba están cifradas (Argon2); no hay claves en texto.
-- =====================================================================

-- 1. PREPARACIÓN EN SUPABASE ------------------------------------------
-- Ejecutar como administrador (SQL Editor de Supabase). En otra base PostgreSQL
-- se puede omitir esta sección y ejecutar el resto con el usuario que corresponda.
-- Reemplaza CAMBIA_ESTA_CLAVE por una contraseña segura y ponla en DB_PASSWORD del .env.
-- En el .env: DB_USER=mimercado_app.<ref-del-proyecto>, DB_HOST=<pooler de sesión>, DB_NAME=postgres.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mimercado_app') THEN
    CREATE ROLE mimercado_app LOGIN PASSWORD 'CAMBIA_ESTA_CLAVE' CONNECTION LIMIT 20;
  END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS mimercadoplus;
GRANT USAGE, CREATE ON SCHEMA mimercadoplus TO mimercado_app;
REVOKE ALL ON SCHEMA mimercadoplus FROM PUBLIC;
ALTER ROLE mimercado_app SET search_path = mimercadoplus;
-- Para que las tablas queden a nombre de la app, ejecuta las secciones 2 y 3
-- conectado como mimercado_app (o descomenta la línea siguiente en el SQL Editor):
-- SET ROLE mimercado_app;

-- 2. ESQUEMA OFICIAL v1 ------------------------------------------------
-- MiMercado+ | Propuesta v1 | PostgreSQL 14+ | Ejecutar completo en Query Tool.
-- Ejecutar UNA VEZ en la base seleccionada (por ejemplo defaultdb).
-- No crea ni elimina bases existentes. Si el esquema existe, se detiene sin modificarlo.
-- Estados y autorizaciones operativas deben validarse también en el backend.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'mimercadoplus') THEN
  CREATE SCHEMA mimercadoplus;
 END IF;
END $$;
SET LOCAL search_path TO mimercadoplus, public;

CREATE TABLE roles (
 codigo varchar(20) PRIMARY KEY,
 nombre varchar(60) NOT NULL
);
INSERT INTO roles VALUES ('comprador','Comprador'),('vendedor','Casero'),
 ('repartidor','Estibador / repartidor'),('administrador','Administrador'),('soporte','Soporte');

CREATE TABLE usuarios (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 nombres varchar(100) NOT NULL,
 apellido_paterno varchar(80), apellido_materno varchar(80),
 celular varchar(20) UNIQUE,
 correo varchar(254),
 password_hash text NOT NULL, -- generar con el sistema de autenticación del backend
 estado varchar(15) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','suspendido','inactivo')),
 fecha_nacimiento date,
 letra_grande boolean NOT NULL DEFAULT false,
 sonido boolean NOT NULL DEFAULT true,
 vibracion boolean NOT NULL DEFAULT true,
 creado_en timestamptz NOT NULL DEFAULT now(),
 CHECK (celular IS NOT NULL OR correo IS NOT NULL),
 CHECK (celular IS NULL OR length(trim(celular)) > 0),
 CHECK (correo IS NULL OR length(trim(correo)) > 0)
);
CREATE UNIQUE INDEX usuarios_correo_unico ON usuarios (lower(correo)) WHERE correo IS NOT NULL;
CREATE TABLE usuario_roles (
 usuario_id bigint NOT NULL REFERENCES usuarios(id),
 rol_codigo varchar(20) NOT NULL REFERENCES roles(codigo),
 PRIMARY KEY (usuario_id,rol_codigo)
);
CREATE TABLE mercados (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 nombre varchar(150) NOT NULL,
 direccion text NOT NULL,
 distrito varchar(100), provincia varchar(100), departamento varchar(100),
 latitud numeric(9,6) CHECK (latitud BETWEEN -90 AND 90),
 longitud numeric(9,6) CHECK (longitud BETWEEN -180 AND 180),
 estado varchar(15) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','suspendido','inactivo')),
 creado_en timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE categorias (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 nombre varchar(100) NOT NULL UNIQUE,
 padre_id bigint REFERENCES categorias(id),
 CHECK (padre_id IS NULL OR padre_id <> id)
);
INSERT INTO categorias(nombre) VALUES ('Verduras y frutas'),('Carnes y aves'),('Abarrotes'),('Pescados y mariscos'),('Hierbas');
CREATE TABLE unidades_medida (
 codigo varchar(15) PRIMARY KEY, nombre varchar(50) NOT NULL,
 permite_fraccion boolean NOT NULL
);
INSERT INTO unidades_medida VALUES ('kg','Kilogramo',true),('unidad','Unidad',false),('atado','Atado',false),('litro','Litro',true);
CREATE TABLE puestos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 mercado_id bigint NOT NULL REFERENCES mercados(id),
 vendedor_id bigint NOT NULL,
 rol_vendedor varchar(20) NOT NULL DEFAULT 'vendedor' CHECK (rol_vendedor='vendedor'),
 categoria_id bigint NOT NULL REFERENCES categorias(id),
 nombre varchar(150) NOT NULL, numero varchar(30), descripcion text, foto_url text,
 contacto_billetera varchar(20), qr_billetera_url text,
 abierto boolean NOT NULL DEFAULT false,
 estado varchar(15) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','suspendido','inactivo')),
 creado_en timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (vendedor_id,rol_vendedor) REFERENCES usuario_roles(usuario_id,rol_codigo),
 UNIQUE (id,mercado_id), UNIQUE (mercado_id,numero)
);
CREATE TABLE horarios_puesto (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 puesto_id bigint NOT NULL REFERENCES puestos(id),
 dia_semana smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- lunes=1
 apertura time NOT NULL, cierre time NOT NULL,
 CHECK (cierre > apertura), UNIQUE (puesto_id,dia_semana,apertura)
);
CREATE TABLE productos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 puesto_id bigint NOT NULL REFERENCES puestos(id),
 categoria_id bigint REFERENCES categorias(id),
 nombre varchar(150) NOT NULL, descripcion text, foto_url text,
 unidad_codigo varchar(15) NOT NULL REFERENCES unidades_medida(codigo),
 precio_unitario numeric(12,2) NOT NULL CHECK (precio_unitario >= 0),
 disponible boolean NOT NULL DEFAULT true,
 stock numeric(12,3) CHECK (stock >= 0), -- NULL: solo se controla disponibilidad
 activo boolean NOT NULL DEFAULT true,
 creado_en timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id,puesto_id)
);
CREATE TABLE repartidor_mercados (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 repartidor_id bigint NOT NULL,
 rol_repartidor varchar(20) NOT NULL DEFAULT 'repartidor' CHECK (rol_repartidor='repartidor'),
 mercado_id bigint NOT NULL REFERENCES mercados(id),
 movilidad varchar(30) NOT NULL CHECK (movilidad IN ('a_pie','carretilla','bicicleta','moto','mototaxi','otro')),
 placa varchar(20), descripcion_movilidad varchar(150),
 autorizado boolean NOT NULL DEFAULT false, disponible boolean NOT NULL DEFAULT false,
 inicio_en timestamptz NOT NULL DEFAULT now(), fin_en timestamptz,
 FOREIGN KEY (repartidor_id,rol_repartidor) REFERENCES usuario_roles(usuario_id,rol_codigo),
 CHECK (fin_en IS NULL OR fin_en >= inicio_en),
 CHECK (NOT disponible OR (autorizado AND fin_en IS NULL)),
 UNIQUE (id,mercado_id)
);
CREATE UNIQUE INDEX repartidor_un_mercado_activo ON repartidor_mercados(repartidor_id)
 WHERE fin_en IS NULL AND autorizado;
CREATE TABLE direcciones (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 comprador_id bigint NOT NULL,
 rol_comprador varchar(20) NOT NULL DEFAULT 'comprador' CHECK (rol_comprador='comprador'),
 etiqueta varchar(50) NOT NULL DEFAULT 'Casa', direccion text NOT NULL, referencia text,
 latitud numeric(9,6) CHECK (latitud BETWEEN -90 AND 90),
 longitud numeric(9,6) CHECK (longitud BETWEEN -180 AND 180),
 principal boolean NOT NULL DEFAULT false, activa boolean NOT NULL DEFAULT true,
 FOREIGN KEY (comprador_id,rol_comprador) REFERENCES usuario_roles(usuario_id,rol_codigo),
 UNIQUE (id,comprador_id)
);
CREATE UNIQUE INDEX una_direccion_principal ON direcciones(comprador_id) WHERE principal AND activa;

-- Una canasta reúne varios puestos, todos del mismo mercado.
CREATE TABLE carritos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 comprador_id bigint NOT NULL,
 rol_comprador varchar(20) NOT NULL DEFAULT 'comprador' CHECK (rol_comprador='comprador'),
 mercado_id bigint NOT NULL REFERENCES mercados(id),
 estado varchar(15) NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto','convertido','abandonado')),
 creado_en timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (comprador_id,rol_comprador) REFERENCES usuario_roles(usuario_id,rol_codigo),
 UNIQUE (id,mercado_id)
);
CREATE UNIQUE INDEX un_carrito_abierto ON carritos(comprador_id) WHERE estado='abierto';
CREATE TABLE carrito_puestos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 carrito_id bigint NOT NULL, mercado_id bigint NOT NULL, puesto_id bigint NOT NULL,
 lista_mandado text, nota text, audio_url text,
 FOREIGN KEY (carrito_id,mercado_id) REFERENCES carritos(id,mercado_id),
 FOREIGN KEY (puesto_id,mercado_id) REFERENCES puestos(id,mercado_id),
 UNIQUE (carrito_id,puesto_id), UNIQUE (id,puesto_id)
);
CREATE TABLE carrito_items (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 carrito_puesto_id bigint NOT NULL, puesto_id bigint NOT NULL, producto_id bigint NOT NULL,
 cantidad numeric(12,3) NOT NULL CHECK (cantidad > 0),
 FOREIGN KEY (carrito_puesto_id,puesto_id) REFERENCES carrito_puestos(id,puesto_id),
 FOREIGN KEY (producto_id,puesto_id) REFERENCES productos(id,puesto_id),
 UNIQUE (carrito_puesto_id,producto_id)
);

CREATE TABLE pedidos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 codigo varchar(40) NOT NULL UNIQUE, -- lo genera el backend, ej. MM-2026-000345
 comprador_id bigint NOT NULL,
 rol_comprador varchar(20) NOT NULL DEFAULT 'comprador' CHECK (rol_comprador='comprador'),
 mercado_id bigint NOT NULL REFERENCES mercados(id),
 estado varchar(30) NOT NULL DEFAULT 'pendiente' CHECK (estado IN
 ('pendiente','en_preparacion','esperando_confirmacion','listo_para_recojo','en_recojo','en_camino','entregado','cancelado')),
 metodo_pago varchar(15) NOT NULL CHECK (metodo_pago IN ('efectivo','yape','plin')),
 -- Copia histórica de entrega: no se altera al editar el perfil.
 direccion_entrega text NOT NULL, referencia_entrega text,
 destinatario varchar(180) NOT NULL, celular_contacto varchar(20) NOT NULL,
 latitud numeric(9,6) CHECK (latitud BETWEEN -90 AND 90),
 longitud numeric(9,6) CHECK (longitud BETWEEN -180 AND 180),
 programado_para timestamptz, creado_en timestamptz NOT NULL DEFAULT now(),
 motivo_cancelacion text,
 FOREIGN KEY (comprador_id,rol_comprador) REFERENCES usuario_roles(usuario_id,rol_codigo),
 UNIQUE (id,mercado_id), UNIQUE (id,comprador_id)
);
CREATE TABLE pedido_puestos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL, mercado_id bigint NOT NULL, puesto_id bigint NOT NULL,
 codigo_bolsa varchar(50) NOT NULL UNIQUE,
 estado varchar(25) NOT NULL DEFAULT 'pendiente' CHECK (estado IN
 ('pendiente','aceptado','pesando','pesado','en_preparacion','listo','recogido','rechazado','cancelado')),
 lista_mandado text, nota text, audio_url text, motivo_rechazo text,
 aceptado_en timestamptz, listo_en timestamptz,
 responder_antes timestamptz,
 FOREIGN KEY (pedido_id,mercado_id) REFERENCES pedidos(id,mercado_id),
 FOREIGN KEY (puesto_id,mercado_id) REFERENCES puestos(id,mercado_id),
 UNIQUE (pedido_id,puesto_id), UNIQUE (id,puesto_id), UNIQUE (id,pedido_id)
);
CREATE TABLE pedido_detalles (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_puesto_id bigint NOT NULL, puesto_id bigint NOT NULL,
 producto_id bigint, -- NULL: producto ingresado desde la lista de mandado
 nombre_solicitado varchar(150) NOT NULL,
 unidad_codigo varchar(15) NOT NULL REFERENCES unidades_medida(codigo),
 cantidad_solicitada numeric(12,3) NOT NULL CHECK (cantidad_solicitada > 0),
 precio_estimado_unitario numeric(12,2) NOT NULL CHECK (precio_estimado_unitario >= 0),
 disponibilidad varchar(20) NOT NULL DEFAULT 'pendiente' CHECK
 (disponibilidad IN ('pendiente','disponible','sin_stock','reemplazo')),
 FOREIGN KEY (pedido_puesto_id,puesto_id) REFERENCES pedido_puestos(id,puesto_id),
 FOREIGN KEY (producto_id,puesto_id) REFERENCES productos(id,puesto_id),
 UNIQUE (id,pedido_puesto_id)
);

-- Cada modificación de precio final produce una NUEVA cotización completa.
CREATE TABLE cotizaciones (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL REFERENCES pedidos(id),
 version integer NOT NULL CHECK (version > 0),
 estado varchar(15) NOT NULL DEFAULT 'borrador' CHECK
 (estado IN ('borrador','enviada','aceptada','rechazada','reemplazada')),
 costo_envio numeric(12,2) NOT NULL DEFAULT 0 CHECK (costo_envio >= 0),
 ganancia_repartidor numeric(12,2) NOT NULL DEFAULT 0 CHECK (ganancia_repartidor >= 0),
 creado_en timestamptz NOT NULL DEFAULT now(), aceptado_en timestamptz,
 CHECK ((estado='aceptada') = (aceptado_en IS NOT NULL)),
 UNIQUE (pedido_id,version), UNIQUE (id,pedido_id)
);
CREATE UNIQUE INDEX una_cotizacion_aceptada ON cotizaciones(pedido_id) WHERE estado='aceptada';
CREATE TABLE cotizacion_puestos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 cotizacion_id bigint NOT NULL, pedido_id bigint NOT NULL, pedido_puesto_id bigint NOT NULL,
 tasa_comision numeric(6,5) NOT NULL DEFAULT 0.05000 CHECK (tasa_comision BETWEEN 0 AND 1),
 FOREIGN KEY (cotizacion_id,pedido_id) REFERENCES cotizaciones(id,pedido_id),
 FOREIGN KEY (pedido_puesto_id,pedido_id) REFERENCES pedido_puestos(id,pedido_id),
 UNIQUE (cotizacion_id,pedido_puesto_id), UNIQUE (id,pedido_puesto_id)
);
CREATE TABLE cotizacion_detalles (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 cotizacion_puesto_id bigint NOT NULL, pedido_puesto_id bigint NOT NULL,
 pedido_detalle_id bigint NOT NULL,
 nombre_final varchar(150) NOT NULL, -- puede ser reemplazo; preservar texto histórico
 producto_final_id bigint, puesto_id bigint NOT NULL,
 unidad_codigo varchar(15) NOT NULL REFERENCES unidades_medida(codigo),
 cantidad_real numeric(12,3) NOT NULL CHECK (cantidad_real > 0),
 precio_unitario numeric(12,2) NOT NULL CHECK (precio_unitario >= 0),
 subtotal numeric(14,2) GENERATED ALWAYS AS (round(cantidad_real * precio_unitario,2)) STORED,
 FOREIGN KEY (cotizacion_puesto_id,pedido_puesto_id) REFERENCES cotizacion_puestos(id,pedido_puesto_id),
 FOREIGN KEY (pedido_detalle_id,pedido_puesto_id) REFERENCES pedido_detalles(id,pedido_puesto_id),
 FOREIGN KEY (pedido_puesto_id,puesto_id) REFERENCES pedido_puestos(id,puesto_id),
 FOREIGN KEY (producto_final_id,puesto_id) REFERENCES productos(id,puesto_id),
 UNIQUE (cotizacion_puesto_id,pedido_detalle_id)
);
CREATE VIEW v_importes_puesto AS
 SELECT cp.id AS cotizacion_puesto_id, cp.cotizacion_id, cp.pedido_id, cp.pedido_puesto_id,
 cp.tasa_comision, COALESCE(sum(cd.subtotal),0)::numeric(14,2) AS bruto,
 round(COALESCE(sum(cd.subtotal),0)*cp.tasa_comision,2) AS comision,
 COALESCE(sum(cd.subtotal),0)-round(COALESCE(sum(cd.subtotal),0)*cp.tasa_comision,2) AS neto_vendedor
 FROM cotizacion_puestos cp LEFT JOIN cotizacion_detalles cd ON cd.cotizacion_puesto_id=cp.id
 GROUP BY cp.id;
CREATE VIEW v_totales_cotizacion AS
 SELECT c.id AS cotizacion_id, c.pedido_id, c.version, c.estado,
 COALESCE(sum(v.bruto),0)::numeric(14,2) AS total_productos,
 c.costo_envio, (COALESCE(sum(v.bruto),0)+c.costo_envio)::numeric(14,2) AS total_cliente,
 COALESCE(sum(v.comision),0)::numeric(14,2) AS comision_plataforma,
 COALESCE(sum(v.neto_vendedor),0)::numeric(14,2) AS neto_vendedores,
 c.ganancia_repartidor
 FROM cotizaciones c LEFT JOIN v_importes_puesto v ON v.cotizacion_id=c.id GROUP BY c.id;

CREATE TABLE pagos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL, cotizacion_id bigint NOT NULL,
 metodo varchar(15) NOT NULL CHECK (metodo IN ('efectivo','yape','plin')),
 canal varchar(20) NOT NULL CHECK (canal IN ('contra_entrega','transferencia','culqi_sandbox')),
 estado varchar(15) NOT NULL DEFAULT 'pendiente' CHECK
 (estado IN ('pendiente','procesando','aprobado','rechazado','anulado','reembolsado')),
 monto numeric(14,2) NOT NULL CHECK (monto > 0), moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda='PEN'),
 idempotencia varchar(100) NOT NULL UNIQUE,
 proveedor_transaccion_id varchar(150) UNIQUE, comprobante_url text,
 creado_en timestamptz NOT NULL DEFAULT now(), confirmado_en timestamptz,
 FOREIGN KEY (cotizacion_id,pedido_id) REFERENCES cotizaciones(id,pedido_id),
 CHECK (canal <> 'culqi_sandbox' OR metodo='yape')
 -- No guardar clave Culqi, código de aprobación de Yape ni cuerpos completos de API.
);
CREATE UNIQUE INDEX un_pago_aprobado ON pagos(pedido_id) WHERE estado='aprobado';
CREATE TABLE entregas (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL, mercado_id bigint NOT NULL,
 repartidor_mercado_id bigint NOT NULL,
 estado varchar(20) NOT NULL DEFAULT 'asignada' CHECK
 (estado IN ('asignada','aceptada','en_recojo','en_camino','entregada','rechazada','cancelada')),
 asignada_en timestamptz NOT NULL DEFAULT now(), aceptada_en timestamptz,
 salida_en timestamptz, entregada_en timestamptz, llegada_estimada timestamptz,
 codigo_entrega_hash text, codigo_validado_en timestamptz,
 FOREIGN KEY (pedido_id,mercado_id) REFERENCES pedidos(id,mercado_id),
 FOREIGN KEY (repartidor_mercado_id,mercado_id) REFERENCES repartidor_mercados(id,mercado_id),
 UNIQUE (id,pedido_id)
);
CREATE UNIQUE INDEX una_entrega_vigente ON entregas(pedido_id) WHERE estado NOT IN ('rechazada','cancelada');
CREATE TABLE entrega_paradas (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 entrega_id bigint NOT NULL, pedido_id bigint NOT NULL, pedido_puesto_id bigint NOT NULL,
 orden smallint NOT NULL CHECK (orden > 0),
 recogido_en timestamptz,
 FOREIGN KEY (entrega_id,pedido_id) REFERENCES entregas(id,pedido_id),
 FOREIGN KEY (pedido_puesto_id,pedido_id) REFERENCES pedido_puestos(id,pedido_id),
 UNIQUE (entrega_id,orden), UNIQUE (entrega_id,pedido_puesto_id)
);
CREATE TABLE historial_estados (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL REFERENCES pedidos(id), pedido_puesto_id bigint,
 estado varchar(30) NOT NULL, observacion text,
 actor_id bigint REFERENCES usuarios(id), creado_en timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (pedido_puesto_id,pedido_id) REFERENCES pedido_puestos(id,pedido_id)
);
CREATE TABLE mensajes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_id bigint NOT NULL REFERENCES pedidos(id),
 remitente_id bigint NOT NULL REFERENCES usuarios(id), destinatario_id bigint NOT NULL REFERENCES usuarios(id),
 texto text NOT NULL CHECK (length(trim(texto)) > 0),
 enviado_en timestamptz NOT NULL DEFAULT now(), leido_en timestamptz
);
CREATE TABLE resenas_puesto (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pedido_puesto_id bigint NOT NULL UNIQUE, pedido_id bigint NOT NULL, comprador_id bigint NOT NULL,
 estrellas smallint NOT NULL CHECK (estrellas BETWEEN 1 AND 5), comentario text,
 creado_en timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (pedido_puesto_id,pedido_id) REFERENCES pedido_puestos(id,pedido_id),
 FOREIGN KEY (pedido_id,comprador_id) REFERENCES pedidos(id,comprador_id)
);
CREATE TABLE resenas_repartidor (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 entrega_id bigint NOT NULL UNIQUE, pedido_id bigint NOT NULL, comprador_id bigint NOT NULL,
 estrellas smallint NOT NULL CHECK (estrellas BETWEEN 1 AND 5), comentario text,
 creado_en timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (entrega_id,pedido_id) REFERENCES entregas(id,pedido_id),
 FOREIGN KEY (pedido_id,comprador_id) REFERENCES pedidos(id,comprador_id)
);
CREATE TABLE solicitudes_soporte (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 usuario_id bigint NOT NULL REFERENCES usuarios(id), pedido_id bigint REFERENCES pedidos(id),
 asunto varchar(150) NOT NULL, descripcion text,
 estado varchar(15) NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta','en_atencion','resuelta','cerrada')),
 responsable_id bigint REFERENCES usuarios(id),
 creado_en timestamptz NOT NULL DEFAULT now(), cerrado_en timestamptz
);

-- Cotizaciones publicadas: el importe queda congelado; corregir creando otra versión.
CREATE FUNCTION proteger_cotizacion() RETURNS trigger LANGUAGE plpgsql
 SET search_path = mimercadoplus, pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.estado <> 'borrador' THEN RAISE EXCEPTION 'La cotización debe iniciar como borrador'; END IF;
  RETURN NEW;
 END IF;
 IF OLD.estado='aceptada' THEN
  RAISE EXCEPTION 'Una cotización aceptada es inmutable';
 END IF;
 IF TG_OP='DELETE' THEN
  IF OLD.estado <> 'borrador' THEN RAISE EXCEPTION 'Solo se elimina una cotización borrador'; END IF;
  RETURN OLD;
 END IF;
 IF NEW.pedido_id <> OLD.pedido_id OR NEW.version <> OLD.version THEN
  RAISE EXCEPTION 'Pedido y versión son inmutables';
 END IF;
 IF OLD.estado <> 'borrador' AND
  (NEW.costo_envio <> OLD.costo_envio OR NEW.ganancia_repartidor <> OLD.ganancia_repartidor) THEN
  RAISE EXCEPTION 'Para cambiar importes, cree una nueva versión';
 END IF;
 IF NEW.estado <> OLD.estado AND NOT (
  (OLD.estado='borrador' AND NEW.estado IN ('enviada','reemplazada')) OR
  (OLD.estado='enviada' AND NEW.estado IN ('aceptada','rechazada','reemplazada'))
 ) THEN RAISE EXCEPTION 'Transición de cotización inválida'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cotizacion_inmutable BEFORE INSERT OR UPDATE OR DELETE ON cotizaciones
 FOR EACH ROW EXECUTE FUNCTION proteger_cotizacion();

CREATE FUNCTION proteger_lineas_cotizacion() RETURNS trigger LANGUAGE plpgsql
 SET search_path = mimercadoplus, pg_temp AS $$
DECLARE ids bigint[]; cid bigint; estado_actual text;
BEGIN
 IF TG_TABLE_NAME='cotizacion_puestos' THEN
  IF TG_OP='INSERT' THEN ids := ARRAY[NEW.cotizacion_id];
  ELSIF TG_OP='DELETE' THEN ids := ARRAY[OLD.cotizacion_id];
  ELSE ids := ARRAY[OLD.cotizacion_id,NEW.cotizacion_id]; END IF;
 ELSE
  IF TG_OP='INSERT' THEN
   SELECT ARRAY[cotizacion_id] INTO ids FROM cotizacion_puestos WHERE id=NEW.cotizacion_puesto_id;
  ELSIF TG_OP='DELETE' THEN
   SELECT ARRAY[cotizacion_id] INTO ids FROM cotizacion_puestos WHERE id=OLD.cotizacion_puesto_id;
  ELSE
   SELECT array_agg(DISTINCT cotizacion_id ORDER BY cotizacion_id) INTO ids
    FROM cotizacion_puestos WHERE id IN (OLD.cotizacion_puesto_id,NEW.cotizacion_puesto_id);
  END IF;
 END IF;
 FOR cid IN SELECT DISTINCT unnest(ids) ORDER BY 1 LOOP
  SELECT estado INTO estado_actual FROM cotizaciones WHERE id=cid FOR UPDATE;
  IF estado_actual <> 'borrador' THEN
   RAISE EXCEPTION 'La cotización publicada no permite modificar líneas: cree otra versión';
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE TRIGGER proteger_puestos_cotizados BEFORE INSERT OR UPDATE OR DELETE ON cotizacion_puestos
 FOR EACH ROW EXECUTE FUNCTION proteger_lineas_cotizacion();
CREATE TRIGGER proteger_detalles_cotizados BEFORE INSERT OR UPDATE OR DELETE ON cotizacion_detalles
 FOR EACH ROW EXECUTE FUNCTION proteger_lineas_cotizacion();

CREATE FUNCTION validar_entrega() RETURNS trigger LANGUAGE plpgsql
 SET search_path = mimercadoplus, pg_temp AS $$
DECLARE autorizado_actual boolean; disponible_actual boolean; fin_actual timestamptz; usuario_estado text;
BEGIN
 IF TG_OP='INSERT' OR NEW.repartidor_mercado_id IS DISTINCT FROM OLD.repartidor_mercado_id THEN
  SELECT rm.autorizado,rm.disponible,rm.fin_en,u.estado
   INTO autorizado_actual,disponible_actual,fin_actual,usuario_estado
   FROM repartidor_mercados rm JOIN usuarios u ON u.id=rm.repartidor_id
   WHERE rm.id=NEW.repartidor_mercado_id FOR UPDATE OF rm;
  IF NOT COALESCE(autorizado_actual,false) OR NOT COALESCE(disponible_actual,false)
   OR fin_actual IS NOT NULL OR usuario_estado IS DISTINCT FROM 'activo' THEN
   RAISE EXCEPTION 'El repartidor debe estar activo, autorizado y disponible';
  END IF;
 END IF;
 IF NEW.estado IN ('en_camino','entregada') THEN
  -- El backend también debe bloquear el pedido al crear/modificar paradas.
  IF NOT EXISTS (SELECT 1 FROM cotizaciones WHERE pedido_id=NEW.pedido_id AND estado='aceptada') THEN
   RAISE EXCEPTION 'El cliente debe aceptar el precio final';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pedido_puestos WHERE pedido_id=NEW.pedido_id AND estado NOT IN ('rechazado','cancelado'))
   OR EXISTS (
    SELECT 1 FROM pedido_puestos pp WHERE pp.pedido_id=NEW.pedido_id
     AND pp.estado NOT IN ('rechazado','cancelado')
     AND NOT EXISTS (SELECT 1 FROM entrega_paradas ep WHERE ep.entrega_id=NEW.id
      AND ep.pedido_puesto_id=pp.id AND ep.recogido_en IS NOT NULL)
   ) THEN RAISE EXCEPTION 'Falta recoger en uno o más puestos'; END IF;
 END IF;
 IF NEW.estado='entregada' AND (NEW.codigo_validado_en IS NULL OR NEW.entregada_en IS NULL) THEN
  RAISE EXCEPTION 'Valide el código y registre la hora de entrega';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER entrega_validada BEFORE INSERT OR UPDATE ON entregas
 FOR EACH ROW EXECUTE FUNCTION validar_entrega();

-- Índices operativos; PK y UNIQUE ya crean sus propios índices.
CREATE INDEX puestos_mercado_categoria ON puestos(mercado_id,categoria_id);
CREATE INDEX puestos_vendedor ON puestos(vendedor_id);
CREATE INDEX productos_puesto ON productos(puesto_id);
CREATE INDEX pedidos_comprador_fecha ON pedidos(comprador_id,creado_en DESC);
CREATE INDEX pedidos_mercado_estado ON pedidos(mercado_id,estado);
CREATE INDEX pedido_puestos_puesto_estado ON pedido_puestos(puesto_id,estado);
CREATE INDEX pedido_detalles_subpedido ON pedido_detalles(pedido_puesto_id);
CREATE INDEX entregas_repartidor_estado ON entregas(repartidor_mercado_id,estado);
CREATE INDEX historial_pedido_fecha ON historial_estados(pedido_id,creado_en);
CREATE INDEX mensajes_pedido_fecha ON mensajes(pedido_id,enviado_en);
CREATE INDEX pagos_pedido ON pagos(pedido_id);
CREATE INDEX soporte_usuario ON solicitudes_soporte(usuario_id);

COMMIT;

-- 3. DATOS: CATÁLOGO DEL EQUIPO Y CUENTAS DE PRUEBA ----------------------
BEGIN;
SET LOCAL search_path TO mimercadoplus, public;


-- usuarios: 38 filas
INSERT INTO usuarios (id, nombres, apellido_paterno, apellido_materno, celular, correo, password_hash, estado, fecha_nacimiento, letra_grande, sonido, vibracion, creado_en) OVERRIDING SYSTEM VALUE VALUES
(1, 'Rosa', 'Quispe', NULL, '910000001', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$aDZvQ3VBYnlrVDNiYTdHaXdvQnZ6TQ$mcpA5mN+iFO/WU3iyVXy62JIDyz1iGKvfiavDZ/vYAQ', 'activo', NULL, false, true, true, '2026-11-11 02:57:11.149575+00:00'),
(2, 'Samuel', 'Enrique', NULL, '910000002', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$WXo0TVoxN1J5WkxVQUtvbWllNWxRNQ$OL0dBaF26bj8/qf3WGCmI7maeGu6VU+lzTKv1MVORCc', 'activo', NULL, false, true, true, '2026-11-11 02:57:12.405951+00:00'),
(3, 'Julio', 'Vega', NULL, '910000003', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$b2FQc052aDJFZzhYOWZEaUtvOE5NTA$HbpNSculuCyJENSThBAfRjs8nSnIOk7X+4RuQL+xJpA', 'activo', NULL, false, true, true, '2026-11-11 02:57:13.651254+00:00'),
(4, 'Joel', 'Sánchez', NULL, '910000004', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$OW50czdFa0hIbHkybmVmRUdvR1YwQQ$1cmQ34ljl3iQujqSv9NLR5pqMluPiwfjk5ccwXnDEOM', 'activo', NULL, false, true, true, '2026-11-11 02:57:14.896422+00:00'),
(5, 'Carmen', 'Flores', NULL, '910000005', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$WmlSS2lpendKMlZOOFZMVzJkbUJMUg$MUwEoHmv5cTad6Q10j/iugf/pZFJp7ygGWc2UaS0pbk', 'activo', NULL, false, true, true, '2026-11-11 02:57:16.146028+00:00'),
(6, 'Luis', 'Ramos', NULL, '910000006', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$UTFHZTFzYnJXUTZ0WHZrNFIzSU5Jcg$k8fflLyYNoSRgzT5VFmFUEFaxRTsQeVXd8g0yGWy2PQ', 'activo', NULL, false, true, true, '2026-11-11 02:57:17.402563+00:00'),
(7, 'Mary', 'Condori', NULL, '910000007', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$UTdRMFJvQ1g1c2JmSklubHUyZGpTbg$MkrtTVXxOR5LrvDVLcmeI6hLC2UuTenM92D/NI9fNEk', 'activo', NULL, false, true, true, '2026-11-11 02:57:18.647468+00:00'),
(8, 'Hugo', 'Mamani', NULL, '910000008', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$V0JCeXRDeTZQY3ZRMWZqYmN6ZjhObg$mHm9kQHnXgZv4krJQAJv5xlIC5dID4DgyUw5GOUbQR4', 'activo', NULL, false, true, true, '2026-11-11 02:57:19.889082+00:00'),
(9, 'Elías', 'Ríos', NULL, '910000009', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$MWxvaVQ1VEdneVA3eE9XUldOUENmTg$B5NEHces++sVNPG/9XWfo0Bnj/I1u33QYipqkwAC4+c', 'activo', NULL, false, true, true, '2026-11-11 02:57:21.135155+00:00'),
(10, 'Teresa', 'Huamán', NULL, '910000010', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$R3hrT21hQm00T1ZmMFZJU1NINnRINg$+qbaCtOB9BHwZ3QJ/ilCKLnXgvFT/S6mT2snowxGdbs', 'activo', NULL, false, true, true, '2026-11-11 02:57:22.386747+00:00'),
(11, 'Pilar', 'Soto', NULL, '910000011', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$RnFHdERQaTR2aDhlbWMzMVNIaGlvYg$0XtfSC4apoQAVSC+MQ2fk42SxTcDjxzp7EaPSzTe4iQ', 'activo', NULL, false, true, true, '2026-11-11 02:57:23.628599+00:00'),
(12, 'Walter', 'Vega', NULL, '910000012', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$RDl0RHBpM3I0ZThEYWpGSUh6aDRSRA$5vSTWCfr9M50FbHuZ9KA59hrZC5C52mcLK/1vB16WOM', 'activo', NULL, false, true, true, '2026-11-11 02:57:24.883627+00:00'),
(13, 'Raúl', 'Paredes', NULL, '910000013', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$d0JmVVVBdURWektEdk5hNmVHNWkweg$ZKYXDR6w/AdD+mYib4JUHAkMHi5GiQSb/yIpRDvpl1M', 'activo', NULL, false, true, true, '2026-11-11 02:57:26.127190+00:00'),
(14, 'Justiniano', 'Choque', NULL, '910000014', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$VzREcTl3clY0bGtyMTlNYU1kODg0dQ$3Sd6xK+dG13yj2UoN6qarqC2W9+r88zN/f8kc5ZEqxw', 'activo', NULL, false, true, true, '2026-11-11 02:57:27.369838+00:00'),
(15, 'Clara', 'Quispe', NULL, '910000015', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$VkhZRnhRNHVKUkZFb3dSOXRmN3RXUQ$yXzmqlGOXuFs3zoDeDFBV2hxJpVR6+kkyXxnYw8063k', 'activo', NULL, false, true, true, '2026-11-11 02:57:28.618432+00:00'),
(16, 'Esteban', 'Ccoyllo', NULL, '910000016', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$aWZDeHhQUkFld0o0eG5QdnBOYUdmaw$NjhjKQBq1dHk2xb2EFWCnVzSV0k7vWz2TeA9AXoLhNw', 'activo', NULL, false, true, true, '2026-11-11 02:57:29.866073+00:00'),
(17, 'Sara', 'Tintaya', NULL, '910000017', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$RTh3Sk10OU9aRFp3ZUpZQUQ1R2pvMg$77HhoxFV1Ds8rWO4gr3w+ZMKwYjTgkvVMvxzRo3Ir84', 'activo', NULL, false, true, true, '2026-11-11 02:57:31.113675+00:00'),
(18, 'Bertha', 'Mendoza', NULL, '910000018', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$cWdHWTNZbFNtZ1JjVDU0RGpTdTZBdw$8+ds3IwA84iCk0F6izHKnOOS/MWATaxHCV8O05ujrfI', 'activo', NULL, false, true, true, '2026-11-11 02:57:32.364560+00:00'),
(19, 'Carlos', 'Alva', NULL, '910000019', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$Z2NGUlNlMXR0T0EwdDhvTkVxekh5Sg$V7SwLKMyBctZNap5HPD5U1jFf0oyMsXs145lmj979m0', 'activo', NULL, false, true, true, '2026-11-11 02:57:33.607153+00:00'),
(20, 'Humberto', 'Solís', NULL, '910000020', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$YVcyd3luUTBhMmk4SU95YTJnZkYyOA$2gtJVJean8Dk8sh0kNzhs2i9Eq5F+mA5Uro7UsVH4cQ', 'activo', NULL, false, true, true, '2026-11-11 02:57:34.853622+00:00'),
(21, 'Marina', 'Espinoza', NULL, '910000021', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$eGNXMmxYWVVpMm9za1FSc1Q2bXhJbQ$ufVOY8iXCU7Jhn8YxBXnmGO0AHR7Zxep9WxwdluPDiM', 'activo', NULL, false, true, true, '2026-11-11 02:57:36.107498+00:00'),
(22, 'Félix', 'Tello', NULL, '910000022', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$U1E5Ym5sbzVFcWxJM3pzVFlqRWN6Vg$TpcRtPnngzFGg7HlrFHKVstZ6R6d63RXCXW79YKSv2U', 'activo', NULL, false, true, true, '2026-11-11 02:57:37.357640+00:00'),
(23, 'Teodora', 'Huamaní', NULL, '910000023', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$REgzMmtOaEZYQXZBVGlnQ3hxbWRUQw$3BEIojhNUMgIFXIL8whYW0bWBFqplLgsd8V2DZtqgfw', 'activo', NULL, false, true, true, '2026-11-11 02:57:38.607176+00:00'),
(24, 'Ricardo', 'Paredes', NULL, '910000024', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$U09ERDU1Tk1ZVWV5UXEyT1NJbDFReA$cW4Gn6kyWAWh1QesV7nZ6GrGGO37VyFiGkyHGX4Vsl8', 'activo', NULL, false, true, true, '2026-11-11 02:57:39.863231+00:00'),
(25, 'Enrique', 'Cáceda', NULL, '910000025', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$c21TWFZzdHJiNUZNU3R3MW1NaVlneg$wQn9g+Yd7JX+H68r83oyyiiQeSZUAX5ax1X0y6a3mzA', 'activo', NULL, false, true, true, '2026-11-11 02:57:41.104243+00:00'),
(26, 'Yolanda', 'Flores', NULL, '910000026', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$MDllak5HZFhld2hEMnFpTlVid1NRZw$84NQ96WVcJpZMoPDhhmc5dYG8ouY5NPiptpUjJ5UId8', 'activo', NULL, false, true, true, '2026-11-11 02:57:42.349131+00:00'),
(27, 'Jorge', 'Ortiz', NULL, '910000027', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$ZjhCM3MxbFR3dzdUVXhJeFN5ajNtNA$ukoM/SQ9t9EisuZqP/z4b5ybtvQ3aTeYsnYKKv2DNmw', 'activo', NULL, false, true, true, '2026-11-11 02:57:43.603964+00:00'),
(28, 'Lucía', 'Benavides', NULL, '910000028', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$VkNZNGpTeW9ldFcyVFJTbTJQY2dlcQ$Z6b7cO5J/6jzUaNvUBi8G/AJFKLuU/394PkI5zuiYYI', 'activo', NULL, false, true, true, '2026-11-11 02:57:44.860104+00:00'),
(29, 'José', 'Gálvez', NULL, '910000029', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$SGpyZGlYMmJaclZYRmFTVk1zc2dlQg$uGWblNgwUxCp5WTgchwX4crrh/a2sFETGoMnZsdfM3k', 'activo', NULL, false, true, true, '2026-11-11 02:57:46.110327+00:00'),
(30, 'Nicanor', 'Rojas', NULL, '910000030', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$VWxPcFBOR0VleVhvdGN1bjR1V3Rybw$Q9JlYrqBJ8+U5qhZYKM9MKalH6W+1+3vqp8/YmluiqU', 'activo', NULL, false, true, true, '2026-11-11 02:57:47.354566+00:00'),
(31, 'Pedro', 'Marín', NULL, '910000031', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$Y3R0VXRNYkdxMFY4NEF6ZmsxT3V1Vg$lJJlF9IoQiKb1MkPEt4kiChoe7TMN4pbT1Q4tvzHVk4', 'activo', NULL, false, true, true, '2026-11-11 02:57:48.603096+00:00'),
(32, 'Milagros', 'Palomino', NULL, '910000032', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$dnhGc0VscWFFTzQ3RWRoT01nRXpFVg$6v+gPQ8BxJaH0W/SR5WLIKnYWKh4gQSLLSjRLqxFSq8', 'activo', NULL, false, true, true, '2026-11-11 02:57:49.848578+00:00'),
(33, 'Alfonso', 'Zavala', NULL, '910000033', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$djhvUDJhR1BtcXJ6WEdQOXhVRmdJdg$5xrcNaKl3Ct3Q1m79oQ9Nla6kjhi60zLV/L5//tq9f8', 'activo', NULL, false, true, true, '2026-11-11 02:57:51.108159+00:00'),
(34, 'Elena', 'Barrientos', NULL, '910000034', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$eWZZckFLNkhwc0Vqb3RuQVZONTgxRw$CmOJVdN1Jl0VNaGWu0XR2mgybklVaoWWy2KQmfSqO10', 'activo', NULL, false, true, true, '2026-11-11 02:57:52.363326+00:00'),
(35, 'Rosa', NULL, NULL, '900000011', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$VDF4WTVpOFNzUVRicmhxTjl1QVR2SQ$/Lb2D7gYtydDE42tBTgUqLxhqbLb2wY8eQCfjKqJ5dA', 'activo', NULL, false, true, true, '2026-11-11 02:58:23.452581+00:00'),
(36, 'Julio', NULL, NULL, '900000012', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$RWFaejN5VlVyTndSNUg5UENZVlNFSw$Pa2HIL0yq+xoi2UrGZFbgyUssTJAQJtbfJU6RqzyKG8', 'activo', NULL, false, true, true, '2026-11-11 02:58:24.320481+00:00'),
(37, 'María', NULL, NULL, '900000001', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$NXNUMGZOVFNFZzlWeUFxQ3RMRzd1Nw$CBrZrTIYG6L343XaGZakCnFQW4E4yxYAIWoJrXQs1is', 'activo', NULL, false, true, true, '2026-11-11 02:58:28.090081+00:00'),
(38, 'Ernesto', NULL, NULL, '900000090', NULL, 'argon2$argon2id$v=19$m=102400,t=2,p=8$TGdybVJtYVF0TEdpZXZxRXJEQVNrSg$jqBfHYOsm861WHV7qujTQou1CDJrfon4+JSpilMSBUQ', 'activo', NULL, false, true, true, '2026-11-11 02:58:29.372112+00:00');
SELECT setval(pg_get_serial_sequence('mimercadoplus.usuarios', 'id'), (SELECT max(id) FROM usuarios));

-- usuario_roles: 38 filas
INSERT INTO usuario_roles (usuario_id, rol_codigo) VALUES
(1, 'vendedor'),
(2, 'vendedor'),
(3, 'vendedor'),
(4, 'vendedor'),
(5, 'vendedor'),
(6, 'vendedor'),
(7, 'vendedor'),
(8, 'vendedor'),
(9, 'vendedor'),
(10, 'vendedor'),
(11, 'vendedor'),
(12, 'vendedor'),
(13, 'vendedor'),
(14, 'vendedor'),
(15, 'vendedor'),
(16, 'vendedor'),
(17, 'vendedor'),
(18, 'vendedor'),
(19, 'vendedor'),
(20, 'vendedor'),
(21, 'vendedor'),
(22, 'vendedor'),
(23, 'vendedor'),
(24, 'vendedor'),
(25, 'vendedor'),
(26, 'vendedor'),
(27, 'vendedor'),
(28, 'vendedor'),
(29, 'vendedor'),
(30, 'vendedor'),
(31, 'vendedor'),
(32, 'vendedor'),
(33, 'vendedor'),
(34, 'vendedor'),
(35, 'vendedor'),
(36, 'vendedor'),
(37, 'comprador'),
(38, 'repartidor');

-- mercados: 9 filas
INSERT INTO mercados (id, nombre, direccion, distrito, provincia, departamento, latitud, longitud, estado, creado_en) OVERRIDING SYSTEM VALUE VALUES
(1, 'Mercado N° 1 de Surquillo', 'Surquillo, Lima', 'Surquillo', 'Lima', 'Lima', -12.113000, -77.020000, 'activo', '2026-11-11 02:57:06.533839+00:00'),
(2, 'Mercado Real Plaza APROMEC', 'Av Nicolás Ayllón', 'Ate', 'Lima', 'Lima', -12.026267, -76.922480, 'activo', '2026-11-11 02:57:07.040513+00:00'),
(3, 'Plaza Vitarte', 'Av Nicolás Ayllón', 'Ate', 'Lima', 'Lima', -12.025720, -76.922064, 'activo', '2026-11-11 02:57:07.542514+00:00'),
(4, 'Mercado Modelo de Vitarte', 'Av Nicolás Ayllón', 'Ate', 'Lima', 'Lima', -12.025615, -76.920248, 'activo', '2026-11-11 02:57:08.049049+00:00'),
(5, 'Mercado Venezuela', 'Av. Venezuela 3176, Lima 15081', 'Cercado de Lima', 'Lima', 'Lima', -12.058950, -77.076050, 'activo', '2026-11-11 02:57:08.551094+00:00'),
(6, 'Mercado Cooperativa Elio', 'Roberto Thorndike Galup 1423, Lima 15081', 'Cercado de Lima', 'Lima', 'Lima', -12.055000, -77.068611, 'activo', '2026-11-11 02:57:09.054475+00:00'),
(7, 'Mercado Colonial', 'Av. Óscar R. Benavides (Ex Colonial) 5405', 'Cercado de Lima', 'Lima', 'Lima', -12.051939, -77.082725, 'activo', '2026-11-11 02:57:09.555505+00:00'),
(8, 'Mercado Unidad Vecinal 3', 'Av. Unidad Vecinal 3', 'Cercado de Lima', 'Lima', 'Lima', -12.051110, -77.078420, 'activo', '2026-11-11 02:57:10.056531+00:00'),
(9, 'Mercado Pando', 'Calle José de la Riva Agüero 380, Urb. Pando', 'San Miguel', 'Lima', 'Lima', -12.061730, -77.086430, 'activo', '2026-11-11 02:57:10.559554+00:00');
SELECT setval(pg_get_serial_sequence('mimercadoplus.mercados', 'id'), (SELECT max(id) FROM mercados));

-- puestos: 36 filas
INSERT INTO puestos (id, mercado_id, vendedor_id, rol_vendedor, categoria_id, nombre, numero, descripcion, foto_url, contacto_billetera, qr_billetera_url, abierto, estado, creado_en) OVERRIDING SYSTEM VALUE VALUES
(1, 1, 1, 'vendedor', 1, 'Doña Rosa Verdulería', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:11.965111+00:00'),
(2, 1, 2, 'vendedor', 4, 'Mariscos Enrique', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:13.209230+00:00'),
(3, 1, 3, 'vendedor', 2, 'Carnicería Huancayo', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:14.455253+00:00'),
(4, 1, 4, 'vendedor', 1, 'Hermanos Sánchez', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:15.700180+00:00'),
(5, 1, 5, 'vendedor', 3, 'Abarrotes Doña Carmen', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:16.961055+00:00'),
(6, 1, 6, 'vendedor', 2, 'Granja Don Lucho', NULL, NULL, NULL, NULL, NULL, false, 'activo', '2026-11-11 02:57:18.209469+00:00'),
(7, 2, 7, 'vendedor', 1, 'Frutas Mary', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:19.451864+00:00'),
(8, 2, 8, 'vendedor', 2, 'Carnes El Cuzqueño', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:20.696645+00:00'),
(9, 2, 9, 'vendedor', 4, 'Pescadería Neptuno', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:21.947006+00:00'),
(10, 2, 10, 'vendedor', 3, 'Abarrotes Central', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:23.190934+00:00'),
(11, 3, 11, 'vendedor', 1, 'Verduras Doña Pilar', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:24.439112+00:00'),
(12, 3, 12, 'vendedor', 4, 'Mariscos del Pacífico', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:25.688681+00:00'),
(13, 3, 13, 'vendedor', 2, 'Carnicería Magdalena', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:26.931783+00:00'),
(14, 4, 14, 'vendedor', 1, 'Verdulería Choque', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:28.174401+00:00'),
(15, 4, 15, 'vendedor', 3, 'Abarrotes El Chanchamayano', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:29.426313+00:00'),
(16, 4, 16, 'vendedor', 2, 'Carnes El Torito de Pucará', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:30.673802+00:00'),
(17, 4, 17, 'vendedor', 4, 'Pescados y Mariscos Sarita', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:31.923426+00:00'),
(18, 5, 18, 'vendedor', 1, 'Frutas y Verduras Doña Bertha', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:33.168131+00:00'),
(19, 5, 19, 'vendedor', 3, 'Distribuidora San Marquitos', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:34.411667+00:00'),
(20, 5, 20, 'vendedor', 2, 'Carnicería Fiel y Sabor', NULL, NULL, NULL, NULL, NULL, false, 'activo', '2026-11-11 02:57:35.660500+00:00'),
(21, 5, 21, 'vendedor', 4, 'Terminal Pesquero El Puerto', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:36.911079+00:00'),
(22, 6, 22, 'vendedor', 3, 'Abarrotes El Sol del Rímac', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:38.163664+00:00'),
(23, 6, 23, 'vendedor', 1, 'Verduras De Mi Tierra', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:39.416215+00:00'),
(24, 6, 24, 'vendedor', 2, 'Cortes Finos Elio', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:40.666191+00:00'),
(25, 7, 25, 'vendedor', 4, 'El Rey de los Mariscos', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:41.907762+00:00'),
(26, 7, 26, 'vendedor', 1, 'Verdulería La Chacra a tu Mesa', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:43.159918+00:00'),
(27, 7, 27, 'vendedor', 3, 'Bodega Colonial Express', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:44.418083+00:00'),
(28, 7, 28, 'vendedor', 2, 'Avícola San Fernando del Norte', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:45.670813+00:00'),
(29, 8, 29, 'vendedor', 3, 'Abarrotes Don Pepe', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:46.914029+00:00'),
(30, 8, 30, 'vendedor', 1, 'El Caserito de la UV3', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:48.163584+00:00'),
(31, 8, 31, 'vendedor', 4, 'Pescadería San Pedro', NULL, NULL, NULL, NULL, NULL, false, 'activo', '2026-11-11 02:57:49.410433+00:00'),
(32, 9, 32, 'vendedor', 1, 'Frutería San Miguelito', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:50.664105+00:00'),
(33, 9, 33, 'vendedor', 2, 'Carnicería El Buen Corte', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:51.913179+00:00'),
(34, 9, 34, 'vendedor', 3, 'Minimarket Pando Gourmet', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:57:53.172596+00:00'),
(35, 8, 35, 'vendedor', 1, 'Verduras Rosa', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:58:25.151659+00:00'),
(36, 8, 36, 'vendedor', 2, 'Carnicería Julio', NULL, NULL, NULL, NULL, NULL, true, 'activo', '2026-11-11 02:58:25.565680+00:00');
SELECT setval(pg_get_serial_sequence('mimercadoplus.puestos', 'id'), (SELECT max(id) FROM puestos));

-- productos: 73 filas
INSERT INTO productos (id, puesto_id, categoria_id, nombre, descripcion, foto_url, unidad_codigo, precio_unitario, disponible, stock, activo, creado_en) OVERRIDING SYSTEM VALUE VALUES
(1, 1, NULL, 'Tomate', NULL, NULL, 'kg', 4.00, true, 50.000, true, '2026-11-11 02:57:53.579106+00:00'),
(2, 1, NULL, 'Papa amarilla', NULL, NULL, 'kg', 3.50, true, 50.000, true, '2026-11-11 02:57:53.984617+00:00'),
(3, 1, NULL, 'Limón', NULL, NULL, 'kg', 8.00, true, 50.000, true, '2026-11-11 02:57:54.391616+00:00'),
(4, 1, NULL, 'Cebolla roja', NULL, NULL, 'kg', 3.00, true, 50.000, true, '2026-11-11 02:57:54.794772+00:00'),
(5, 1, NULL, 'Culantro', NULL, NULL, 'atado', 1.00, true, 50.000, true, '2026-11-11 02:57:55.196398+00:00'),
(6, 1, NULL, 'Zanahoria', NULL, NULL, 'kg', 2.50, false, 50.000, true, '2026-11-11 02:57:55.601916+00:00'),
(7, 2, NULL, 'Bonito', NULL, NULL, 'kg', 14.00, true, 50.000, true, '2026-11-11 02:57:56.004098+00:00'),
(8, 2, NULL, 'Jurel', NULL, NULL, 'kg', 9.00, true, 50.000, true, '2026-11-11 02:57:56.408495+00:00'),
(9, 3, NULL, 'Pollo entero', NULL, NULL, 'kg', 10.00, true, 50.000, true, '2026-11-11 02:57:56.814524+00:00'),
(10, 3, NULL, 'Carne molida', NULL, NULL, 'kg', 22.00, true, 50.000, true, '2026-11-11 02:57:57.220762+00:00'),
(11, 3, NULL, 'Bistec', NULL, NULL, 'kg', 28.00, true, 50.000, true, '2026-11-11 02:57:57.625761+00:00'),
(12, 4, NULL, 'Plátano de seda', NULL, NULL, 'kg', 3.80, true, 50.000, true, '2026-11-11 02:57:58.028761+00:00'),
(13, 4, NULL, 'Palta fuerte', NULL, NULL, 'kg', 8.50, true, 50.000, true, '2026-11-11 02:57:58.433882+00:00'),
(14, 5, NULL, 'Arroz extra', NULL, NULL, 'kg', 4.20, true, 50.000, true, '2026-11-11 02:57:58.836565+00:00'),
(15, 5, NULL, 'Aceite vegetal', NULL, NULL, 'litro', 9.50, true, 50.000, true, '2026-11-11 02:57:59.241548+00:00'),
(16, 5, NULL, 'Huevos', NULL, NULL, 'kg', 7.50, true, 50.000, true, '2026-11-11 02:57:59.644248+00:00'),
(17, 6, NULL, 'Gallina', NULL, NULL, 'kg', 12.00, true, 50.000, true, '2026-11-11 02:58:00.048782+00:00'),
(18, 7, NULL, 'Mandarina', NULL, NULL, 'kg', 4.50, true, 50.000, true, '2026-11-11 02:58:00.453781+00:00'),
(19, 7, NULL, 'Piña', NULL, NULL, 'unidad', 6.00, true, 50.000, true, '2026-11-11 02:58:00.866943+00:00'),
(20, 8, NULL, 'Pollo entero', NULL, NULL, 'kg', 10.50, true, 50.000, true, '2026-11-11 02:58:01.269456+00:00'),
(21, 9, NULL, 'Trucha', NULL, NULL, 'kg', 18.00, true, 50.000, true, '2026-11-11 02:58:01.670360+00:00'),
(22, 9, NULL, 'Liza', NULL, NULL, 'kg', 12.00, true, 50.000, true, '2026-11-11 02:58:02.074033+00:00'),
(23, 10, NULL, 'Azúcar rubia', NULL, NULL, 'kg', 3.80, true, 50.000, true, '2026-11-11 02:58:02.486006+00:00'),
(24, 10, NULL, 'Leche evaporada', NULL, NULL, 'unidad', 4.20, true, 50.000, true, '2026-11-11 02:58:02.897015+00:00'),
(25, 11, NULL, 'Brócoli', NULL, NULL, 'kg', 5.00, true, 50.000, true, '2026-11-11 02:58:03.301529+00:00'),
(26, 11, NULL, 'Lechuga orgánica', NULL, NULL, 'unidad', 2.50, true, 50.000, true, '2026-11-11 02:58:03.716239+00:00'),
(27, 12, NULL, 'Mixtura de mariscos', NULL, NULL, 'kg', 25.00, true, 50.000, true, '2026-11-11 02:58:04.120239+00:00'),
(28, 12, NULL, 'Choros', NULL, NULL, 'kg', 6.00, true, 50.000, true, '2026-11-11 02:58:04.529778+00:00'),
(29, 13, NULL, 'Chuleta de cerdo', NULL, NULL, 'kg', 16.50, true, 50.000, true, '2026-11-11 02:58:04.934425+00:00'),
(30, 13, NULL, 'Panceta', NULL, NULL, 'kg', 22.00, true, 50.000, true, '2026-11-11 02:58:05.345434+00:00'),
(31, 14, NULL, 'Camote amarillo', NULL, NULL, 'kg', 2.50, true, 50.000, true, '2026-11-11 02:58:05.750121+00:00'),
(32, 14, NULL, 'Choclo serrano', NULL, NULL, 'unidad', 1.50, true, 50.000, true, '2026-11-11 02:58:06.157123+00:00'),
(33, 15, NULL, 'Café molido pasita', NULL, NULL, 'unidad', 15.00, true, 50.000, true, '2026-11-11 02:58:06.558889+00:00'),
(34, 15, NULL, 'Menestra lenteja', NULL, NULL, 'kg', 6.50, true, 50.000, true, '2026-11-11 02:58:06.965246+00:00'),
(35, 16, NULL, 'Lomo de res', NULL, NULL, 'kg', 34.00, true, 50.000, true, '2026-11-11 02:58:07.370761+00:00'),
(36, 16, NULL, 'Hígado de res', NULL, NULL, 'kg', 14.00, true, 50.000, true, '2026-11-11 02:58:07.772280+00:00'),
(37, 17, NULL, 'Caballa', NULL, NULL, 'kg', 8.00, true, 50.000, true, '2026-11-11 02:58:08.174297+00:00'),
(38, 17, NULL, 'Calamar entero', NULL, NULL, 'kg', 24.00, true, 50.000, true, '2026-11-11 02:58:08.580280+00:00'),
(39, 18, NULL, 'Maracuyá', NULL, NULL, 'kg', 4.50, true, 50.000, true, '2026-11-11 02:58:08.982193+00:00'),
(40, 18, NULL, 'Manzana Israel', NULL, NULL, 'kg', 5.50, true, 50.000, true, '2026-11-11 02:58:09.388704+00:00'),
(41, 19, NULL, 'Fideos spaghetti', NULL, NULL, 'kg', 5.00, true, 50.000, true, '2026-11-11 02:58:09.791154+00:00'),
(42, 19, NULL, 'Atún en conserva', NULL, NULL, 'unidad', 4.80, true, 50.000, true, '2026-11-11 02:58:10.201152+00:00'),
(43, 20, NULL, 'Malaya de res', NULL, NULL, 'kg', 21.00, true, 50.000, true, '2026-11-11 02:58:10.603153+00:00'),
(44, 21, NULL, 'Corvina', NULL, NULL, 'kg', 45.00, true, 50.000, true, '2026-11-11 02:58:11.005421+00:00'),
(45, 21, NULL, 'Filete de perico', NULL, NULL, 'kg', 22.00, true, 50.000, true, '2026-11-11 02:58:11.409419+00:00'),
(46, 22, NULL, 'Aceite de oliva', NULL, NULL, 'litro', 32.00, true, 50.000, true, '2026-11-11 02:58:11.811932+00:00'),
(47, 22, NULL, 'Sal yodada', NULL, NULL, 'kg', 1.80, true, 50.000, true, '2026-11-11 02:58:12.214661+00:00'),
(48, 23, NULL, 'Espinaca', NULL, NULL, 'atado', 2.00, true, 50.000, true, '2026-11-11 02:58:12.615792+00:00'),
(49, 23, NULL, 'Huacatay', NULL, NULL, 'atado', 1.00, true, 50.000, true, '2026-11-11 02:58:13.018028+00:00'),
(50, 24, NULL, 'Asado de tira', NULL, NULL, 'kg', 29.50, true, 50.000, true, '2026-11-11 02:58:13.420026+00:00'),
(51, 25, NULL, 'Pulpo fresco', NULL, NULL, 'kg', 38.00, true, 50.000, true, '2026-11-11 02:58:13.824024+00:00'),
(52, 25, NULL, 'Langostinos pelados', NULL, NULL, 'kg', 32.00, true, 50.000, true, '2026-11-11 02:58:14.227258+00:00'),
(53, 26, NULL, 'Espinaca fresca', NULL, NULL, 'atado', 1.80, true, 50.000, true, '2026-11-11 02:58:14.629890+00:00'),
(54, 26, NULL, 'Ajo molido puro', NULL, NULL, 'kg', 14.00, true, 50.000, true, '2026-11-11 02:58:15.030423+00:00'),
(55, 27, NULL, 'Frugos litro', NULL, NULL, 'litro', 5.50, true, 50.000, true, '2026-11-11 02:58:15.433423+00:00'),
(56, 27, NULL, 'Arroz integral', NULL, NULL, 'kg', 6.20, true, 50.000, true, '2026-11-11 02:58:15.836763+00:00'),
(57, 28, NULL, 'Pechuga de pollo', NULL, NULL, 'kg', 16.00, true, 50.000, true, '2026-11-11 02:58:16.239272+00:00'),
(58, 29, NULL, 'Detergente bolsa', NULL, NULL, 'unidad', 8.50, true, 50.000, true, '2026-11-11 02:58:16.641237+00:00'),
(59, 29, NULL, 'Vinagre blanco', NULL, NULL, 'litro', 3.50, true, 50.000, true, '2026-11-11 02:58:17.044170+00:00'),
(60, 30, NULL, 'Yuca amarilla', NULL, NULL, 'kg', 3.00, true, 50.000, true, '2026-11-11 02:58:17.449626+00:00'),
(61, 30, NULL, 'Ají amarillo', NULL, NULL, 'kg', 7.00, true, 50.000, true, '2026-11-11 02:58:17.853632+00:00'),
(62, 31, NULL, 'Cabrilla', NULL, NULL, 'kg', 26.00, false, 50.000, true, '2026-11-11 02:58:18.255158+00:00'),
(63, 32, NULL, 'Fresa San Juan', NULL, NULL, 'kg', 7.50, true, 50.000, true, '2026-11-11 02:58:18.658167+00:00'),
(64, 32, NULL, 'Papaya selva', NULL, NULL, 'kg', 4.00, true, 50.000, true, '2026-11-11 02:58:19.062687+00:00'),
(65, 33, NULL, 'Pata de res', NULL, NULL, 'kg', 9.00, true, 50.000, true, '2026-11-11 02:58:19.467199+00:00'),
(66, 33, NULL, 'Carne para guiso', NULL, NULL, 'kg', 24.00, true, 50.000, true, '2026-11-11 02:58:19.875089+00:00'),
(67, 34, NULL, 'Queso fresco andino', NULL, NULL, 'kg', 26.00, true, 50.000, true, '2026-11-11 02:58:20.277091+00:00'),
(68, 34, NULL, 'Mantequilla con sal', NULL, NULL, 'unidad', 5.20, true, 50.000, true, '2026-11-11 02:58:20.685091+00:00'),
(69, 35, NULL, 'Tomate', NULL, NULL, 'kg', 4.00, true, 48.000, true, '2026-11-11 02:58:25.978523+00:00'),
(70, 35, NULL, 'Papa amarilla', NULL, NULL, 'kg', 3.50, true, 50.000, true, '2026-11-11 02:58:26.393824+00:00'),
(71, 35, NULL, 'Limón', NULL, NULL, 'kg', 6.00, true, 50.000, true, '2026-11-11 02:58:26.813300+00:00'),
(72, 36, NULL, 'Pollo', NULL, NULL, 'kg', 10.00, true, 47.000, true, '2026-11-11 02:58:27.228301+00:00'),
(73, 36, NULL, 'Carne molida', NULL, NULL, 'kg', 22.00, true, 50.000, true, '2026-11-11 02:58:27.640699+00:00');
SELECT setval(pg_get_serial_sequence('mimercadoplus.productos', 'id'), (SELECT max(id) FROM productos));

-- repartidor_mercados: 1 filas
INSERT INTO repartidor_mercados (id, repartidor_id, rol_repartidor, mercado_id, movilidad, placa, descripcion_movilidad, autorizado, disponible, inicio_en, fin_en) OVERRIDING SYSTEM VALUE VALUES
(1, 38, 'repartidor', 8, 'bicicleta', NULL, NULL, true, true, '2026-11-11 02:58:30.201645+00:00', NULL);
SELECT setval(pg_get_serial_sequence('mimercadoplus.repartidor_mercados', 'id'), (SELECT max(id) FROM repartidor_mercados));

-- direcciones: 1 filas
INSERT INTO direcciones (id, comprador_id, rol_comprador, etiqueta, direccion, referencia, latitud, longitud, principal, activa) OVERRIDING SYSTEM VALUE VALUES
(1, 37, 'comprador', 'Casa', 'Av. Venezuela 3400, Lima', 'Portón verde', NULL, NULL, true, true);
SELECT setval(pg_get_serial_sequence('mimercadoplus.direcciones', 'id'), (SELECT max(id) FROM direcciones));

COMMIT;
