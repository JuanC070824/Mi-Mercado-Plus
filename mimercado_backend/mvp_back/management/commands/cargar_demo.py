from decimal import Decimal
from io import StringIO
from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from rest_framework.test import APIClient
from mvp_back.authentication import issue_token
from mvp_back.models import (Categoria,Cotizacion,Direccion,Mercado,PedidoPuesto,Producto,Puesto,
                             RepartidorMercado,Usuario,UsuarioRol)

class Command(BaseCommand):
    help=('Cuentas de prueba (cliente, 2 caseros, repartidor autorizado) y 2 pedidos listos para repartir. '
          'Solo en modo mock. Requiere el catálogo (cargar_catalogo).')
    def add_arguments(self,parser):
        parser.add_argument('--mercado',default='Mercado Unidad Vecinal 3')
        parser.add_argument('--clave',default='DemoSegura!42')
    def handle(self,*args,**opts):
        if settings.PAYMENT_MODE!='mock':raise CommandError('Este comando solo se permite en modo mock.')
        mercado=Mercado.objects.filter(nombre=opts['mercado']).first()
        if mercado is None:raise CommandError('No existe el mercado: ejecuta primero cargar_catalogo.')
        cat={c.nombre:c for c in Categoria.objects.all()}
        def usuario(nombre,celular,rol):
            u,_=Usuario.objects.get_or_create(celular=celular,defaults={'nombres':nombre,'password_hash':make_password(opts['clave'])})
            UsuarioRol.objects.get_or_create(usuario_id=u.pk,rol_codigo=rol)
            return u
        rosa,julio=usuario('Rosa','900000011','vendedor'),usuario('Julio','900000012','vendedor')
        p1,_=Puesto.objects.get_or_create(mercado_id=mercado.pk,nombre='Verduras Rosa',defaults={
            'vendedor_id':rosa.pk,'categoria_id':cat['Verduras y frutas'].pk,'abierto':True})
        p2,_=Puesto.objects.get_or_create(mercado_id=mercado.pk,nombre='Carnicería Julio',defaults={
            'vendedor_id':julio.pk,'categoria_id':cat['Carnes y aves'].pk,'abierto':True})
        productos=[Producto.objects.get_or_create(puesto_id=puesto.pk,nombre=nombre,defaults={
            'unidad_codigo':'kg','precio_unitario':Decimal(precio),'stock':Decimal('50')})[0]
            for puesto,nombre,precio in [(p1,'Tomate','4.00'),(p1,'Papa amarilla','3.50'),(p1,'Limón','6.00'),
                                         (p2,'Pollo','10.00'),(p2,'Carne molida','22.00')]]
        maria=usuario('María','900000001','comprador')
        direccion,_=Direccion.objects.get_or_create(comprador_id=maria.pk,direccion='Av. Venezuela 3400, Lima',
                                                    defaults={'referencia':'Portón verde','principal':True})
        ernesto=usuario('Ernesto','900000090','repartidor')
        RepartidorMercado.objects.get_or_create(repartidor=ernesto,mercado=mercado,defaults={
            'movilidad':'bicicleta','autorizado':True,'disponible':True})
        if PedidoPuesto.objects.filter(pedido__comprador_id=maria.pk).exists():
            self.stdout.write('La clienta de prueba ya tiene pedidos: no se crean más.')
            return
        # Los pedidos pasan por la API real, igual que desde la app.
        settings.ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS,'testserver']
        cliente=APIClient()
        cliente.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(maria))
        def post(url,data):
            r=cliente.post(url,data,format='json')
            if r.status_code not in (200,201):raise CommandError(f'{url}: {r.status_code} {r.data}')
            return r
        def pedido(metodo,estados):
            for prod,cant in [(productos[0],'1.000'),(productos[3],'1.500')]:
                post('/api/carrito/items/',{'producto_id':prod.pk,'cantidad':cant})
            pid=post('/api/pedidos/',{'direccion_id':direccion.pk,'metodo_pago':metodo}).data['id']
            call_command('cotizar_demo',pedido=pid,envio_centavos=500,stdout=StringIO())
            post(f'/api/pedidos/{pid}/cotizaciones/{Cotizacion.objects.get(pedido_id=pid).pk}/aceptar/',{})
            if metodo=='yape':
                post('/api/pagos/yape/',{'pedido_id':pid,'celular':maria.celular,'codigo':settings.MOCK_YAPE_CODE,
                                         'idempotencia':f'demo_pago_{pid:06d}'})
            for parte,estado in zip(PedidoPuesto.objects.filter(pedido_id=pid).order_by('id'),estados):
                PedidoPuesto.objects.filter(pk=parte.pk).update(estado=estado)
            return pid
        a=pedido('yape',['listo','en_preparacion'])
        b=pedido('efectivo',['listo','listo'])
        self.stdout.write(self.style.SUCCESS(
            f'Cuentas de prueba listas (cliente 900000001, repartidor 900000090, caseros 900000011 y 900000012). '
            f'Pedidos para repartir: #{a} (Yape) y #{b} (efectivo).'))
