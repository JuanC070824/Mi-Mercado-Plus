from io import StringIO
from django.core.management import call_command
from django.test import TestCase
from .models import Categoria,Entrega,Mercado,Pedido,Producto,Puesto,Rol,UnidadMedida,Usuario
from . import operaciones as op

class ComandosDatosTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        # Lo mismo que inserta el script SQL de la base.
        for code in ['comprador','vendedor','repartidor','administrador']:Rol.objects.create(codigo=code,nombre=code)
        for code,frac in [('kg',True),('unidad',False),('atado',False),('litro',True)]:
            UnidadMedida.objects.create(codigo=code,nombre=code,permite_fraccion=frac)
        for nombre in ['Verduras y frutas','Carnes y aves','Abarrotes','Pescados y mariscos']:Categoria.objects.create(nombre=nombre)
    def cargar(self,comando):
        call_command(comando,stdout=StringIO())
    def test_catalogo_completo_y_sin_duplicados(self):
        self.cargar('cargar_catalogo')
        conteo=(Mercado.objects.count(),Puesto.objects.count(),Producto.objects.count())
        self.assertEqual(conteo,(9,34,68))
        self.assertFalse(Mercado.objects.filter(latitud__isnull=True).exists())
        self.cargar('cargar_catalogo')
        self.assertEqual((Mercado.objects.count(),Puesto.objects.count(),Producto.objects.count()),conteo)
    def test_demo_deja_pedidos_listos_para_repartir(self):
        self.cargar('cargar_catalogo');self.cargar('cargar_demo')
        self.assertEqual(Pedido.objects.count(),2)
        ernesto=Usuario.objects.get(celular='900000090')
        self.assertEqual(len(op.aptos_para_reparto(Pedido.objects.all())),2)
        self.assertTrue(op.asignacion(ernesto).disponible)
        self.cargar('cargar_demo')
        self.assertEqual(Pedido.objects.count(),2)
        self.assertFalse(Entrega.objects.exists())
