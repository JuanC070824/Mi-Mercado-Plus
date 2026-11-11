from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import User
from django.test import TestCase
from .models import Entrega, Mercado, Pedido, RepartidorMercado, Rol, Usuario, UsuarioRol

URL='/admin/mvp_back/repartidormercado/'

class AdminRepartidoresTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        Rol.objects.create(codigo='repartidor',nombre='repartidor')
        cls.m1=Mercado.objects.create(nombre='Mercado UV3',direccion='D1')
        cls.m2=Mercado.objects.create(nombre='Mercado Pando',direccion='D2')
        cls.ernesto=Usuario.objects.create(nombres='Ernesto',celular='900000090',password_hash=make_password('Clave!42'))
        UsuarioRol.objects.create(usuario_id=cls.ernesto.pk,rol_codigo='repartidor')
    def setUp(self):
        self.client.force_login(User.objects.create_superuser('admin','admin@example.test','AdminClave!42'))
    def accion(self,accion,*rms):
        return self.client.post(URL,{'action':accion,'_selected_action':[rm.pk for rm in rms]},follow=True)
    def solicitud(self,mercado,**extra):
        return RepartidorMercado.objects.create(repartidor=self.ernesto,mercado=mercado,movilidad='bicicleta',**extra)

    def test_autoriza_desde_admin_sin_consola(self):
        rm=self.solicitud(self.m1)
        lista=self.client.get(URL)
        self.assertContains(lista,'Ernesto')
        self.assertNotContains(lista,'argon2')
        r=self.accion('autorizar',rm)
        self.assertContains(r,'1 repartidor(es) autorizado(s)')
        rm.refresh_from_db()
        self.assertTrue(rm.autorizado and rm.disponible)

    def test_cambiar_de_mercado_cierra_el_anterior(self):
        viejo=self.solicitud(self.m1,autorizado=True,disponible=True)
        nuevo=self.solicitud(self.m2)
        self.accion('autorizar',nuevo)
        viejo.refresh_from_db();nuevo.refresh_from_db()
        self.assertIsNotNone(viejo.fin_en)
        self.assertTrue(nuevo.autorizado)
        self.assertNotContains(self.client.get(URL),'Mercado UV3</td>')  # solo se listan las vigentes

    def test_no_autoriza_ni_quita_con_entrega_en_curso(self):
        viejo=self.solicitud(self.m1,autorizado=True,disponible=True)
        pedido=Pedido.objects.create(codigo='MM-1',comprador_id=self.ernesto.pk,mercado_id=self.m1.pk,estado='en_recojo',
            metodo_pago='yape',direccion_entrega='Casa',destinatario='X',celular_contacto='900000090')
        Entrega.objects.create(pedido_id=pedido.pk,mercado_id=self.m1.pk,repartidor_mercado_id=viejo.pk,estado='en_recojo')
        nuevo=self.solicitud(self.m2)
        self.assertContains(self.accion('autorizar',nuevo),'tiene una entrega en curso')
        self.assertContains(self.accion('quitar_autorizacion',viejo),'tiene una entrega en curso')
        nuevo.refresh_from_db();viejo.refresh_from_db()
        self.assertFalse(nuevo.autorizado)
        self.assertTrue(viejo.autorizado and viejo.fin_en is None)

    def test_usuarios_y_puestos_se_ven_sin_contrasena(self):
        r=self.client.get(f'/admin/mvp_back/usuario/{self.ernesto.pk}/change/')
        self.assertEqual(r.status_code,200)
        self.assertNotContains(r,'password_hash')
        self.assertNotContains(r,'argon2')
        self.assertEqual(self.client.get('/admin/mvp_back/puesto/').status_code,200)
