from django.apps import AppConfig
from django.conf import settings

class MvpBackConfig(AppConfig):
    default_auto_field='django.db.models.BigAutoField'
    name='mvp_back'
    def ready(self):
        # Solo la suite portátil: SQLite no entiende nombres schema.table.
        if getattr(settings,'MVP_SQLITE_TESTS',False):
            for model in self.get_models():
                model._meta.db_table=model._meta.db_table.split('.')[-1].strip('"')
