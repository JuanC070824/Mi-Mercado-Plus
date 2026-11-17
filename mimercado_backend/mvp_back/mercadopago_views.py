from django.views.decorators.cache import never_cache
from django.utils.decorators import method_decorator
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from . import mercadopago_pruebas as mp
from .services import require_buyer
from .mercadopago_integrado import PagoIntegradoSerializer, pagar, cancelar_intento


class CheckoutSerializer(serializers.Serializer):
    pedido_id = serializers.IntegerField(min_value=1)


@method_decorator(never_cache, name='dispatch')
class PagoIntegradoMercadoPagoView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_checkout'

    def post(self, request):
        require_buyer(request.user)
        serializer = PagoIntegradoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(pagar(request.user, serializer.validated_data))


@method_decorator(never_cache, name='dispatch')
class ConfiguracionMercadoPagoView(APIView):
    def get(self, request):
        require_buyer(request.user)
        return Response(mp.configuracion())


@method_decorator(never_cache, name='dispatch')
class CancelarIntentoMercadoPagoView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_checkout'

    def post(self, request):
        require_buyer(request.user)
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(cancelar_intento(request.user, serializer.validated_data['pedido_id']))


@method_decorator(never_cache, name='dispatch')
class CheckoutMercadoPagoView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_checkout'

    def post(self, request):
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(mp.crear_checkout(request.user, serializer.validated_data['pedido_id']))


@method_decorator(never_cache, name='dispatch')
class EstadoMercadoPagoView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_estado'

    def get(self, request, order_id):
        return Response(mp.consultar_estado(request.user, order_id))


@method_decorator(never_cache, name='dispatch')
class ConfirmarMercadoPagoView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_estado'

    def post(self, request):
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(mp.confirmar_pago(request.user, serializer.validated_data['pedido_id']))


class WebhookMercadoPagoView(APIView):
    authentication_classes = []  # Mercado Pago se autentica con la firma HMAC.
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'mp_webhook'

    def post(self, request):
        return Response(mp.recibir_webhook(request))
