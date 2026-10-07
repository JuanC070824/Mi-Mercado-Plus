from decimal import Decimal
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import transaction
from django.contrib.auth.hashers import make_password
from mvp_back.models import Rol,Usuario,UsuarioRol,Mercado,Categoria,Puesto,Producto,UnidadMedida

class Command(BaseCommand):
    help='Crea dos puestos del mismo mercado para una demostración local; solo PAYMENT_MODE=mock.'
    @transaction.atomic
    def handle(self,*args,**options):
        if settings.PAYMENT_MODE!='mock':raise CommandError('Este comando solo se permite en modo mock.')
        if not Rol.objects.filter(pk='vendedor').exists():raise CommandError('Instala primero el esquema SQL v1.')
        unit=UnidadMedida.objects.get(pk='kg')
        category=Categoria.objects.get(nombre='Verduras y frutas')
        market,_=Mercado.objects.get_or_create(nombre='Mercado DEMO MVP',direccion='Dirección ficticia DEMO')
        for phone,name,stall,product,price in [('900000011','Casera Demo','Verdulería DEMO','Tomate DEMO','4.00'),('900000012','Casero Demo','Carnicería DEMO','Pollo DEMO','10.00')]:
            user,created=Usuario.objects.get_or_create(celular=phone,defaults={'nombres':name,'password_hash':make_password(None)})
            if not created and user.nombres!=name:raise CommandError('Un celular demo pertenece a otro usuario. No se modificó.')
            UsuarioRol.objects.get_or_create(usuario_id=user.pk,rol_codigo='vendedor')
            puesto,_=Puesto.objects.get_or_create(mercado_id=market.pk,nombre=stall,defaults={'vendedor_id':user.pk,'categoria_id':category.pk,'abierto':True})
            row,_=Producto.objects.get_or_create(puesto_id=puesto.pk,nombre=product,defaults={'unidad_codigo':unit.pk,'precio_unitario':Decimal(price)})
            self.stdout.write(f'Producto {row.pk}: {row.nombre}, puesto {puesto.pk}, mercado {market.pk}')
        self.stdout.write(self.style.SUCCESS('Catálogo DEMO listo. Registra al comprador mediante la API.'))
