from django.test import TestCase
from django.contrib.auth.hashers import make_password
from django.core.management import call_command
from io import StringIO
from .tests import ApiTests
from .authentication import issue_token
from .models import (Usuario,UsuarioRol,RepartidorMercado,Entrega,EntregaParada,Pedido,PedidoPuesto,Pago,Mensaje,Mercado,PedidoDetalle,Cotizacion,Puesto)
from . import operaciones as op

class RepartoApiTests(TestCase):
    setUpTestData=classmethod(ApiTests.setUpTestData.__func__)
    setUp=ApiTests.setUp
    post=ApiTests.post
    add=ApiTests.add
    order=ApiTests.order
    quoted_order=ApiTests.quoted_order
    pay=ApiTests.pay
    def driver(self,celular='900000090',mercado=None,autorizado=True):
        u=Usuario.objects.create(nombres='Repartidor',celular=celular,password_hash=make_password('ClaveSegura!42'))
        UsuarioRol.objects.create(usuario_id=u.pk,rol_codigo='repartidor')
        rm=RepartidorMercado.objects.create(repartidor=u,mercado=mercado or self.market,movilidad='a_pie',autorizado=autorizado,disponible=autorizado)
        return u,rm
    def auth(self,u):self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(u))
    def preparado(self,efectivo=False):
        order=self.quoted_order()
        if efectivo: Pedido.objects.filter(pk=order).update(metodo_pago='efectivo')
        else:self.assertEqual(self.pay(order,key=f'intento_{order}').status_code,200)
        return order
    def aceptar(self,u,order):
        self.auth(u);r=self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{})
        self.assertEqual(r.status_code,200,r.data)
        return Entrega.objects.get(pedido_id=order)
    def accion(self,order,accion,parte=None):return self.post(f'/api/repartidor/pedidos/{order}/accion/',{'accion':accion,'pedido_puesto_id':parte})
    def recoger_todo(self,order):
        PedidoPuesto.objects.filter(pedido_id=order).update(estado='listo')
        for parte in PedidoPuesto.objects.filter(pedido_id=order).order_by('id'):
            self.assertEqual(self.accion(order,'recoger',parte.pk).status_code,200)
        self.assertEqual(self.accion(order,'salir').status_code,200)
    def test_no_hay_ofertas_antes_de_aceptar_precio_y_pago(self):
        order=self.order();u,rm=self.driver();self.auth(u)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'],[])
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,400)
        self.assertFalse(Entrega.objects.exists())
    def test_yape_sin_pago_no_se_asigna(self):
        order=self.quoted_order();u,rm=self.driver();self.auth(u)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,400)
    def test_solo_mercado_autorizado_y_disponible(self):
        order=self.preparado();otro=Mercado.objects.create(nombre='Otro',direccion='D')
        u,rm=self.driver(mercado=otro);self.auth(u)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'],[])
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,404)
        rm.mercado=self.market;rm.disponible=False;rm.save()
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,400)
        self.assertEqual(self.client.patch('/api/repartidor/inicio/',{'disponible':True},format='json').status_code,200)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'][0]['id'],order)
    def test_solicitud_no_se_autoriza_a_si_misma(self):
        u,rm=self.driver(autorizado=False);self.auth(u)
        r=self.post('/api/repartidor/mercado/',{'mercado_id':self.market.pk,'movilidad':'moto','autorizado':True})
        self.assertEqual(r.status_code,201,r.data)
        rm.refresh_from_db();self.assertFalse(rm.autorizado);self.assertFalse(rm.disponible)
        self.assertEqual(self.client.patch('/api/repartidor/inicio/',{'disponible':True},format='json').status_code,403)
    def test_una_asignacion_y_aceptacion_idempotente(self):
        order=self.preparado();u,rm=self.driver();entrega=self.aceptar(u,order)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,200)
        otro,_=self.driver('900000091');self.auth(otro)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/aceptar/',{}).status_code,400)
        self.assertEqual(Entrega.objects.filter(pedido_id=order).count(),1)
        self.assertEqual(EntregaParada.objects.filter(entrega=entrega).count(),2)
    def test_un_repartidor_no_toma_dos_pedidos(self):
        order=self.preparado();u,rm=self.driver();self.aceptar(u,order)
        self.auth(self.user);order2=self.preparado();self.auth(u)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order2}/aceptar/',{}).status_code,400)
    def test_recoger_exige_preparacion_orden_y_propiedad(self):
        order=self.preparado();u,rm=self.driver();entrega=self.aceptar(u,order)
        paradas=list(EntregaParada.objects.filter(entrega=entrega).order_by('orden'))
        self.assertEqual(self.accion(order,'recoger',paradas[0].pedido_puesto_id).status_code,400)
        PedidoPuesto.objects.filter(pedido_id=order).update(estado='listo')
        self.assertEqual(self.accion(order,'recoger',paradas[1].pedido_puesto_id).status_code,400)
        self.assertEqual(self.accion(order,'salir').status_code,400)
        self.recoger_todo(order)
        otro,_=self.driver('900000091');self.auth(otro)
        self.assertEqual(self.accion(order,'llegue').status_code,404)
    def test_codigo_solo_para_comprador_y_entrega_idempotente(self):
        order=self.preparado();u,rm=self.driver();entrega=self.aceptar(u,order)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['en_curso']['codigo_entrega'],'')
        self.auth(self.user);codigo=self.client.get('/api/comprador/pedidos/').data[0]['codigo_entrega']
        self.assertEqual(len(codigo),4);self.assertNotEqual(entrega.codigo_entrega_hash,codigo)
        self.auth(u);self.recoger_todo(order);url=f'/api/repartidor/pedidos/{order}/entregar/'
        self.assertEqual(self.post(url,{'codigo':str((int(codigo)+1)%10000).zfill(4)}).status_code,400)
        self.assertNotEqual(Pedido.objects.get(pk=order).estado,'entregado')
        self.assertEqual(self.post(url,{'codigo':codigo}).status_code,200)
        self.assertEqual(self.post(url,{'codigo':codigo}).status_code,200)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['entregas_hoy'],1)
    def test_avisos_se_guardan_sin_duplicados(self):
        order=self.preparado();u,rm=self.driver();self.aceptar(u,order)
        self.assertEqual(self.accion(order,'recogiendo').status_code,200)
        self.assertEqual(self.accion(order,'recogiendo').status_code,200)
        self.assertEqual(Mensaje.objects.filter(pedido_id=order,destinatario_id=self.user.pk).count(),1)
    def test_efectivo_exige_cobro_y_no_duplica_pago(self):
        order=self.preparado(efectivo=True);u,rm=self.driver();entrega=self.aceptar(u,order)
        self.recoger_todo(order);url=f'/api/repartidor/pedidos/{order}/entregar/'
        self.assertEqual(self.post(url,{'codigo':op.codigo_entrega(entrega)}).status_code,400)
        for _ in range(2):self.assertEqual(self.post(url,{'codigo':op.codigo_entrega(entrega),'efectivo_confirmado':True}).status_code,200)
        self.assertEqual(Pago.objects.filter(pedido_id=order,estado='aprobado').count(),1)
    def test_distancia_real_o_no_disponible(self):
        order=self.order();p=Pedido.objects.get(pk=order);self.assertIsNone(op.distancia(p))
        self.market.latitud=-12;self.market.longitud=-77;self.market.save()
        p.latitud=-12.01;p.longitud=-77.01;p.save();p=Pedido.objects.get(pk=order)
        self.assertGreater(op.distancia(p),1);self.assertLess(op.distancia(p),2)
    def test_comprador_no_accede_a_reparto(self):
        self.assertEqual(self.client.get('/api/repartidor/inicio/').status_code,403)

    def test_cambio_de_movilidades_sin_escalar_autorizacion(self):
        u,rm=self.driver();self.auth(u)
        for movilidad in ['a_pie','carretilla','bicicleta','moto','mototaxi','otro']:
            r=self.client.patch('/api/repartidor/mercado/',{'movilidad':movilidad,
                'placa':'ABC-123','descripcion_movilidad':'Vehículo de prueba','autorizado':False,'mercado_id':999},format='json')
            self.assertEqual(r.status_code,200,r.data)
            rm.refresh_from_db();self.assertEqual(rm.movilidad,movilidad)
            self.assertTrue(rm.autorizado);self.assertEqual(rm.mercado_id,self.market.pk)
            if movilidad in ['a_pie','carretilla','bicicleta']:self.assertIsNone(rm.placa)
        self.assertEqual(self.client.patch('/api/repartidor/mercado/',{'movilidad':'otro'},format='json').status_code,400)
        self.assertEqual(self.client.patch('/api/repartidor/mercado/',{'movilidad':'avion'},format='json').status_code,400)

    def test_no_cambiar_movilidad_con_entrega_activa(self):
        order=self.preparado();u,rm=self.driver();self.aceptar(u,order)
        self.assertEqual(self.client.patch('/api/repartidor/mercado/',{'movilidad':'moto'},format='json').status_code,400)
        rm.refresh_from_db();self.assertEqual(rm.movilidad,'a_pie')

    def test_operador_autoriza_solicitud_sin_perder_movilidad(self):
        u,rm=self.driver(autorizado=False)
        rm.movilidad='bicicleta';rm.save()
        call_command('autorizar_repartidor',celular=u.celular,stdout=StringIO())
        rm.refresh_from_db()
        self.assertTrue(rm.autorizado);self.assertTrue(rm.disponible)
        self.assertEqual(rm.movilidad,'bicicleta')

    def test_rechazo_de_oferta_no_asigna_y_otro_puede_aceptarla(self):
        order=self.preparado();u,rm=self.driver();self.auth(u)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'][0]['id'],order)
        self.assertFalse(Entrega.objects.exists())
        otro,_=self.driver('900000091');self.aceptar(otro,order)
        self.auth(u);self.assertEqual(self.client.get('/api/repartidor/inicio/').data['ofertas'],[])

    def test_flujo_completo_dos_vendedores_pago_local_y_entrega(self):
        # Recorre las APIs reales de cada rol, sin cotizar_demo ni asignar estados a mano.
        otro=Usuario.objects.create(nombres='Julio',celular='900000088',password_hash=make_password('x'))
        UsuarioRol.objects.create(usuario_id=otro.pk,rol_codigo='vendedor')
        Puesto.objects.filter(pk=self.stall2.pk).update(vendedor=otro)
        order=self.order()
        for vendedor,puesto in [(self.seller,self.stall),(otro,self.stall2)]:
            self.auth(vendedor)
            parte=PedidoPuesto.objects.get(pedido_id=order,puesto_id=puesto.pk)
            r=self.client.patch(f'/api/vendedor/pedidos/{parte.pk}/accion/',{'accion':'aceptar'},format='json')
            self.assertEqual(r.status_code,200,r.data)
            filas=[]
            for detalle in PedidoDetalle.objects.filter(pedido_puesto=parte):
                r=self.client.patch(f'/api/vendedor/detalles/{detalle.pk}/',{'disponibilidad':'disponible'},format='json')
                self.assertEqual(r.status_code,200,r.data)
                filas.append({'pedido_detalle_id':detalle.pk,'nombre_final':detalle.nombre_solicitado,
                    'cantidad_real':str(detalle.cantidad_solicitada),'precio_unitario':str(detalle.precio_estimado_unitario)})
            r=self.post(f'/api/vendedor/pedidos/{parte.pk}/cotizacion/',{'detalles':filas})
            self.assertEqual(r.status_code,201,r.data)
        self.auth(self.user)
        quote=Cotizacion.objects.get(pedido_id=order)
        self.assertEqual(self.post(f'/api/pedidos/{order}/cotizaciones/{quote.pk}/aceptar/',{}).status_code,200)
        self.assertEqual(self.pay(order).status_code,200)
        u,rm=self.driver();entrega=self.aceptar(u,order)
        self.assertEqual(self.client.get('/api/repartidor/inicio/').data['en_curso']['ganancia_repartidor_centavos'],500)
        for vendedor,puesto in [(self.seller,self.stall),(otro,self.stall2)]:
            self.auth(vendedor);parte=PedidoPuesto.objects.get(pedido_id=order,puesto_id=puesto.pk)
            self.assertEqual(self.client.patch(f'/api/vendedor/pedidos/{parte.pk}/accion/',{'accion':'listo'},format='json').status_code,200)
            self.auth(u);self.assertEqual(self.accion(order,'recoger',parte.pk).status_code,200)
        self.assertEqual(self.accion(order,'salir').status_code,200)
        self.assertEqual(self.accion(order,'llegue').status_code,200)
        self.auth(self.user);datos=self.client.get('/api/comprador/pedidos/').data[0]
        self.assertTrue(any('llegó' in h['texto'] for h in datos['historial']))
        self.auth(u)
        self.assertEqual(self.post(f'/api/repartidor/pedidos/{order}/entregar/',{'codigo':datos['codigo_entrega']}).status_code,200)
        inicio=self.client.get('/api/repartidor/inicio/').data
        self.assertIsNone(inicio['en_curso']);self.assertEqual(inicio['ganancia_hoy_centavos'],500)
        self.assertEqual(inicio['entregas_hoy'],1)
