from unittest.mock import patch
from django.test import TestCase, SimpleTestCase, override_settings
from . import mercadopago_pruebas as mp
from . import tests as fixtures
from .models import Pago, Pedido
from .test_mercadopago import CONFIG, order_data, ORDER_ID


@override_settings(**CONFIG, MERCADOPAGO_TEST_PUBLIC_KEY='APP_USR-publica-ficticia')
class PagoIntegradoTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        fixtures.ApiTests.setUpTestData.__func__(cls)
    def setUp(self):
        fixtures.ApiTests.setUp(self)
        cuenta = patch('mvp_back.mercadopago_integrado.comprobar_cuenta_prueba')
        cuenta.start()
        self.addCleanup(cuenta.stop)
    post = fixtures.ApiTests.post
    add = fixtures.ApiTests.add
    order = fixtures.ApiTests.order
    quoted_order = fixtures.ApiTests.quoted_order

    def datos(self):
        return {'pedido_id': self.quoted_order(), 'token': 'token_ficticio_123456',
                'payment_method_id': 'master', 'payment_type_id': 'credit_card',
                'installments': 1, 'email': 'comprador@example.test'}

    def enviar(self, datos):
        return self.post('/api/pagos/mercadopago/integrado/', datos)

    def proveedor(self, api, status='processed', paid='24.00'):
        def responder(metodo, **kwargs):
            reference = (kwargs.get('body') or {}).get('external_reference')
            if not reference:
                reference = Pago.objects.get().idempotencia
            return {**order_data(reference), 'processing_mode': 'automatic',
                    'status': status, 'status_detail': 'accredited' if status == 'processed' else status,
                    'total_paid_amount': paid}
        api.side_effect = responder

    @patch.object(mp, 'solicitud')
    def test_pago_tokenizado_valida_total_y_registra_una_sola_vez(self, api):
        datos = self.datos()
        self.proveedor(api)
        r = self.enviar(datos)
        self.assertEqual(r.status_code, 200, r.data)
        self.assertTrue(r.data['pago_interno_aprobado'])
        self.assertTrue(r.data['formulario_integrado'])
        enviado = api.call_args_list[0].kwargs['body']
        self.assertEqual(enviado['total_amount'], '24.00')
        self.assertEqual(enviado['transactions']['payments'][0]['amount'], '24.00')
        self.assertEqual(enviado['processing_mode'], 'automatic')
        self.assertEqual([c.args[0] for c in api.call_args_list], ['POST', 'GET'])
        self.assertNotIn(datos['token'], str(Pago.objects.values().first()))
        self.assertNotIn(datos['email'], str(Pago.objects.values().first()))
        api.reset_mock()
        self.assertEqual(self.enviar(datos).status_code, 400)
        api.assert_not_called()
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_no_acepta_monto_o_datos_crudos_del_cliente(self, api):
        datos = self.datos()
        for extra in [{'total_amount': '.01'}, {'card_number': '1234'}, {'security_code': '123'}]:
            self.assertEqual(self.enviar({**datos, **extra}).status_code, 400)
        api.assert_not_called()
        self.assertFalse(Pago.objects.exists())

    @patch.object(mp, 'solicitud')
    def test_timeout_conserva_reserva_y_bloquea_otro_cobro(self, api):
        datos = self.datos()
        api.side_effect = mp.ErrorProveedor()
        self.assertEqual(self.enviar(datos).status_code, 502)
        self.assertEqual(Pago.objects.get().estado, 'procesando')
        api.side_effect = None
        api.return_value = {'data': []}
        r = self.post('/api/pagos/mercadopago/confirmar/', {'pedido_id': datos['pedido_id']})
        self.assertEqual(r.data['estado'], 'processing')
        api.reset_mock()
        self.assertEqual(self.enviar({**datos, 'token': 'otro_token_ficticio'}).status_code, 400)
        api.assert_not_called()
        # Recuperar por referencia después de perder la respuesta del POST.
        reference = Pago.objects.get().idempotencia
        data = {**order_data(reference), 'processing_mode': 'automatic',
                'status': 'processed', 'status_detail': 'accredited', 'total_paid_amount': '24.00'}
        api.side_effect = [{'data': [{'id': ORDER_ID, 'external_reference': reference}]}, data]
        r = self.post('/api/pagos/mercadopago/confirmar/', {'pedido_id': datos['pedido_id']})
        self.assertTrue(r.data['pago_interno_aprobado'])
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_error_en_consulta_posterior_no_pierde_id_del_pago(self, api):
        datos = self.datos()
        def responder(metodo, **kwargs):
            if metodo == 'GET':
                raise mp.ErrorProveedor()
            return {**order_data(kwargs['body']['external_reference']), 'processing_mode': 'automatic'}
        api.side_effect = responder
        self.assertEqual(self.enviar(datos).status_code, 502)
        pago = Pago.objects.get()
        self.assertEqual(pago.proveedor_transaccion_id, mp.PREFIJO_PAGO + ORDER_ID)
        self.assertEqual(pago.estado, 'procesando')

    @patch.object(mp, 'solicitud')
    def test_rechazo_permite_otro_token_y_solo_cuenta_el_nuevo_intento(self, api):
        datos = self.datos()
        self.proveedor(api, status='failed', paid='0.00')
        self.assertEqual(self.enviar(datos).status_code, 200)
        self.assertEqual(Pago.objects.get().estado, 'rechazado')
        vieja = Pago.objects.get().idempotencia
        self.assertEqual(self.enviar(datos).status_code, 400)
        self.proveedor(api)
        r = self.enviar({**datos, 'token': 'nuevo_token_ficticio'})
        self.assertEqual(r.status_code, 200, r.data)
        self.assertNotEqual(Pago.objects.get().idempotencia, vieja)
        self.assertEqual(Pago.objects.count(), 1)

    @patch.object(mp, 'solicitud')
    def test_respuesta_de_otro_entorno_o_importe_no_aprueba(self, api):
        datos = self.datos()
        def responder(metodo, **kwargs):
            return {**order_data(kwargs['body']['external_reference']), 'processing_mode': 'automatic',
                    'live_mode': True}
        api.side_effect = responder
        self.assertEqual(self.enviar(datos).status_code, 502)
        self.assertFalse(Pago.objects.filter(estado='aprobado').exists())

    @patch.object(mp, 'solicitud')
    def test_yape_necesita_celular_y_envia_token_sin_otp(self, api):
        datos = {**self.datos(), 'payment_method_id': 'yape', 'payment_type_id': 'debit_card'}
        self.assertEqual(self.enviar(datos).status_code, 400)
        self.proveedor(api)
        self.assertEqual(self.enviar({**datos, 'phone': '900000001'}).status_code, 200)
        enviado = api.call_args_list[0].kwargs['body']
        self.assertEqual(enviado['payer']['phone'], {'area_code': '51', 'number': '900000001'})
        self.assertNotIn('otp', str(enviado))

    @override_settings(MERCADOPAGO_TEST_PUBLIC_KEY='')
    @patch.object(mp, 'solicitud')
    def test_sin_clave_publica_no_inicia_pago(self, api):
        self.assertEqual(self.enviar(self.datos()).status_code, 503)
        api.assert_not_called()

    @patch.object(mp, 'solicitud')
    def test_cancela_checkout_anterior_sin_cancelar_el_pedido(self, api):
        datos = self.datos()
        _, _, reference = mp.contexto(self.user, datos['pedido_id'])
        data = order_data(reference)
        mp.registrar_order(self.user, datos['pedido_id'], data)
        api.side_effect = [data, {}, {**data, 'status': 'canceled'}]
        r = self.post('/api/pagos/mercadopago/cancelar-intento/', {'pedido_id': datos['pedido_id']})
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(Pago.objects.get().estado, 'anulado')
        self.assertEqual(Pedido.objects.get(pk=datos['pedido_id']).estado, 'en_preparacion')
        self.assertEqual(api.call_args_list[1].kwargs['accion'], 'cancel')
        self.proveedor(api)
        self.assertEqual(self.enviar(datos).status_code, 200)

    @patch.object(mp, 'solicitud')
    def test_no_cancela_un_pago_ya_acreditado(self, api):
        datos = self.datos()
        self.proveedor(api)
        self.assertEqual(self.enviar(datos).status_code, 200)
        api.reset_mock()
        r = self.post('/api/pagos/mercadopago/cancelar-intento/', {'pedido_id': datos['pedido_id']})
        self.assertEqual(r.status_code, 400)
        self.assertEqual([c.args[0] for c in api.call_args_list], ['GET'])
        self.assertEqual(Pago.objects.get().estado, 'aprobado')


@override_settings(**CONFIG)
class CuentaPruebaTests(SimpleTestCase):
    @patch('mvp_back.mercadopago_integrado.requests.get')
    def test_exige_cuenta_de_prueba_peruana_y_id_esperado(self, get):
        from .mercadopago_integrado import comprobar_cuenta_prueba
        get.return_value.status_code = 200
        valido = {'id': '12345', 'site_id': 'MPE', 'tags': ['test_user']}
        get.return_value.json.return_value = valido
        comprobar_cuenta_prueba()
        for invalido in [{**valido, 'tags': []}, {**valido, 'site_id': 'MLA'}, {**valido, 'id': 'otro'}]:
            get.return_value.json.return_value = invalido
            with self.assertRaises(mp.ServicioNoDisponible):
                comprobar_cuenta_prueba()
