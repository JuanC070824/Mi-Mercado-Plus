import re
from decimal import Decimal
from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from mvp_back.models import Categoria,Mercado,Producto,Puesto,Usuario,UsuarioRol

# Catálogo que diseñó el equipo; la app lo usa como datos de prueba sin backend.
FUENTE=settings.BASE_DIR.parent/'mimercado_frontend'/'lib'/'data'/'repositories'/'catalogo_repository.dart'
CATEGORIAS={'verduras':'Verduras y frutas','carnes':'Carnes y aves','abarrotes':'Abarrotes','pescados':'Pescados y mariscos'}

def bloques(texto,clase):
    """Campos (como texto) de cada `Clase(...)` del catálogo de Dart."""
    salida=[]
    for cuerpo in re.findall(rf'(?:const\s+)?\b{clase}\(\s*\n(.*?)\n\s*\),',texto,re.S):
        salida.append(dict((k,v.strip().rstrip(',')) for k,v in re.findall(r'^\s*(\w+):\s*(.+?),?\s*$',cuerpo,re.M)))
    return salida

def cadena(valor):
    return valor[1:-1].replace("\\'","'") if valor and valor[0] in "'\"" else valor

class Command(BaseCommand):
    help='Carga los mercados, puestos y productos del catálogo del equipo. No duplica si se repite.'
    def add_arguments(self,parser):
        parser.add_argument('--clave',default='DemoSegura!42',help='Contraseña de las cuentas de los caseros de prueba.')
        parser.add_argument('--plan',action='store_true',help='Solo muestra qué se cargaría.')
    @transaction.atomic
    def handle(self,*args,**opts):
        try:texto=FUENTE.read_text(encoding='utf-8').split('class CatalogoRepositoryMock',1)[1]
        except (OSError,IndexError):raise CommandError(f'No se encontró el catálogo en {FUENTE}.')
        mercados,puestos,productos=bloques(texto,'Mercado'),bloques(texto,'Puesto'),bloques(texto,'Producto')
        self.stdout.write(f'Catálogo: {len(mercados)} mercados, {len(puestos)} puestos, {len(productos)} productos.')
        if opts['plan']:return
        categorias={c.nombre:c for c in Categoria.objects.filter(nombre__in=CATEGORIAS.values())}
        if len(categorias)<len(CATEGORIAS):raise CommandError('Faltan categorías: ejecuta primero el script SQL de la base.')
        id_mercado,id_puesto={},{}
        for m in mercados:
            obj,_=Mercado.objects.get_or_create(nombre=cadena(m['nombre']),defaults={'direccion':cadena(m['direccion'])})
            obj.direccion=cadena(m['direccion'])
            obj.distrito=cadena(m.get('distrito',"''")) or None
            obj.provincia=obj.departamento='Lima'
            obj.latitud=Decimal(m['latitud']).quantize(Decimal('0.000001')) if 'latitud' in m else None
            obj.longitud=Decimal(m['longitud']).quantize(Decimal('0.000001')) if 'longitud' in m else None
            obj.save()
            id_mercado[m['id']]=obj
        for p in puestos:
            casero=cadena(p['casero']).split()
            # Celular ficticio y único por casero de prueba: 91 + id del puesto.
            vendedor,_=Usuario.objects.get_or_create(celular=f'91{int(p["id"]):07d}',defaults={
                'nombres':casero[0],'apellido_paterno':' '.join(casero[1:]) or None,'password_hash':make_password(opts['clave'])})
            UsuarioRol.objects.get_or_create(usuario_id=vendedor.pk,rol_codigo='vendedor')
            id_puesto[p['id']],_=Puesto.objects.get_or_create(mercado_id=id_mercado[p['mercadoId']].pk,nombre=cadena(p['nombre']),
                defaults={'vendedor_id':vendedor.pk,'categoria_id':categorias[CATEGORIAS[p['categoria'].split('.')[-1]]].pk,
                          'abierto':p.get('abierto','true')!='false'})
        nuevos=0
        for pr in productos:
            if pr['puestoId'] not in id_puesto:continue
            _,creado=Producto.objects.get_or_create(puesto_id=id_puesto[pr['puestoId']].pk,nombre=cadena(pr['nombre']),defaults={
                'unidad_codigo':pr['unidad'].split('.')[-1],'precio_unitario':Decimal(pr['precioUnitario']).quantize(Decimal('0.01')),
                'disponible':pr.get('disponible','true')!='false','stock':Decimal('50')})
            nuevos+=creado
        self.stdout.write(self.style.SUCCESS(
            f'Base: {Mercado.objects.count()} mercados, {Puesto.objects.count()} puestos, {Producto.objects.count()} productos ({nuevos} nuevos).'))
