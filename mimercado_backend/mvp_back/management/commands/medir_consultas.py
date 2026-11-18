import time
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from mvp_back.authentication import issue_token
from mvp_back.models import Puesto, Usuario

# Pantallas de lectura de la app. Con la base en la nube cada consulta es un viaje de red.
RUTAS=[(None,'/api/mercados/'),(None,'/api/categorias/'),(None,'/api/puestos/'),
       (None,'/api/puestos/?mercado_id={mercado}'),(None,'/api/productos/?puesto_id={puesto}'),
       ('comprador','/api/auth/me/'),('comprador','/api/carrito/'),
       ('comprador','/api/direcciones/'),('comprador','/api/comprador/recomendaciones/'),
       ('comprador','/api/comprador/pedidos/?vigente=1'),('comprador','/api/comprador/pedidos/'),
       ('vendedor','/api/vendedor/inicio/'),('vendedor','/api/vendedor/puesto/'),
       ('vendedor','/api/vendedor/productos/'),('vendedor','/api/vendedor/pedidos/'),
       ('repartidor','/api/repartidor/inicio/')]

class Command(BaseCommand):
    help='Cuenta las consultas SQL y el tiempo de las pantallas principales (para detectar consultas de más).'
    def add_arguments(self,parser):
        parser.add_argument('--comprador',default='900000001')
        parser.add_argument('--vendedor',default='900000011')
        parser.add_argument('--repartidor',default='900000090')
        parser.add_argument('--sql',default='',help='Muestra el SQL de las rutas que contengan este texto.')
    def handle(self,*args,**opts):
        settings.ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS,'testserver']
        puesto=Puesto.objects.filter(vendedor__celular=opts['vendedor']).first() or Puesto.objects.first()
        if puesto is None:raise CommandError('No hay puestos cargados.')
        for rol,plantilla in RUTAS:
            url=plantilla.format(mercado=puesto.mercado_id,puesto=puesto.pk)
            cliente=APIClient()
            if rol:
                usuario=Usuario.objects.filter(celular=opts[rol]).first()
                if usuario is None:raise CommandError(f'No existe la cuenta {opts[rol]} ({rol}).')
                cliente.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(usuario))
            with CaptureQueriesContext(connection) as consultas:
                inicio=time.perf_counter()
                respuesta=cliente.get(url)
                ms=(time.perf_counter()-inicio)*1000
            self.stdout.write(f'{respuesta.status_code}  {len(consultas):3d} consultas  {ms:7.0f} ms  {url}')
            if opts['sql'] and opts['sql'] in url:
                for q in consultas.captured_queries:
                    self.stdout.write('      '+q['sql'][:200])
