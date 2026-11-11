from decimal import Decimal
from django.contrib.auth.hashers import make_password
from django.test import TestCase
from .authentication import issue_token
from .models import Mercado, PedidoPuesto, Producto, Puesto, ResenaPuesto, Usuario, UsuarioRol
from . import tests as base  # el módulo, no la clase: así sus pruebas no se ejecutan dos veces

class RecomendacionesTests(TestCase):
    setUpTestData=classmethod(base.ApiTests.setUpTestData.__func__)
    setUp=base.ApiTests.setUp
    post=base.ApiTests.post
    add=base.ApiTests.add
    order=base.ApiTests.order

    def test_primero_donde_mas_compra_con_calificacion_real_y_productos_repetidos(self):
        primero=self.order()
        self.add();self.post('/api/pedidos/',{'direccion_id':self.address.pk,'metodo_pago':'yape'})  # solo tomate otra vez
        parte=PedidoPuesto.objects.get(pedido_id=primero,puesto_id=self.stall2.pk)
        ResenaPuesto.objects.create(pedido_puesto_id=parte.pk,pedido_id=primero,comprador_id=self.user.pk,estrellas=4)
        r=self.client.get(f'/api/comprador/recomendaciones/?mercado_id={self.market.pk}')
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual([p['nombre'] for p in r.data['puestos']],['Rosa','Julio'])
        self.assertEqual([p['compras'] for p in r.data['puestos']],[2,1])
        self.assertEqual((r.data['puestos'][1]['calificacion'],r.data['puestos'][1]['resenas']),(4.0,1))
        self.assertEqual([(p['nombre'],p['veces']) for p in r.data['productos']],[('Tomate',2),('Pollo',1)])
        self.assertEqual([p['puesto']['nombre'] for p in r.data['productos']],['Rosa','Julio'])
        self.assertNotIn('Otro',[p['nombre'] for p in r.data['puestos']])  # puesto de otro mercado

    def test_sin_compras_muestra_los_mejor_calificados(self):
        r=self.client.get('/api/comprador/recomendaciones/')
        self.assertEqual(r.status_code,200)
        self.assertEqual(r.data['productos'],[])
        self.assertTrue(all(p['compras']==0 for p in r.data['puestos']))
        self.assertEqual(self.client.get('/api/comprador/recomendaciones/?mercado_id=x').status_code,400)

    def test_volver_a_pedir_copia_cantidades_y_salta_lo_no_disponible(self):
        pedido=self.order()
        Producto.objects.filter(pk=self.p2.pk).update(disponible=False)
        r=self.post(f'/api/comprador/pedidos/{pedido}/volver-a-pedir/',{})
        self.assertEqual(r.status_code,200,r.data)
        self.assertEqual((r.data['agregados'],r.data['omitidos']),(['Tomate'],['Pollo']))
        items=[i for g in r.data['carrito']['puestos'] for i in g['items']]
        self.assertEqual([(i['producto_id'],i['cantidad']) for i in items],[(self.p1.pk,'1.000')])

    def test_no_mezcla_mercados_ni_usa_pedidos_ajenos(self):
        pedido=self.order()
        self.assertEqual(self.add(self.p3).status_code,200)  # canasta con un producto de otro mercado
        self.assertEqual(self.post(f'/api/comprador/pedidos/{pedido}/volver-a-pedir/',{}).status_code,400)
        otro=Usuario.objects.create(nombres='Otro',celular='900000077',password_hash=make_password('x'))
        UsuarioRol.objects.create(usuario_id=otro.pk,rol_codigo='comprador')
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(otro))
        self.assertEqual(self.post(f'/api/comprador/pedidos/{pedido}/volver-a-pedir/',{}).status_code,404)
