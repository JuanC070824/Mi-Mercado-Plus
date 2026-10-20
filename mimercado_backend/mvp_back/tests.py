from decimal import Decimal
from io import StringIO
from unittest.mock import patch
from django.test import TestCase, SimpleTestCase, override_settings
from django.core.management import call_command
from django.contrib.auth.hashers import make_password,check_password
from django.utils import timezone
from rest_framework.test import APIClient
from .models import (Usuario,UsuarioRol,Rol,Mercado,Categoria,Puesto,Producto,UnidadMedida,
    Pedido,PedidoDetalle,Carrito,CarritoItem,Cotizacion,Pago,Direccion)
from .authentication import issue_token
from .money import line_total,cents
from .payments import RejectedPayment,UncertainPayment,provider_charge
from .dni import firmar_consulta,consultar_dni,DniNoEncontrado

class MoneyTests(SimpleTestCase):
    def test_exact_decimal_and_half_up(self):
        self.assertEqual(cents(line_total(Decimal('1.125'),Decimal('4.00'))),450)
        self.assertEqual(cents(Decimal('1.005')),101)
        self.assertEqual(line_total('0.1','0.2'),Decimal('0.02'))

class DniServiceTests(SimpleTestCase):
    @override_settings(JSONPE_KEY='token-de-prueba')
    @patch('mvp_back.dni.requests.post')
    def test_jsonpe_contract_and_name_normalization(self,post):
        response=type('R',(),{'status_code':200,'json':lambda self:{'success':True,'data':{
            'nombres':'MARIA ESPERANZA','apellido_paterno':'DEL PILAR','apellido_materno':'LÓPEZ'}}})()
        post.return_value=response
        datos=consultar_dni('12345678')
        self.assertEqual(datos['nombres'],'Maria Esperanza')
        self.assertEqual(datos['apellido_paterno'],'Del Pilar')
        self.assertEqual(datos['apellido_materno'],'López')
        self.assertEqual(post.call_args.kwargs['json'],{'dni':'12345678'})
        self.assertEqual(post.call_args.kwargs['headers']['Authorization'],'Bearer token-de-prueba')

    @override_settings(JSONPE_KEY='token-de-prueba')
    @patch('mvp_back.dni.requests.post')
    def test_jsonpe_404_is_not_found(self,post):
        post.return_value=type('R',(),{'status_code':404})()
        with self.assertRaises(DniNoEncontrado):
            consultar_dni('00000000')

class ApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        for code in ['comprador','vendedor','repartidor']:
            Rol.objects.create(codigo=code,nombre=code)
        UnidadMedida.objects.create(codigo='kg',nombre='Kilogramo',permite_fraccion=True)
        UnidadMedida.objects.create(codigo='unidad',nombre='Unidad',permite_fraccion=False)
        cat=Categoria.objects.create(nombre='Verduras y frutas')
        cls.market=Mercado.objects.create(nombre='Mercado1',direccion='D1')
        other=Mercado.objects.create(nombre='Mercado2',direccion='D2')
        seller=Usuario.objects.create(nombres='Rosa',celular='900000011',password_hash=make_password('password'))
        UsuarioRol.objects.create(usuario_id=seller.pk,rol_codigo='vendedor')
        cls.stall=Puesto.objects.create(mercado_id=cls.market.pk,vendedor_id=seller.pk,categoria_id=cat.pk,nombre='Rosa',abierto=True)
        cls.stall2=Puesto.objects.create(mercado_id=cls.market.pk,vendedor_id=seller.pk,categoria_id=cat.pk,nombre='Julio',abierto=True)
        p3=Puesto.objects.create(mercado_id=other.pk,vendedor_id=seller.pk,categoria_id=cat.pk,nombre='Otro',abierto=True)
        cls.p1=Producto.objects.create(puesto_id=cls.stall.pk,nombre='Tomate',unidad_codigo='kg',precio_unitario=Decimal('4.00'),stock=Decimal('10'))
        cls.p2=Producto.objects.create(puesto_id=cls.stall2.pk,nombre='Pollo',unidad_codigo='kg',precio_unitario=Decimal('10.00'))
        cls.p3=Producto.objects.create(puesto_id=p3.pk,nombre='Otro',unidad_codigo='kg',precio_unitario=Decimal('1.00'))
        cls.user=Usuario.objects.create(nombres='María',celular='900000001',correo='maria@example.test',password_hash=make_password('CompraSegura!42'))
        UsuarioRol.objects.create(usuario_id=cls.user.pk,rol_codigo='comprador')
        cls.address=Direccion.objects.create(comprador_id=cls.user.pk,direccion='Casa1',principal=True)

    def setUp(self):
        self.client=APIClient()
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(self.user))

    def post(self,url,data):return self.client.post(url,data,format='json')
    def registro(self,celular='900000002',rol='comprador',dni='12345678'):
        identidad={'dni':dni,'nombres':'Nuevo','apellido_paterno':'Usuario','apellido_materno':'Prueba'}
        return {'dni':dni,'dni_token':firmar_consulta(identidad),'celular':celular,
                'password':'ClaveFuerte!42','rol':rol}
    def add(self,product=None,quantity='1.000'):
        return self.post('/api/carrito/items/',{'producto_id':(product or self.p1).pk,'cantidad':quantity})
    def order(self):
        self.add()
        self.add(self.p2,'1.500')
        response=self.post('/api/pedidos/',{'direccion_id':self.address.pk,'metodo_pago':'yape'})
        self.assertEqual(response.status_code,201,response.data)
        return response.data['id']
    def quoted_order(self):
        order=self.order()
        call_command('cotizar_demo',pedido=order,envio_centavos=500,stdout=StringIO())
        quote=Cotizacion.objects.get(pedido_id=order)
        r=self.post(f'/api/pedidos/{order}/cotizaciones/{quote.pk}/aceptar/',{})
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual(r.data['total_centavos'],2400)
        return order
    def pay(self,order,key='intento_001',code='123456'):
        return self.post('/api/pagos/yape/',{'pedido_id':order,'celular':'900000001','codigo':code,'idempotencia':key})

    def test_registration_hash_role_no_privilege_escalation(self):
        data=self.registro()
        data['celular']='+51 900 000 002'
        r=self.post('/api/auth/registro/',data)
        self.assertEqual(r.status_code,201,r.data)
        u=Usuario.objects.get(celular='900000002')
        self.assertEqual((u.nombres,u.apellido_paterno,u.apellido_materno),('Nuevo','Usuario','Prueba'))
        self.assertNotEqual(u.password_hash,'ClaveFuerte!42')
        self.assertTrue(check_password('ClaveFuerte!42',u.password_hash))
        self.assertEqual(list(UsuarioRol.objects.filter(usuario_id=u.pk).values_list('rol_codigo',flat=True)),['comprador'])

    def test_registration_supports_all_three_roles(self):
        for index,rol in enumerate(['comprador','vendedor','repartidor'],start=2):
            celular=f'90000010{index}'
            r=self.post('/api/auth/registro/',self.registro(celular=celular,rol=rol,dni=f'1234567{index}'))
            self.assertEqual(r.status_code,201,r.data)
            self.assertEqual(r.data['rol_activo'],rol)
            self.assertTrue(UsuarioRol.objects.filter(usuario_id=r.data['usuario']['id'],rol_codigo=rol).exists())

    def test_markets_endpoint_returns_only_active_markets_with_location(self):
        self.market.distrito='Surquillo'
        self.market.provincia='Lima'
        self.market.departamento='Lima'
        self.market.latitud=Decimal('-12.113000')
        self.market.longitud=Decimal('-77.020000')
        self.market.save()
        Mercado.objects.create(nombre='Mercado suspendido',direccion='D3',estado='suspendido')

        response=self.client.get('/api/mercados/')

        self.assertEqual(response.status_code,200,response.data)
        self.assertNotIn('Mercado suspendido',[row['nombre'] for row in response.data])
        row=next(row for row in response.data if row['id']==self.market.pk)
        self.assertEqual(row['distrito'],'Surquillo')
        self.assertEqual(Decimal(str(row['latitud'])),Decimal('-12.113000'))
        self.assertEqual(Decimal(str(row['longitud'])),Decimal('-77.020000'))

    @patch('mvp_back.views.consultar_dni')
    def test_dni_lookup_returns_names_and_signed_registration_token(self,consulta):
        consulta.return_value={'dni':'12345678','nombres':'María Elena',
            'apellido_paterno':'Del Pilar','apellido_materno':'López'}
        r=self.post('/api/auth/dni/',{'dni':'12345678'})
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual(r.data['nombres'],'María Elena')
        self.assertIn('registro_token',r.data)
        data=self.registro()
        data['dni_token']=r.data['registro_token']
        creado=self.post('/api/auth/registro/',data)
        self.assertEqual(creado.status_code,201,creado.data)
        self.assertEqual(creado.data['usuario']['apellido_paterno'],'Del Pilar')

    def test_registration_rejects_tampered_dni_token(self):
        data=self.registro()
        data['dni_token']+='alterado'
        self.assertEqual(self.post('/api/auth/registro/',data).status_code,400)

    def test_login_and_wrong_password(self):
        r=self.post('/api/auth/login/',{'celular':'900000001','password':'CompraSegura!42'})
        self.assertEqual(r.status_code,200)
        self.assertIn('token',r.data)
        self.assertEqual(r.data['rol_activo'],'comprador')
        self.assertEqual(self.post('/api/auth/login/',{'celular':'900000001','password':'incorrecta'}).status_code,401)

    def test_login_validates_selected_role(self):
        r=self.post('/api/auth/login/',{
            'celular':'900000011','password':'password','rol':'vendedor'})
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual(r.data['rol_activo'],'vendedor')
        self.assertIn('vendedor',r.data['usuario']['roles'])
        self.assertEqual(r.data['usuario']['puesto_id'],self.stall.pk)
        self.assertEqual(r.data['usuario']['mercado_id'],self.market.pk)

        r=self.post('/api/auth/login/',{
            'celular':'900000001','password':'CompraSegura!42','rol':'repartidor'})
        self.assertEqual(r.status_code,403,r.data)
        self.assertNotIn('token',r.data)

        r=self.post('/api/auth/login/',{
            'celular':'900000001','password':'CompraSegura!42','rol':'administrador'})
        self.assertEqual(r.status_code,400,r.data)

    def test_duplicate_phone(self):
        self.assertEqual(self.post('/api/auth/registro/',self.registro(celular='900000001')).status_code,400)

    def test_invalid_phone(self):
        self.assertEqual(self.post('/api/auth/login/',{'celular':'123','password':'X'}).status_code,400)

    def test_missing_or_tampered_token(self):
        self.client.credentials()
        self.assertEqual(self.client.get('/api/carrito/').status_code,401)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer falso')
        self.assertEqual(self.client.get('/api/carrito/').status_code,401)

    def test_suspended_user_token(self):
        Usuario.objects.filter(pk=self.user.pk).update(estado='suspendido')
        self.assertEqual(self.client.get('/api/carrito/').status_code,401)

    def test_multi_stall_same_market_and_absolute_quantity(self):
        self.add(quantity='1.125')
        self.add(quantity='1.125')
        r=self.add(self.p2,'1.500')
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual(len(r.data['puestos']),2)
        self.assertEqual(r.data['total_productos_centavos'],1950)
        self.assertEqual(CarritoItem.objects.count(),2)

    def test_reject_cross_market(self):
        self.add()
        self.assertEqual(self.add(self.p3).status_code,400)
        self.assertEqual(CarritoItem.objects.count(),1)

    def test_reject_stock_and_unit_fraction(self):
        self.assertEqual(self.add(quantity='11.000').status_code,400)
        Producto.objects.filter(pk=self.p1.pk).update(unidad_codigo='unidad')
        self.assertEqual(self.add(quantity='0.500').status_code,400)

    def test_closed_stall(self):
        Puesto.objects.filter(pk=self.stall.pk).update(abierto=False)
        self.assertEqual(self.add().status_code,400)

    def test_remove_final_item_allows_market_change(self):
        r=self.add();item=r.data['puestos'][0]['items'][0]['id']
        self.assertEqual(self.client.delete(f'/api/carrito/items/{item}/').status_code,200)
        self.assertEqual(self.add(self.p3).status_code,200)

    def test_cannot_modify_another_users_cart(self):
        item=self.add().data['puestos'][0]['items'][0]['id']
        user=Usuario.objects.create(nombres='Otro',celular='900000009',password_hash=make_password('x'))
        UsuarioRol.objects.create(usuario_id=user.pk,rol_codigo='comprador')
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(user))
        self.assertEqual(self.client.delete(f'/api/carrito/items/{item}/').status_code,404)

    def test_checkout_snapshot_stock_and_no_repeat(self):
        order=self.order()
        self.p1.refresh_from_db();self.assertEqual(self.p1.stock,Decimal('9.000'))
        self.assertEqual(PedidoDetalle.objects.filter(pedido_puesto__pedido_id=order).count(),2)
        self.address.direccion='Cambio';self.address.save()
        self.assertEqual(Pedido.objects.get(pk=order).direccion_entrega,'Casa1')
        self.assertEqual(self.post('/api/pedidos/',{'direccion_id':self.address.pk,'metodo_pago':'yape'}).status_code,400)

    def test_price_acceptance_required(self):
        order=self.order()
        self.assertEqual(self.pay(order).status_code,400)
        self.assertEqual(Pago.objects.count(),0)

    def test_mock_payment_and_retries_do_not_charge_twice(self):
        order=self.quoted_order()
        with patch('mvp_back.payments.provider_charge',return_value='mock_test') as provider:
            first=self.pay(order)
            again=self.pay(order)
            third=self.pay(order,key='otra_clave_001')
        self.assertEqual(first.status_code,200,first.data)
        self.assertTrue(first.data['success']);self.assertTrue(first.data['simulado'])
        self.assertEqual(first.data['pago_id'],again.data['pago_id'])
        self.assertEqual(first.data['pago_id'],third.data['pago_id'])
        self.assertEqual(provider.call_count,1)
        self.assertEqual(Pago.objects.count(),1)

    def test_mock_wrong_code_is_rejected(self):
        r=self.pay(self.quoted_order(),code='000000')
        self.assertEqual(r.status_code,402,r.data)
        self.assertFalse(r.data['success'])
        self.assertEqual(Pago.objects.get().estado,'rechazado')

    def test_uncertain_charge_blocks_new_attempt(self):
        order=self.quoted_order()
        with patch('mvp_back.payments.provider_charge',side_effect=UncertainPayment('Revisar')):
            self.assertEqual(self.pay(order).status_code,502)
        with patch('mvp_back.payments.provider_charge') as provider:
            self.assertEqual(self.pay(order,key='otra_clave_001').status_code,409)
            provider.assert_not_called()
        self.assertEqual(Pago.objects.get().estado,'procesando')

    def test_invalid_otp_and_disabled_mode(self):
        order=self.quoted_order()
        self.assertEqual(self.pay(order,code='12345').status_code,400)
        with override_settings(PAYMENT_MODE='disabled'):
            self.assertEqual(self.pay(order).status_code,400)

    def test_other_user_cannot_pay_order(self):
        order=self.quoted_order()
        user=Usuario.objects.create(nombres='Otro',celular='900000009',password_hash=make_password('x'))
        UsuarioRol.objects.create(usuario_id=user.pk,rol_codigo='comprador')
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(user))
        self.assertEqual(self.pay(order).status_code,404)

    def test_cancellation_restores_reservation_once(self):
        order=self.order()
        response=self.post(f'/api/pedidos/{order}/cancelar/',{})
        self.assertEqual(response.status_code,200,response.data)
        self.post(f'/api/pedidos/{order}/cancelar/',{})
        self.p1.refresh_from_db()
        self.assertEqual(self.p1.stock,Decimal('10'))
        self.assertEqual(Pedido.objects.get(pk=order).estado,'cancelado')

    def test_cannot_cancel_paid_order(self):
        order=self.quoted_order()
        self.assertEqual(self.pay(order).status_code,200)
        self.assertEqual(self.post(f'/api/pedidos/{order}/cancelar/',{}).status_code,400)

    def test_culqi_adapter_uses_test_keys_and_cents(self):
        token_response=type('R',(),{'status_code':201,'json':lambda self:{'id':'ype_test_123'}})()
        charge_response=type('R',(),{'status_code':201,'json':lambda self:{'id':'chr_test_123'}})()
        with override_settings(PAYMENT_MODE='culqi_sandbox',CULQI_PUBLIC_KEY='pk_test_demo',CULQI_SECRET_KEY='sk_test_demo'):
            with patch('mvp_back.payments.requests.post',side_effect=[token_response,charge_response]) as post:
                self.assertEqual(provider_charge('900000001','123456',2400,'maria@example.test'),'chr_test_123')
                self.assertEqual(post.call_args_list[0].kwargs['json']['amount'],'2400')
                self.assertEqual(post.call_args_list[1].kwargs['json']['amount'],2400)
        with override_settings(PAYMENT_MODE='culqi_sandbox',CULQI_PUBLIC_KEY='pk_live_X',CULQI_SECRET_KEY='sk_live_X'):
            with self.assertRaises(RejectedPayment):provider_charge('900000001','123456',2400,'maria@example.test')
