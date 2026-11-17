from django import forms
from django.contrib import admin, messages

from . import operaciones as op
from .models import Mercado, Puesto, RepartidorMercado, Usuario


class MercadoAdminForm(forms.ModelForm):
    ESTADOS = (
        ("activo", "Activo"),
        ("suspendido", "Suspendido"),
        ("inactivo", "Inactivo"),
    )

    estado = forms.ChoiceField(choices=ESTADOS)

    class Meta:
        model = Mercado
        fields = "__all__"

    def clean(self):
        datos = super().clean()
        latitud = datos.get("latitud")
        longitud = datos.get("longitud")

        if (latitud is None) != (longitud is None):
            raise forms.ValidationError(
                "Ingresa tanto la latitud como la longitud, o deja ambas vacías."
            )

        if latitud is not None and not -90 <= latitud <= 90:
            self.add_error("latitud", "La latitud debe estar entre -90 y 90.")
        if longitud is not None and not -180 <= longitud <= 180:
            self.add_error("longitud", "La longitud debe estar entre -180 y 180.")

        return datos


@admin.register(Mercado)
class MercadoAdmin(admin.ModelAdmin):
    form = MercadoAdminForm
    list_display = (
        "nombre",
        "distrito",
        "provincia",
        "departamento",
        "estado",
        "creado_en",
    )
    list_filter = ("estado", "departamento", "provincia", "distrito")
    search_fields = ("nombre", "direccion", "distrito", "provincia", "departamento")
    ordering = ("nombre",)
    readonly_fields = ("creado_en",)
    list_per_page = 25
    save_on_top = True
    fieldsets = (
        (
            "Datos del mercado",
            {"fields": ("nombre", "direccion", "estado")},
        ),
        (
            "Ubicación",
            {
                "fields": (
                    "departamento",
                    "provincia",
                    "distrito",
                    "latitud",
                    "longitud",
                )
            },
        ),
        ("Registro", {"fields": ("creado_en",)}),
    )


class EstadoForm(forms.ModelForm):
    """La base solo acepta estos estados (CHECK); un texto libre daría error."""

    estado = forms.ChoiceField(choices=MercadoAdminForm.ESTADOS)


def _nombre(usuario):
    return " ".join(filter(None, [usuario.nombres, usuario.apellido_paterno]))


@admin.register(RepartidorMercado)
class RepartidorMercadoAdmin(admin.ModelAdmin):
    """Solicitudes de repartidores: se autorizan aquí, sin usar la consola (RF-18)."""

    list_display = (
        "repartidor_nombre",
        "celular",
        "mercado",
        "movilidad",
        "placa",
        "autorizado",
        "disponible",
        "inicio_en",
    )
    list_filter = ("autorizado", "disponible", "mercado", "movilidad")
    search_fields = ("repartidor__nombres", "repartidor__apellido_paterno", "repartidor__celular", "placa")
    list_select_related = ("repartidor", "mercado")
    ordering = ("autorizado", "-inicio_en")
    actions = ("autorizar", "quitar_autorizacion")
    # Los datos los envía el repartidor desde la app; aquí solo se decide la autorización.
    readonly_fields = (
        "repartidor",
        "rol_repartidor",
        "mercado",
        "movilidad",
        "placa",
        "descripcion_movilidad",
        "autorizado",
        "disponible",
        "inicio_en",
        "fin_en",
    )

    def get_queryset(self, request):
        return super().get_queryset(request).filter(fin_en__isnull=True)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    @admin.display(description="Repartidor", ordering="repartidor__nombres")
    def repartidor_nombre(self, obj):
        return _nombre(obj.repartidor)

    @admin.display(description="Celular")
    def celular(self, obj):
        return obj.repartidor.celular

    def _aplicar(self, request, queryset, accion, hecho):
        listos, fallidos = 0, []
        for rm in queryset.select_related("repartidor"):
            motivo = accion(rm)
            if motivo:
                fallidos.append(f"{_nombre(rm.repartidor)}: {motivo}")
            else:
                listos += 1
        if listos:
            self.message_user(request, f"{listos} repartidor(es) {hecho}.", messages.SUCCESS)
        for f in fallidos:
            self.message_user(request, f"No se pudo con {f}.", messages.WARNING)

    @admin.action(description="Autorizar a los seleccionados")
    def autorizar(self, request, queryset):
        self._aplicar(request, queryset, op.autorizar_solicitud, "autorizado(s)")

    @admin.action(description="Quitar autorización a los seleccionados")
    def quitar_autorizacion(self, request, queryset):
        self._aplicar(request, queryset, op.quitar_autorizacion, "sin autorización")


@admin.register(Puesto)
class PuestoAdmin(admin.ModelAdmin):
    form = EstadoForm
    list_display = ("nombre", "mercado", "vendedor_nombre", "categoria", "abierto", "estado")
    list_filter = ("estado", "abierto", "mercado", "categoria")
    search_fields = ("nombre", "vendedor__nombres", "vendedor__celular")
    list_select_related = ("mercado", "vendedor", "categoria")
    readonly_fields = ("vendedor", "rol_vendedor", "creado_en")

    @admin.display(description="Casero")
    def vendedor_nombre(self, obj):
        return _nombre(obj.vendedor)


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    """Consulta de cuentas. La contraseña nunca se muestra ni se edita aquí."""

    form = EstadoForm
    list_display = ("nombres", "apellido_paterno", "celular", "estado", "creado_en")
    list_filter = ("estado",)
    search_fields = ("nombres", "apellido_paterno", "celular", "correo")
    fields = ("nombres", "apellido_paterno", "apellido_materno", "celular", "correo", "estado", "creado_en")
    readonly_fields = ("nombres", "apellido_paterno", "apellido_materno", "celular", "correo", "creado_en")

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


admin.site.site_header ="Administración de MiMercado+"
admin.site.site_title = "MiMercado+"
admin.site.index_title = "Panel administrativo"
