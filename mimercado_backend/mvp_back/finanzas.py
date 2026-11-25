"""Saldos informativos derivados de pagos y entregas; no realizan transferencias."""
from collections import defaultdict
from decimal import Decimal
from django.db.models import Sum
from .models import Cotizacion, CotizacionPuesto, CotizacionDetalle, Pago
from .money import cents, soles


ESTADOS_CON_PAGO = ['en_preparacion', 'listo_para_recojo', 'en_recojo', 'en_camino', 'entregado']


def pagos_confirmados(pedido_ids, cargado=None):
    """Una entrada por pedido, solo para su cotización aceptada y monto íntegro.

    `cargado` reutiliza lo que el llamador ya leyó (pedidos, su última
    cotización, sus puestos cotizados y sus detalles) y ahorra tres consultas.
    Una cotización aceptada ya no admite versiones nuevas, así que si existe es
    siempre la última del pedido.
    """
    if cargado is None:
        quotes = {q.pk: q for q in Cotizacion.objects.filter(
            pedido_id__in=pedido_ids, estado='aceptada', pedido__estado__in=ESTADOS_CON_PAGO)}
        grupos = list(CotizacionPuesto.objects.filter(cotizacion_id__in=quotes))
        subtotales = {r['cotizacion_puesto_id']: r['total'] for r in
            CotizacionDetalle.objects.filter(cotizacion_puesto_id__in=[g.pk for g in grupos])
            .values('cotizacion_puesto_id').annotate(total=Sum('subtotal'))}
    else:
        estados = {p.pk: p.estado for p in cargado['pedidos']}
        quotes = {q.pk: q for q in cargado['quotes'].values()
                  if q.estado == 'aceptada' and estados.get(q.pedido_id) in ESTADOS_CON_PAGO}
        grupos = [g for g in cargado['grupos'] if g.cotizacion_id in quotes]
        subtotales = cargado['subtotales']
    totales = defaultdict(Decimal)
    for g in grupos:
        totales[g.cotizacion_id] += subtotales.get(g.pk, Decimal(0))
    resultado = {}
    for pago in Pago.objects.filter(cotizacion_id__in=quotes, estado='aprobado',
                                    moneda='PEN').order_by('-id'):
        q = quotes[pago.cotizacion_id]
        if pago.pedido_id != q.pedido_id or pago.monto != soles(totales[q.pk] + q.costo_envio):
            continue
        resultado.setdefault(pago.pedido_id, {
            'pago_aprobado': True,
            'pago_metodo': 'Mercado Pago' if (pago.proveedor_transaccion_id or '').startswith('mp_test_')
                           else pago.metodo.capitalize(),
            'ganancia_repartidor_centavos': cents(q.ganancia_repartidor),
            'puestos': {},
        })
    for g in grupos:
        datos = resultado.get(g.pedido_id)
        if datos is None:
            continue
        bruto = cents(subtotales.get(g.pk, Decimal(0)))
        comision = cents(subtotales.get(g.pk, Decimal(0)) * g.tasa_comision)
        datos['puestos'][g.pedido_puesto_id] = {
            'ventas_centavos': bruto, 'comision_centavos': comision,
            'recibes_centavos': bruto - comision,
        }
    return resultado
