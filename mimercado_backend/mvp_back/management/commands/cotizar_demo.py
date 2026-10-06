from decimal import Decimal
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import transaction
from django.db.models import Max
from mvp_back.models import Pedido,PedidoPuesto,PedidoDetalle,Cotizacion,CotizacionPuesto,CotizacionDetalle,HistorialEstado
from mvp_back.services import quote_total

class Command(BaseCommand):
    help='Simula el pesaje y publica una cotización. Solo para demostraciones en modo mock.'
    def add_arguments(self,parser):
        parser.add_argument('--pedido',type=int,required=True)
        parser.add_argument('--envio-centavos',type=int,default=500)
    @transaction.atomic
    def handle(self,*args,**opts):
        if settings.PAYMENT_MODE!='mock':raise CommandError('Este comando solo se permite en modo mock.')
        if opts['envio_centavos']<0:raise CommandError('El envío no puede ser negativo.')
        try:order=Pedido.objects.select_for_update().get(pk=opts['pedido'])
        except Pedido.DoesNotExist:raise CommandError('Pedido no encontrado.')
        if order.estado in ['cancelado','entregado']:raise CommandError('El pedido está cerrado.')
        if Cotizacion.objects.filter(pedido_id=order.pk,estado='aceptada').exists():raise CommandError('Ya tiene un precio aceptado.')
        Cotizacion.objects.filter(pedido_id=order.pk,estado__in=['borrador','enviada']).update(estado='reemplazada')
        version=(Cotizacion.objects.filter(pedido_id=order.pk).aggregate(n=Max('version'))['n'] or 0)+1
        quote=Cotizacion.objects.create(pedido_id=order.pk,version=version,costo_envio=Decimal(opts['envio_centavos'])/100,
                                       ganancia_repartidor=Decimal(opts['envio_centavos'])/100)
        for sub in PedidoPuesto.objects.filter(pedido_id=order.pk).exclude(estado__in=['rechazado','cancelado']):
            group=CotizacionPuesto.objects.create(cotizacion_id=quote.pk,pedido_id=order.pk,pedido_puesto_id=sub.pk)
            for detail in PedidoDetalle.objects.filter(pedido_puesto_id=sub.pk):
                CotizacionDetalle.objects.create(cotizacion_puesto_id=group.pk,pedido_puesto_id=sub.pk,
                    pedido_detalle_id=detail.pk,nombre_final=detail.nombre_solicitado,producto_final_id=detail.producto_id,
                    puesto_id=sub.puesto_id,unidad_codigo=detail.unidad_codigo,cantidad_real=detail.cantidad_solicitada,
                    precio_unitario=detail.precio_estimado_unitario)
                detail.disponibilidad='disponible'
                detail.save(update_fields=['disponibilidad'])
            sub.estado='pesado'
            sub.save(update_fields=['estado'])
        total=quote_total(quote)
        quote.estado='enviada'
        quote.save(update_fields=['estado'])
        order.estado='esperando_confirmacion'
        order.save(update_fields=['estado'])
        HistorialEstado.objects.create(pedido_id=order.pk,estado=order.estado,observacion='Cotización DEMO; no es un pesaje real.')
        self.stdout.write(self.style.SUCCESS(f'Cotización {quote.pk} enviada. Total S/{total}. El comprador debe aceptarla vía API.'))
