from django import forms
from django.contrib import admin

from .models import Mercado


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


admin.site.site_header = "Administración de MiMercado+"
admin.site.site_title = "MiMercado+"
admin.site.index_title = "Panel administrativo"
