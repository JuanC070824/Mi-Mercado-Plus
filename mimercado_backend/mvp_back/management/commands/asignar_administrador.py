from django.core.management.base import BaseCommand, CommandError
from mvp_back.models import Rol, Usuario, UsuarioRol

class Command(BaseCommand):
    help='Da (o quita) el rol de administrador de la app a una cuenta existente. Solo con acceso al servidor.'
    def add_arguments(self,parser):
        parser.add_argument('--celular',required=True)
        parser.add_argument('--quitar',action='store_true')
    def handle(self,*args,**opts):
        user=Usuario.objects.filter(celular=opts['celular'],estado='activo').first()
        if user is None:raise CommandError('No existe una cuenta activa con ese celular.')
        if not Rol.objects.filter(pk='administrador').exists():raise CommandError('Falta el rol administrador: ejecuta el script SQL.')
        if opts['quitar']:
            UsuarioRol.objects.filter(usuario_id=user.pk,rol_codigo='administrador').delete()
            self.stdout.write(self.style.SUCCESS(f'{user.nombres} ya no es administrador.'))
            return
        UsuarioRol.objects.get_or_create(usuario_id=user.pk,rol_codigo='administrador')
        self.stdout.write(self.style.SUCCESS(f'{user.nombres} ahora es administrador. Entra desde "Soy administrador".'))
