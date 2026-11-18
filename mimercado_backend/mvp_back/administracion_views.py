"""Administración desde la app (RF-05, RF-18): mercados y solicitudes de repartidores.

Solo para cuentas con el rol `administrador` (se asigna con `asignar_administrador`).
"""
from django.db.models import Count
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from . import operaciones as op
from . import serializers as s
from .models import Entrega, Mercado, Puesto, RepartidorMercado, UsuarioRol
from .authentication import tiene_rol

def exigir_administrador(user):
    if not tiene_rol(user,'administrador'):
        raise PermissionDenied('Esta opción es solo para el administrador del mercado.')

def mercado_payload(m,puestos=0):
    return {'id':m.pk,'nombre':m.nombre,'direccion':m.direccion,'distrito':m.distrito,'estado':m.estado,
            'latitud':None if m.latitud is None else str(m.latitud),
            'longitud':None if m.longitud is None else str(m.longitud),'puestos':puestos}

class AdminRepartidoresView(APIView):
    """Solicitudes vigentes: primero las pendientes de autorizar."""
    def get(self,request):
        exigir_administrador(request.user)
        filas=list(RepartidorMercado.objects.filter(fin_en__isnull=True).select_related('repartidor','mercado')
                   .order_by('autorizado','-inicio_en'))
        en_curso=set(Entrega.objects.filter(repartidor_mercado_id__in=[r.pk for r in filas],estado__in=op.VIGENTES)
                     .values_list('repartidor_mercado_id',flat=True))
        return Response([{'id':r.pk,'nombre':op.nombre(r.repartidor),'celular':r.repartidor.celular,
            'mercado':{'id':r.mercado_id,'nombre':r.mercado.nombre},'movilidad':r.movilidad,'placa':r.placa,
            'descripcion_movilidad':r.descripcion_movilidad,'autorizado':r.autorizado,'disponible':r.disponible,
            'entrega_en_curso':r.pk in en_curso} for r in filas])

class AdminRepartidorAccionView(APIView):
    def post(self,request,solicitud_id,accion):
        exigir_administrador(request.user)
        if accion not in ('autorizar','quitar'):raise NotFound('Acción no válida.')
        rm=RepartidorMercado.objects.filter(pk=solicitud_id,fin_en__isnull=True).first()
        if rm is None:raise NotFound('La solicitud ya no está vigente.')
        motivo=(op.autorizar_solicitud if accion=='autorizar' else op.quitar_autorizacion)(rm)
        if motivo:raise ValidationError(f'No se pudo: {motivo}.')
        rm.refresh_from_db()
        return Response({'id':rm.pk,'autorizado':rm.autorizado,'disponible':rm.disponible})

class AdminMercadosView(APIView):
    def get(self,request):
        exigir_administrador(request.user)
        conteo={r['mercado_id']:r['n'] for r in Puesto.objects.filter(estado='activo').values('mercado_id').annotate(n=Count('id'))}
        return Response([mercado_payload(m,conteo.get(m.pk,0)) for m in Mercado.objects.order_by('nombre')])
    def post(self,request):
        exigir_administrador(request.user)
        ser=s.MercadoAdminSerializer(data=request.data);ser.is_valid(raise_exception=True)
        d=ser.validated_data
        m=Mercado.objects.create(nombre=d['nombre'].strip(),direccion=d['direccion'].strip(),
            distrito=(d.get('distrito') or '').strip() or None,estado=d.get('estado','activo'),
            latitud=d.get('latitud'),longitud=d.get('longitud'))
        return Response(mercado_payload(m),status=201)

class AdminMercadoView(APIView):
    def patch(self,request,mercado_id):
        exigir_administrador(request.user)
        m=Mercado.objects.filter(pk=mercado_id).first()
        if m is None:raise NotFound('Mercado no encontrado.')
        ser=s.MercadoAdminSerializer(data={**{'nombre':m.nombre,'direccion':m.direccion},**request.data},partial=True)
        ser.is_valid(raise_exception=True)
        d=ser.validated_data
        for campo in ['nombre','direccion']:
            if campo in d:setattr(m,campo,d[campo].strip())
        if 'distrito' in d:m.distrito=d['distrito'].strip() or None
        if 'estado' in d:m.estado=d['estado']
        if 'latitud' in d:m.latitud,m.longitud=d['latitud'],d['longitud']
        m.save()
        return Response(mercado_payload(m))
