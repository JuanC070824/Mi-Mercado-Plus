from django.test.runner import DiscoverRunner
from django.apps import apps
from django.db import connection

class MvpTestRunner(DiscoverRunner):
    def setup_databases(self,**kwargs):
        result=super().setup_databases(**kwargs)
        # Solo en SQLite aislado; NUNCA crear/recrear tablas unmanaged en Aiven.
        if connection.vendor!='sqlite':raise RuntimeError('La suite portátil solo usa SQLite.')
        with connection.schema_editor() as editor:
            for model in apps.get_app_config('mvp_back').get_models():
                editor.create_model(model)
        with connection.cursor() as c:
            c.execute("CREATE UNIQUE INDEX test_open_cart ON carritos(comprador_id) WHERE estado='abierto'")
            c.execute("CREATE UNIQUE INDEX test_paid_order ON pagos(pedido_id) WHERE estado='aprobado'")
            c.execute("CREATE UNIQUE INDEX test_accepted_quote ON cotizaciones(pedido_id) WHERE estado='aceptada'")
        return result
