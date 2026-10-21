from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone
from mvp_back.models import Usuario, UsuarioRol, Mercado, RepartidorMercado, Entrega

class Command(BaseCommand):
    help='Autoriza un repartidor en un mercado. Solo para el responsable con acceso al servidor.'
    def add_arguments(self,parser):
        parser.add_argument('--celular',required=True)
        parser.add_argument('--mercado',type=int,help='Si se omite, autoriza el mercado solicitado desde la app.')
        parser.add_argument('--movilidad',choices=['a_pie','carretilla','bicicleta','moto','mototaxi','otro'])
        parser.add_argument('--placa')
        parser.add_argument('--descripcion')
    @transaction.atomic
    def handle(self,*args,**opts):
        user=Usuario.objects.select_for_update().filter(celular=opts['celular'],estado='activo').first()
        if user is None or not UsuarioRol.objects.filter(usuario_id=user.pk,rol_codigo='repartidor').exists():
            raise CommandError('Debe existir una cuenta activa con rol repartidor.')
        actual=RepartidorMercado.objects.filter(repartidor_id=user.pk,fin_en__isnull=True).order_by('id').first()
        mercado_id=opts['mercado'] or (actual.mercado_id if actual else None)
        mercado=Mercado.objects.filter(pk=mercado_id,estado='activo').first()
        if mercado is None: raise CommandError('Solicita un mercado desde la app o indica --mercado con un mercado activo.')
        if actual and Entrega.objects.filter(repartidor_mercado_id=actual.pk,estado__in=['asignada','aceptada','en_recojo','en_camino']).exists():
            raise CommandError('El repartidor tiene una entrega en curso.')
        movilidad=opts['movilidad'] or (actual.movilidad if actual else 'a_pie')
        placa=opts['placa'] if opts['placa'] is not None else ((actual.placa or '') if actual else '')
        descripcion=opts['descripcion'] if opts['descripcion'] is not None else ((actual.descripcion_movilidad or '') if actual else '')
        if len(placa)>20: raise CommandError('La placa admite hasta 20 caracteres.')
        if len(descripcion)>150: raise CommandError('La descripción admite hasta 150 caracteres.')
        if movilidad=='otro' and not descripcion.strip(): raise CommandError('Describe la otra movilidad con --descripcion.')
        if actual and actual.mercado_id!=mercado.pk:
            actual.disponible=False;actual.fin_en=timezone.now();actual.save(update_fields=['disponible','fin_en']);actual=None
        if actual is None: actual=RepartidorMercado(repartidor_id=user.pk,mercado=mercado)
        actual.movilidad=movilidad;actual.placa=placa or None
        actual.descripcion_movilidad=descripcion.strip() or None
        actual.autorizado=True;actual.disponible=True;actual.save()
        self.stdout.write(self.style.SUCCESS('Repartidor autorizado en el mercado seleccionado.'))
