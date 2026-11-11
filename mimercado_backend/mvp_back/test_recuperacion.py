from unittest import mock
from django.contrib.auth.hashers import check_password, make_password
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from .authentication import issue_token
from .dni import DniNoEncontrado, DniServicioNoDisponible
from .models import Rol, Usuario, UsuarioRol
from . import recuperacion

ROSA={'dni':'12345678','nombres':'Rosa','apellido_paterno':'Quispe','apellido_materno':'Mamani'}

class RecuperarContrasenaTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        Rol.objects.create(codigo='comprador',nombre='comprador')
        cls.user=Usuario.objects.create(nombres='Rosa',apellido_paterno='Quispe',celular='911111111',
                                        password_hash=make_password('Anterior!42'))
        UsuarioRol.objects.create(usuario_id=cls.user.pk,rol_codigo='comprador')
    def setUp(self):
        self.client=APIClient()
    def recuperar(self,celular='911111111',dni='12345678',identidad=ROSA,efecto=None):
        with mock.patch('mvp_back.views.consultar_dni',return_value=identidad,side_effect=efecto):
            return self.client.post('/api/auth/recuperar/',{'celular':celular,'dni':dni},format='json')
    def restablecer(self,codigo,password='NuevaClave!42',celular='911111111'):
        return self.client.post('/api/auth/restablecer/',{'celular':celular,'codigo':codigo,'password':password},format='json')

    def test_flujo_completo_cierra_sesiones_y_el_codigo_es_de_un_solo_uso(self):
        token_viejo=issue_token(self.user)
        r=self.recuperar()
        self.assertEqual(r.status_code,200,r.data)
        codigo=r.data['codigo_demostracion']
        self.assertRegex(codigo,r'^\d{6}$')
        self.assertEqual(self.restablecer(codigo).status_code,200)
        self.user.refresh_from_db()
        self.assertTrue(check_password('NuevaClave!42',self.user.password_hash))
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+token_viejo)
        self.assertEqual(self.client.get('/api/auth/me/').status_code,401)
        self.client.credentials()
        login=self.client.post('/api/auth/login/',{'celular':'911111111','password':'NuevaClave!42'},format='json')
        self.assertEqual(login.status_code,200)
        self.assertEqual(self.restablecer(codigo,'OtraClave!42').status_code,400)

    def test_dni_de_otra_persona_o_celular_inexistente_dan_el_mismo_mensaje(self):
        otro=self.recuperar(identidad={**ROSA,'nombres':'Carmen','apellido_paterno':'Flores'})
        inexistente=self.recuperar(celular='922222222')
        self.assertEqual((otro.status_code,inexistente.status_code),(400,400))
        self.assertEqual(otro.data['detail'],inexistente.data['detail'])
        self.assertNotIn('codigo_demostracion',otro.data)

    def test_nombres_se_comparan_sin_importar_mayusculas_ni_espacios(self):
        r=self.recuperar(identidad={**ROSA,'nombres':'  ROSA ','apellido_paterno':'quispe'})
        self.assertEqual(r.status_code,200)

    def test_dni_no_encontrado_y_servicio_caido(self):
        self.assertEqual(self.recuperar(efecto=DniNoEncontrado('x')).status_code,400)
        caido=self.recuperar(efecto=DniServicioNoDisponible('La consulta de DNI no está configurada.'))
        self.assertEqual(caido.status_code,503)
        self.assertIn('DNI',caido.data['detail'])

    def test_codigo_incorrecto_o_clave_debil_no_cambian_nada(self):
        codigo=self.recuperar().data['codigo_demostracion']
        incorrecto=str((int(codigo)+1)%1_000_000).zfill(6)
        self.assertEqual(self.restablecer(incorrecto).status_code,400)
        self.assertEqual(self.restablecer(codigo,'123').status_code,400)
        self.user.refresh_from_db()
        self.assertTrue(check_password('Anterior!42',self.user.password_hash))

    def test_el_codigo_vence(self):
        codigo=self.recuperar().data['codigo_demostracion']
        actual=recuperacion._ventana_actual()
        with mock.patch.object(recuperacion,'_ventana_actual',return_value=actual+1):
            self.assertTrue(recuperacion.codigo_valido(self.user,codigo))
        with mock.patch.object(recuperacion,'_ventana_actual',return_value=actual+2):
            self.assertEqual(self.restablecer(codigo).status_code,400)

    @override_settings(RECUPERACION_MODO='sms')
    def test_fuera_de_demo_no_muestra_el_codigo(self):
        r=self.recuperar()
        self.assertEqual(r.status_code,200)
        self.assertNotIn('codigo_demostracion',r.data)
