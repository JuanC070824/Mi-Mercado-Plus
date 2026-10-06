from django.contrib.auth.hashers import make_password, check_password
from django.db import transaction, IntegrityError
from django.db.models import Q
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, NotFound
from rest_framework.throttling import ScopedRateThrottle
from . import serializers as s
from .models import Usuario, UsuarioRol, Producto, Mercado, Puesto, Direccion, Pedido, Cotizacion
from .authentication import issue_token
from .services import put_item, cart_payload, change_item, checkout, require_buyer, accept_quote, quote_total, lock_user
from .payments import pay_order
from .money import cents


def validated(cls, data):
    serializer=cls(data=data)
    serializer.is_valid(raise_exception=True)
    return serializer.validated_data


def user_payload(user):
    return {'id':user.pk,'nombres':user.nombres,'celular':user.celular,
            'roles':list(UsuarioRol.objects.filter(usuario_id=user.pk).values_list('rol_codigo',flat=True))}


def auth_payload(user):
    return {'token':issue_token(user),'token_type':'Bearer','expires_in':settings.AUTH_TOKEN_TTL_SECONDS,
            'usuario':user_payload(user)}

class RegistroView(APIView):
    permission_classes=[AllowAny]
    authentication_classes=[]
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='registro'
    def post(self,request):
        data=validated(s.RegistroSerializer,request.data)
        password=data.pop('password')
        data['correo']=data.get('correo','').lower() or None
        if Usuario.objects.filter(celular=data['celular']).exists() or (data['correo'] and Usuario.objects.filter(correo__iexact=data['correo']).exists()):
            raise ValidationError('El celular o correo ya está registrado.')
        try:
            with transaction.atomic():
                user=Usuario.objects.create(**data,password_hash=make_password(password))
                UsuarioRol.objects.create(usuario_id=user.pk,rol_codigo='comprador')
        except IntegrityError:
            raise ValidationError('No se pudo registrar: datos duplicados o catálogo de roles no instalado.')
        return Response(auth_payload(user),status=201)

class LoginView(APIView):
    permission_classes=[AllowAny]
    authentication_classes=[]
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='login'
    def post(self,request):
        data=validated(s.LoginSerializer,request.data)
        user=Usuario.objects.filter(celular=data['celular']).first()
        if user is None:
            make_password(data['password'])  # costo similar para un celular inexistente
        if user is None or not check_password(data['password'],user.password_hash) or user.estado!='activo':
            return Response({'detail':'Celular o contraseña incorrectos.'},status=401)
        return Response(auth_payload(user))

class PerfilView(APIView):
    def get(self,request):
        return Response(user_payload(request.user))

class MercadosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        return Response(list(Mercado.objects.filter(estado='activo').values('id','nombre','direccion')))

class PuestosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        rows=Puesto.objects.filter(estado='activo',mercado__estado='activo')
        market=request.query_params.get('mercado_id')
        if market:
            if not market.isdecimal():raise ValidationError('mercado_id debe ser entero.')
            rows=rows.filter(mercado_id=int(market))
        return Response(list(rows.values('id','nombre','mercado_id','abierto')))

class ProductosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        rows=Producto.objects.filter(activo=True,puesto__estado='activo',puesto__mercado__estado='activo').order_by('id')
        for key in ['puesto_id','puesto__mercado_id']:
            value=request.query_params.get('mercado_id' if '__' in key else key)
            if value:
                if not value.isdecimal():raise ValidationError('El filtro debe ser entero.')
                rows=rows.filter(**{key:int(value)})
        return Response([{'id':p.pk,'puesto_id':p.puesto_id,'nombre':p.nombre,
            'unidad':p.unidad_codigo,'precio_unitario_centavos':cents(p.precio_unitario),
            'disponible':p.disponible,'stock':None if p.stock is None else str(p.stock)} for p in rows[:200]])

class CarritoView(APIView):
    def get(self,request):
        return Response(cart_payload(request.user))

class CarritoItemsView(APIView):
    def post(self,request):
        data=validated(s.ItemSerializer,request.data)
        return Response(put_item(request.user,data['producto_id'],data['cantidad']))

class CarritoItemView(APIView):
    def patch(self,request,item_id):
        data=validated(s.CantidadSerializer,request.data)
        return Response(change_item(request.user,item_id,data['cantidad']))
    def delete(self,request,item_id):
        return Response(change_item(request.user,item_id))

class DireccionesView(APIView):
    def get(self,request):
        require_buyer(request.user)
        return Response(list(Direccion.objects.filter(comprador_id=request.user.pk,activa=True).values(
            'id','etiqueta','direccion','referencia','principal')))
    def post(self,request):
        require_buyer(request.user)
        data=validated(s.DireccionSerializer,request.data)
        with transaction.atomic():
            lock_user(request.user)
            if data['principal']:
                Direccion.objects.filter(comprador_id=request.user.pk,principal=True,activa=True).update(principal=False)
            row=Direccion.objects.create(comprador_id=request.user.pk,**data)
        return Response({'id':row.pk,'direccion':row.direccion},status=201)

class PedidosView(APIView):
    def get(self,request):
        require_buyer(request.user)
        return Response(list(Pedido.objects.filter(comprador_id=request.user.pk).order_by('-id').values('id','codigo','estado','metodo_pago')[:100]))
    def post(self,request):
        data=validated(s.PedidoSerializer,request.data)
        order=checkout(request.user,data['direccion_id'],data['metodo_pago'])
        return Response({'id':order.pk,'codigo':order.codigo,'estado':order.estado,
                         'detail':'Pedido creado. El casero debe pesar y enviar la cotización final.'},status=201)

class PedidoView(APIView):
    def get(self,request,order_id):
        require_buyer(request.user)
        try:order=Pedido.objects.get(pk=order_id,comprador_id=request.user.pk)
        except Pedido.DoesNotExist:raise NotFound('Pedido no encontrado.')
        quotes=[]
        for quote in Cotizacion.objects.filter(pedido_id=order.pk).order_by('-version'):
            total=None
            if quote.estado in ['enviada','aceptada']:
                total=cents(quote_total(quote))
            quotes.append({'id':quote.pk,'version':quote.version,'estado':quote.estado,'total_centavos':total})
        return Response({'id':order.pk,'codigo':order.codigo,'estado':order.estado,
                         'metodo_pago':order.metodo_pago,'cotizaciones':quotes})

class AceptarCotizacionView(APIView):
    def post(self,request,order_id,quote_id):
        quote=accept_quote(request.user,order_id,quote_id)
        return Response({'id':quote.pk,'estado':quote.estado,'total_centavos':cents(quote_total(quote))})

class PagoView(APIView):
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='pago'
    def post(self,request):
        data=validated(s.PagoSerializer,request.data)
        result,status=pay_order(request.user,data)
        return Response(result,status=status)

class CancelarPedidoView(APIView):
    def post(self,request,order_id):
        from .services import cancel_order
        order=cancel_order(request.user,order_id)
        return Response({'id':order.pk,'estado':order.estado})
