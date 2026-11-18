from django.contrib.auth.hashers import make_password
from django.test import TestCase
from rest_framework.test import APIClient
from .authentication import issue_token
from .models import Entrega, Mercado, Pedido, Puesto, Categoria, RepartidorMercado, Rol, Usuario, UsuarioRol

def cuenta(nombre,celular,rol):
    u=Usuario.objects.create(nombres=nombre,celular=celular,password_hash=make_password('Clave!4242'))
    UsuarioRol.objects.create(usuario_id=u.pk,rol_codigo=rol)
    return u

class AdministracionAppTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        for code in ['comprador','vendedor','repartidor','administrador']:Rol.objects.create(codigo=code,nombre=code)
        cls.m1=Mercado.objects.create(nombre='Mercado UV3',direccion='D1')
        cls.m2=Mercado.objects.create(nombre='Mercado Pando',direccion='D2',estado='suspendido')
        cls.admin=cuenta('Ana','900000099','administrador')
        cls.ernesto=cuenta('Ernesto','900000090','repartidor')
        casero=cuenta('Rosa','900000011','vendedor')
        Puesto.objects.create(mercado=cls.m1,vendedor=casero,categoria=Categoria.objects.create(nombre='Verduras'),nombre='Rosa')
    def cliente(self,user):
        c=APIClient();c.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(user));return c

    def test_solo_el_administrador_entra(self):
        c=self.cliente(self.ernesto)
        for url in ['/api/administracion/repartidores/','/api/administracion/mercados/']:
            self.assertEqual(c.get(url).status_code,403)
        self.assertEqual(APIClient().get('/api/administracion/mercados/').status_code,401)
        login=APIClient().post('/api/auth/login/',{'celular':'900000099','password':'Clave!4242','rol':'administrador'},format='json')
        self.assertEqual((login.status_code,login.data['rol_activo']),(200,'administrador'))

    def test_ve_y_autoriza_solicitudes_desde_la_app(self):
        rm=RepartidorMercado.objects.create(repartidor=self.ernesto,mercado=self.m1,movilidad='moto',placa='ABC-123')
        c=self.cliente(self.admin)
        lista=c.get('/api/administracion/repartidores/').data
        self.assertEqual([(r['nombre'],r['autorizado'],r['mercado']['nombre']) for r in lista],[('Ernesto',False,'Mercado UV3')])
        r=c.post(f'/api/administracion/repartidores/{rm.pk}/autorizar/',format='json')
        self.assertEqual((r.status_code,r.data['autorizado'],r.data['disponible']),(200,True,True))
        self.assertEqual(c.post(f'/api/administracion/repartidores/{rm.pk}/borrar/',format='json').status_code,404)
        self.assertEqual(c.post(f'/api/administracion/repartidores/{rm.pk}/quitar/',format='json').data['autorizado'],False)

    def test_no_quita_autorizacion_con_entrega_en_curso(self):
        rm=RepartidorMercado.objects.create(repartidor=self.ernesto,mercado=self.m1,movilidad='moto',autorizado=True,disponible=True)
        pedido=Pedido.objects.create(codigo='MM-9',comprador_id=self.admin.pk,mercado_id=self.m1.pk,estado='en_camino',
            metodo_pago='yape',direccion_entrega='Casa',destinatario='X',celular_contacto='900000099')
        Entrega.objects.create(pedido_id=pedido.pk,mercado_id=self.m1.pk,repartidor_mercado_id=rm.pk,estado='en_camino')
        c=self.cliente(self.admin)
        self.assertTrue(c.get('/api/administracion/repartidores/').data[0]['entrega_en_curso'])
        r=c.post(f'/api/administracion/repartidores/{rm.pk}/quitar/',format='json')
        self.assertEqual(r.status_code,400)
        self.assertIn('entrega en curso',str(r.data))

    def test_crea_edita_y_suspende_mercados(self):
        c=self.cliente(self.admin)
        lista=c.get('/api/administracion/mercados/').data
        self.assertEqual([(m['nombre'],m['estado'],m['puestos']) for m in lista],
                         [('Mercado Pando','suspendido',0),('Mercado UV3','activo',1)])
        nuevo=c.post('/api/administracion/mercados/',{'nombre':' Mercado Central ','direccion':'Jr. Ayacucho',
            'distrito':'Cercado','latitud':'-12.05','longitud':'-77.03'},format='json')
        self.assertEqual((nuevo.status_code,nuevo.data['nombre'],nuevo.data['estado']),(201,'Mercado Central','activo'))
        mal=c.post('/api/administracion/mercados/',{'nombre':'X','direccion':'Y','latitud':'-12'},format='json')
        self.assertEqual(mal.status_code,400)
        r=c.patch(f'/api/administracion/mercados/{nuevo.data["id"]}/',{'estado':'suspendido'},format='json')
        self.assertEqual((r.status_code,r.data['estado'],r.data['nombre']),(200,'suspendido','Mercado Central'))
        self.assertEqual(c.patch(f'/api/administracion/mercados/{self.m1.pk}/',{'estado':'cerrado'},format='json').status_code,400)
        # Un mercado suspendido deja de aparecer para los clientes.
        self.assertNotIn('Mercado Central',[m['nombre'] for m in APIClient().get('/api/mercados/').data])
