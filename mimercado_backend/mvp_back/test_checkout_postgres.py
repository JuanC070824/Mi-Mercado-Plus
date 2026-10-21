from unittest.mock import patch

from django.db.backends.postgresql.base import DatabaseWrapper
from django.test import SimpleTestCase

from .services import _productos_para_checkout


class CheckoutPostgresSqlTests(SimpleTestCase):
    def test_lock_sql_supports_schema_qualified_tables(self):
        # Compilar con PostgreSQL sin abrir conexiones ni modificar datos.
        db = DatabaseWrapper({'NAME': 'compilacion_sql', 'OPTIONS': {}})
        query = _productos_para_checkout([2, 1])
        with patch.object(db, 'get_autocommit', return_value=False):
            sql, params = query.query.get_compiler(connection=db).as_sql()
        self.assertTrue(sql.endswith('FOR UPDATE'), sql)
        self.assertNotIn('FOR UPDATE OF', sql)
        self.assertNotIn(' JOIN ', sql)
        self.assertIn('ORDER BY', sql)
        self.assertEqual(tuple(params), (2, 1))
        self.assertEqual(query._prefetch_related_lookups, ('puesto__mercado',))
