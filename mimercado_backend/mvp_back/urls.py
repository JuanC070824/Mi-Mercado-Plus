from django.urls import path
from . import views as v

urlpatterns=[
    path('auth/dni/',v.DniView.as_view()),
    path('auth/registro/',v.RegistroView.as_view()),
    path('auth/login/',v.LoginView.as_view()),
    path('auth/me/',v.PerfilView.as_view()),
    path('mercados/',v.MercadosView.as_view()),
    path('categorias/',v.CategoriasView.as_view()),
    path('puestos/',v.PuestosView.as_view()),
    path('vendedor/puesto/',v.VendedorPuestoView.as_view()),
    path('vendedor/inicio/',v.VendedorInicioView.as_view()),
    path('productos/',v.ProductosView.as_view()),
    path('direcciones/',v.DireccionesView.as_view()),
    path('carrito/',v.CarritoView.as_view()),
    path('carrito/items/',v.CarritoItemsView.as_view()),
    path('carrito/items/<int:item_id>/',v.CarritoItemView.as_view()),
    path('pedidos/',v.PedidosView.as_view()),
    path('pedidos/<int:order_id>/',v.PedidoView.as_view()),
    path('pedidos/<int:order_id>/cotizaciones/<int:quote_id>/aceptar/',v.AceptarCotizacionView.as_view()),
    path('pedidos/<int:order_id>/cancelar/',v.CancelarPedidoView.as_view()),
    path('pagos/yape/',v.PagoView.as_view()),
]
