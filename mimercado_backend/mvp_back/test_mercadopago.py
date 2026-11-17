"""Contrato del piloto: red simulada y SQLite aislado, nunca Supabase."""
import hashlib
import hmac
from unittest.mock import Mock, patch

import requests
from django.db import connection
from django.test import TestCase, SimpleTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from . import mercadopago_pruebas as mp, tests as fixtures
from .authentication import issue_token
from .models import Cotizacion, Pedido, Pago, PedidoPuesto, Usuario, UsuarioRol
from . import test_reparto as reparto_fixtures

ORDER_ID = 'ORDTST01KS5AJ6HTK2HRQ3XJ3C2JCKP9'
URL = f'https://www.mercadopago.com.pe/checkout/v1/redirect?order_id={ORDER_ID}'
CONFIG = dict(MERCADOPAGO_PRUEBAS_ENABLED=True,
              MERCADOPAGO_TEST_ACCESS_TOKEN='credencial-ficticia-solo-tests',
              MERCADOPAGO_TEST_USER_ID='12345', MERCADOPAGO_RETURN_URL='',
              MERCADOPAGO_WEBHOOK_SECRET='firma-ficticia-solo-tests')


def order_data(reference):
    return dict(id=ORDER_ID, type='online', processing_mode='manual',
                currency='PEN', country_code='PER', user_id='12345',
                external_reference=reference, total_amount='24.00',
                total_paid_amount='0.00', status='created', status_detail='created',
                checkout_url=URL)


@override_settings(**CONFIG)
class MercadoPagoApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        fixtures.ApiTests.setUpTestData.__func__(cls)

    setUp = fixtures.ApiTests.setUp
    post = fixtures.ApiTests.post
    add = fixtures.ApiTests.add
    order = fixtures.ApiTests.order
    quoted_order = fixtures.ApiTests.quoted_order
    driver = reparto_fixtures.RepartoApiTests.driver
    auth = reparto_fixtures.RepartoApiTests.auth
    aceptar = reparto_fixtures.RepartoApiTests.aceptar
    recoger_todo = reparto_fixtures.RepartoApiTests.recoger_todo
    accion = reparto_fixtures.RepartoApiTests.accion

    def preparar(self):
        self.pedido = self.quoted_order()
        _, self.total, self.reference = mp.contexto(self.user, self.pedido)
        return order_data(self.reference)

    def checkout(self, **extra):
        return self.post('/api/pagos/mercadopago/checkout/', {'pedido_id': self.pedido, **extra})

    def estado(self):
        return self.client.get(f'/api/pagos/mercadopago/pedidos/{self.pedido}/estado/')

    def confirmar(self, **extra):
        return self.post('/api/pagos/mercadopago/confirmar/', {'pedido_id': self.pedido, **extra})

    def buscar_responde(self, api, data):
        api.side_effect = [{'data': [{'id': ORDER_ID, 'external_reference': self.reference}]}, data]

    def assert_sin_escrituras(self, queries):
        for query in queries:
            self.assertFalse(query['sql'].lstrip().upper().startswith(
                ('INSERT', 'UPDATE', 'DELETE', 'ALTER', 'CREATE')), query['sql'])

    @patch.object(mp, 'solicitud')
    def test_crea_desde_total_servidor_y_guarda_pendiente_sin_datos_personales(self, api):
        data = self.preparar()
        api.side_effect = [{'data': []}, data]
        with CaptureQueriesContext(connection) as queries:
            response = self.checkout(total_amount='0.01', comprador_id=self.seller.pk)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['monto_centavos'], 2400)
        self.assertTrue(response.data['registro_interno'])
        self.assertFalse(response.data['reparto_habilitado'])
        pago = Pago.objects.get(pedido_id=self.pedido)
        self.assertEqual(pago.estado, 'pendiente')
        self.assertEqual(pago.proveedor_transaccion_id, mp.PREFIJO_PAGO + ORDER_ID)
        sent = api.call_args.kwargs['body']
        self.assertEqual(sent['total_amount'], '24.00')
        self.assertEqual(sent['items'][0]['unit_price'], '24.00')
        self.assertNotIn('payer', sent)
        self.assertEqual(set(sent), {'type', 'processing_mode', 'total_amount', 'external_reference', 'items'})
        self.assertTrue(api.call_args.kwargs['clave'])

    @patch.object(mp, 'solicitud')
    def test_reutiliza_order_aprobada_y_registra_pago(self, api):
        data = self.preparar()
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        api.side_effect = [{'data': [{'id': ORDER_ID, 'external_reference': self.reference}]}, data]
        with CaptureQueriesContext(connection) as queries:
            response = self.checkout()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['aprobado_en_proveedor'])
        self.assertIsNone(response.data['checkout_url'])
        self.assertEqual([call.args[0] for call in api.call_args_list], ['GET', 'GET'])
        self.assertEqual(Pago.objects.filter(pedido_id=self.pedido, estado='aprobado').count(), 1)
        self.assertTrue(response.data['pago_interno_aprobado'])
        self.assertTrue(response.data['reparto_habilitado'])

    @patch.object(mp, 'solicitud')
    def test_get_solo_consulta_y_post_confirma_idempotente(self, api):
        data = self.preparar()
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        self.buscar_responde(api, data)
        with CaptureQueriesContext(connection) as queries:
            r = self.estado()
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.data['registro_interno'])
        self.assert_sin_escrituras(queries)
        for _ in range(2):
            self.buscar_responde(api, data)
            r = self.confirmar(estado='aprobado', monto='0.01')
            self.assertEqual(r.status_code, 200, r.data)
            self.assertTrue(r.data['pago_interno_aprobado'])
        self.assertEqual(Pago.objects.filter(pedido_id=self.pedido).count(), 1)
        self.assertEqual(str(Pago.objects.get(pedido_id=self.pedido).monto), '24.00')

    @patch.object(mp, 'solicitud')
    def test_pendiente_o_rechazado_no_desbloquean_reparto(self, api):
        data = self.preparar()
        for status in ['created', 'processing', 'failed', 'canceled']:
            self.buscar_responde(api, {**data, 'status': status})
            r = self.confirmar(estado='aprobado')
            self.assertEqual(r.status_code, 200, r.data)
            self.assertFalse(r.data['reparto_habilitado'])
            self.assertFalse(Pago.objects.filter(pedido_id=self.pedido, estado='aprobado').exists())
        self.assertEqual(Pago.objects.filter(pedido_id=self.pedido).count(), 1)

    @patch.object(mp, 'solicitud')
    def test_error_de_red_no_registra_aprobacion(self, api):
        self.preparar()
        api.side_effect = mp.ErrorProveedor()
        self.assertEqual(self.confirmar().status_code, 502)
        self.assertFalse(Pago.objects.exists())

    @patch.object(mp, 'solicitud')
    def test_confirmacion_exige_comprador_propietario(self, api):
        self.preparar()
        anonymous = APIClient()
        self.assertIn(anonymous.post('/api/pagos/mercadopago/confirmar/', {'pedido_id': self.pedido}).status_code, (401, 403))
        self.auth(self.seller)
        self.assertEqual(self.confirmar().status_code, 403)
        self.auth(self.user)
        Pedido.objects.filter(pk=self.pedido).update(comprador_id=self.seller.pk)
        self.assertEqual(self.confirmar().status_code, 404)
        api.assert_not_called()

    @patch.object(mp, 'solicitud')
    def test_checkout_pendiente_impide_simulador_alternativo(self, api):
        data = self.preparar()
        api.side_effect = [{'data': []}, data]
        self.assertEqual(self.checkout().status_code, 200)
        self.assertEqual(fixtures.ApiTests.pay(self, self.pedido).status_code, 400)
        self.assertEqual(self.post(f'/api/pedidos/{self.pedido}/cancelar/', {}).status_code, 400)
        self.assertNotEqual(Pedido.objects.get(pk=self.pedido).estado, 'cancelado')
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_reembolso_no_se_mantiene_como_pago_aprobado(self, api):
        data = self.preparar()
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        self.buscar_responde(api, data)
        self.assertEqual(self.confirmar().status_code, 200)
        data.update(status='processed', status_detail='partially_refunded', total_paid_amount='20.00')
        self.buscar_responde(api, data)
        r = self.confirmar()
        self.assertFalse(r.data['reparto_habilitado'])
        self.assertEqual(Pago.objects.get(pedido_id=self.pedido).estado, 'reembolsado')

    @patch.object(mp, 'solicitud')
    def test_webhook_de_order_vinculada_concilia_idempotente_y_verifica_importe(self, api):
        data = self.preparar()
        api.side_effect = [{'data': []}, data]
        self.assertEqual(self.checkout().status_code, 200)
        ts, request_id = '1234567890', 'evento-test'
        manifest = f'id:{ORDER_ID.lower()};request-id:{request_id};ts:{ts};'
        firma = hmac.new(CONFIG['MERCADOPAGO_WEBHOOK_SECRET'].encode(), manifest.encode(), hashlib.sha256).hexdigest()
        client = APIClient()
        body = {'type': 'order', 'live_mode': False, 'data': {'id': ORDER_ID}, 'status': 'processed'}
        ruta = f'/api/pagos/mercadopago/webhook/?data.id={ORDER_ID}'
        def enviar():
            return client.post(ruta, body, format='json', HTTP_X_REQUEST_ID=request_id,
                               HTTP_X_SIGNATURE=f'ts={ts},v1={firma}')
        api.side_effect = None
        api.return_value = data
        self.assertEqual(enviar().status_code, 200)
        self.assertEqual(Pago.objects.get(pedido_id=self.pedido).estado, 'pendiente')
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        api.return_value = {**data, 'total_amount': '23.00', 'total_paid_amount': '23.00'}
        self.assertEqual(enviar().status_code, 502)
        self.assertEqual(Pago.objects.get(pedido_id=self.pedido).estado, 'pendiente')
        api.return_value = data
        for _ in range(2):
            r = enviar()
            self.assertEqual(r.status_code, 200, r.data)
            self.assertTrue(r.data['pago_interno_aprobado'])
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_confirmar_rechaza_monto_ajeno_cancelado_y_otro_pago(self, api):
        data = self.preparar()
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        self.buscar_responde(api, {**data, 'total_paid_amount': '23.99'})
        self.assertEqual(self.confirmar().status_code, 502)
        self.assertFalse(Pago.objects.exists())
        Pedido.objects.filter(pk=self.pedido).update(estado='cancelado')
        self.buscar_responde(api, data)
        self.assertEqual(self.confirmar().status_code, 400)
        self.assertFalse(Pago.objects.exists())
        Pedido.objects.filter(pk=self.pedido).update(estado='en_preparacion')
        fixtures.ApiTests.pay(self, self.pedido)
        self.buscar_responde(api, data)
        self.assertEqual(self.confirmar().status_code, 400)
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_referencia_guardada_sobrevive_rotacion_de_secret_key(self, api):
        data = self.preparar()
        api.side_effect = [{'data': []}, data]
        self.assertEqual(self.checkout().status_code, 200)
        with override_settings(SECRET_KEY='clave-django-rotada-solo-test'):
            _, _, reference = mp.contexto(self.user, self.pedido)
            self.assertEqual(reference, self.reference)
            data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
            self.buscar_responde(api, data)
            # Invocación de servicio: los tokens previos se invalidan al rotar SECRET_KEY.
            self.assertTrue(mp.confirmar_pago(self.user, self.pedido)['pago_interno_aprobado'])

    @patch.object(mp, 'solicitud')
    def test_flujo_completo_mercadopago_habilita_recogida_y_entrega(self, api):
        data = self.preparar()
        julio = Usuario.objects.create(nombres='Julio', celular='900000012', password_hash=self.seller.password_hash)
        UsuarioRol.objects.create(usuario_id=julio.pk, rol_codigo='vendedor')
        self.stall2.vendedor = julio
        self.stall2.save(update_fields=['vendedor'])
        api.side_effect = [{'data': []}, data]
        self.assertEqual(self.checkout().status_code, 200)
        repartidor, _ = self.driver()
        self.auth(repartidor)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'], [])
        self.auth(self.user)
        data.update(status='processed', status_detail='accredited', total_paid_amount='24.00')
        self.buscar_responde(api, data)
        self.assertEqual(self.confirmar().status_code, 200)
        for parte in PedidoPuesto.objects.filter(pedido_id=self.pedido).select_related('puesto__vendedor'):
            self.auth(parte.puesto.vendedor)
            r = self.client.patch(f'/api/vendedor/pedidos/{parte.pk}/accion/', {'accion': 'listo'}, format='json')
            self.assertEqual(r.status_code, 200, r.data)
        self.auth(repartidor)
        oferta = self.client.get('/api/repartidor/inicio/').data['ofertas'][0]
        self.assertEqual(oferta['id'], self.pedido)
        self.assertEqual(oferta['pago_proveedor'], 'mercadopago_prueba')
        self.aceptar(repartidor, self.pedido)
        for parte in PedidoPuesto.objects.filter(pedido_id=self.pedido).select_related('puesto__vendedor').order_by('id'):
            self.auth(parte.puesto.vendedor)
            r = self.client.patch(f'/api/vendedor/pedidos/{parte.pk}/accion/', {'accion': 'entregar'}, format='json')
            self.assertEqual(r.status_code, 200, r.data)
        self.auth(repartidor)
        self.assertEqual(self.accion(self.pedido, 'salir').status_code, 200)
        self.auth(self.user)
        codigo = self.client.get('/api/comprador/pedidos/?vigente=1').data[0]['codigo_entrega']
        self.auth(repartidor)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{self.pedido}/entregar/', {'codigo': codigo}).status_code, 200)
        self.assertEqual(Pedido.objects.get(pk=self.pedido).estado, 'entregado')
        self.assertEqual(Pago.objects.filter(pedido_id=self.pedido).count(), 1)

    @patch.object(mp, 'solicitud')
    def test_reintento_tras_timeout_conserva_idempotencia(self, api):
        data = self.preparar()
        api.side_effect = [{'data': []}, mp.ErrorProveedor(), {'data': []}, data]
        self.assertEqual(self.checkout().status_code, 502)
        self.assertEqual(self.checkout().status_code, 200)
        self.assertEqual(api.call_args_list[1].kwargs['clave'], api.call_args_list[3].kwargs['clave'])

    @patch.object(mp, 'solicitud')
    def test_rechaza_order_con_datos_ajenos_o_importe_incorrecto(self, api):
        data = self.preparar()
        for cambio in [{'total_amount': '0.01'}, {'currency': 'USD'}, {'user_id': 'otro'},
                       {'live_mode': True}, {'id': 'ORDPRODUCTION123456'},
                       {'external_reference': 'ajena'}, {'country_code': 'ARG'},
                       {'checkout_url': 'https://sitio-ajeno.test/'}]:
            with self.subTest(cambio=cambio):
                invalid = {**data, **cambio}
                api.side_effect = [{'data': []}, invalid]
                self.assertEqual(self.checkout().status_code, 502)

    @patch.object(mp, 'solicitud')
    def test_estado_no_confunde_pendiente_reembolso_ni_importe_parcial_con_aprobacion(self, api):
        data = self.preparar()
        for estado, detalle, pagado, codigo, aprobado in [
            ('processing', 'in_process', '0', 200, False),
            ('processed', 'partially_refunded', '20', 200, False),
            ('processed', 'accredited', '23', 502, None),
            ('processed', 'accredited', '24', 200, True),
        ]:
            with self.subTest(estado=estado, detalle=detalle, pagado=pagado):
                api.side_effect = [{'data': [{'id': ORDER_ID, 'external_reference': self.reference}]},
                                   {**data, 'status': estado, 'status_detail': detalle, 'total_paid_amount': pagado}]
                response = self.estado()
                self.assertEqual(response.status_code, codigo)
                if codigo == 200:
                    self.assertEqual(response.data['aprobado_en_proveedor'], aprobado)

    @patch.object(mp, 'solicitud')
    def test_anonimo_vendedor_y_pedido_ajeno_no_contactan_proveedor(self, api):
        self.preparar()
        anonymous = APIClient()
        self.assertIn(anonymous.post('/api/pagos/mercadopago/checkout/', {'pedido_id': self.pedido}).status_code, (401, 403))
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(self.seller))
        self.assertEqual(self.checkout().status_code, 403)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(self.user))
        Pedido.objects.filter(pk=self.pedido).update(comprador_id=self.seller.pk)
        self.assertEqual(self.checkout().status_code, 404)
        self.assertEqual(self.estado().status_code, 404)
        api.assert_not_called()

    @patch.object(mp, 'solicitud')
    def test_sin_cotizacion_aceptada_o_vencida_no_inicia(self, api):
        self.pedido = self.order()
        self.assertEqual(self.checkout().status_code, 400)
        self.pedido = self.quoted_order()
        Cotizacion.objects.filter(pedido_id=self.pedido).update(aceptado_en=timezone.now()-timezone.timedelta(days=2))
        self.assertEqual(self.checkout().status_code, 400)
        api.assert_not_called()

    @patch.object(mp, 'solicitud')
    def test_pago_interno_aprobado_y_metodo_efectivo_no_crean_checkout(self, api):
        self.preparar()
        Pedido.objects.filter(pk=self.pedido).update(metodo_pago='efectivo')
        self.assertEqual(self.checkout().status_code, 400)
        Pedido.objects.filter(pk=self.pedido).update(metodo_pago='yape')
        response = fixtures.ApiTests.pay(self, self.pedido)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(self.checkout().status_code, 400)
        api.assert_not_called()

    @override_settings(MERCADOPAGO_PRUEBAS_ENABLED=False)
    @patch.object(mp, 'solicitud')
    def test_desactivado_y_configuracion_no_expone_secretos(self, api):
        self.pedido = 1
        response = self.client.get('/api/pagos/mercadopago/configuracion/')
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['configurado'])
        self.assertIn('no-store', response['Cache-Control'])
        self.assertNotIn(CONFIG['MERCADOPAGO_TEST_ACCESS_TOKEN'], str(response.data))
        self.assertEqual(self.checkout().status_code, 503)
        api.assert_not_called()

    @patch.object(mp, 'solicitud')
    def test_webhook_firmado_consulta_fuente_y_no_escribe(self, api):
        data = self.preparar()
        api.return_value = data
        ts, request_id = '1234567890', 'notificacion-test'
        manifest = f'id:{ORDER_ID.lower()};request-id:{request_id};ts:{ts};'
        firma = hmac.new(CONFIG['MERCADOPAGO_WEBHOOK_SECRET'].encode(), manifest.encode(), hashlib.sha256).hexdigest()
        client = APIClient()
        body = {'type': 'order', 'live_mode': False, 'data': {'id': ORDER_ID}, 'status': 'processed'}
        ruta = f'/api/pagos/mercadopago/webhook/?data.id={ORDER_ID}'
        with CaptureQueriesContext(connection) as queries:
            response = client.post(ruta, body, format='json', HTTP_X_REQUEST_ID=request_id,
                                   HTTP_X_SIGNATURE=f'ts={ts},v1={firma}')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(response.data['registro_interno'])
        api.assert_called_once_with('GET', order_id=ORDER_ID)
        self.assert_sin_escrituras(queries)
        api.reset_mock()
        response = client.post(ruta, body, format='json', HTTP_X_REQUEST_ID=request_id,
                               HTTP_X_SIGNATURE=f'ts={ts},v1={"0" * 64}')
        self.assertEqual(response.status_code, 403)
        api.assert_not_called()


@override_settings(**CONFIG)
class MercadoPagoContractTests(SimpleTestCase):
    @patch.object(mp.requests, 'request')
    def test_http_idempotencia_y_errores_sin_filtrar_secretos(self, request):
        request.return_value = Mock(status_code=201, json=Mock(return_value={'id': ORDER_ID}))
        self.assertEqual(mp.solicitud('POST', body={'type': 'online'}, clave='clave-estable'), {'id': ORDER_ID})
        args, kwargs = request.call_args
        self.assertEqual(args, ('POST', mp.API_URL))
        self.assertEqual(kwargs['headers']['X-Idempotency-Key'], 'clave-estable')
        self.assertEqual(kwargs['headers']['Authorization'], 'Bearer '+CONFIG['MERCADOPAGO_TEST_ACCESS_TOKEN'])
        self.assertFalse(kwargs['allow_redirects'])
        self.assertEqual(kwargs['timeout'], (3, 10))
        request.side_effect = requests.Timeout('detalle privado')
        with self.assertRaises(mp.ErrorProveedor) as error:
            mp.solicitud('GET')
        self.assertNotIn('detalle privado', str(error.exception))
        request.side_effect = None
        request.return_value = Mock(status_code=401)
        with self.assertRaises(mp.ServicioNoDisponible):
            mp.solicitud('GET')

    def test_no_abre_url_ajena_ni_orders_reales(self):
        self.assertEqual(mp.validar_url_checkout(URL, ORDER_ID), URL)
        for url in [URL.replace('https:', 'http:'), URL.replace('.com.pe', '.com.pe.evil.test'),
                    URL.replace('www.', 'user:pass@www.'), URL+'&order_id=OTRO',
                    URL.replace('/checkout/', '/otra/'), URL.replace(ORDER_ID, 'ORDPROD123')]:
            with self.subTest(url=url), self.assertRaises(mp.ErrorProveedor):
                mp.validar_url_checkout(url, ORDER_ID)
        with self.assertRaises(mp.ErrorProveedor):
            mp.solicitud('GET', order_id='ORDPROD123456789')
