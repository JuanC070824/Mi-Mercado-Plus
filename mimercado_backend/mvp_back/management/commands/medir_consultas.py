import time
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from mvp_back.authentication import issue_token
from mvp_back.models import Usuario

# Pantallas que más se refrescan. Con la base en la nube cada consulta es un viaje de red.
RUTAS=[('comprador','/api/carrito/'),
       ('comprador','/api/comprador/pedidos/?vigente=1'),('comprador','/api/comprador/pedidos/'),
       ('vendedor','/api/vendedor/pedidos/'),('repartidor','/api/repartidor/inicio/')]

class Command(BaseCommand):
    help='Cuenta las consultas SQL y el tiempo de las pantallas principales (para detectar consultas de más).'
    def add_arguments(self,parser):
        parser.add_argument('--comprador',default='900000001')
        parser.add_argument('--vendedor',default='900000011')
        parser.add_argument('--repartidor',default='900000090')
    def handle(self,*args,**opts):
        settings.ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS,'testserver']
        for rol,url in RUTAS:
            usuario=Usuario.objects.filter(celular=opts[rol]).first()
            if usuario is None:raise CommandError(f'No existe la cuenta {opts[rol]} ({rol}).')
            cliente=APIClient()
            cliente.credentials(HTTP_AUTHORIZATION='Bearer '+issue_token(usuario))
            with CaptureQueriesContext(connection) as consultas:
                inicio=time.perf_counter()
                respuesta=cliente.get(url)
                ms=(time.perf_counter()-inicio)*1000
            self.stdout.write(f'{respuesta.status_code}  {len(consultas):3d} consultas  {ms:7.0f} ms  {url}')
