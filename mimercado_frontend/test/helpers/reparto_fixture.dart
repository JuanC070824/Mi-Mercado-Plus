Map<String, dynamic> pedidoRepartoJson({
  String estado = 'en_recojo',
  String metodo = 'yape',
  List<String> estados = const ['listo', 'en_preparacion'],
}) => {
  'id': 25,
  'codigo': 'MM-interno-no-visible',
  'codigo_corto': '25',
  'cliente_nombre': 'María del Pilar',
  'cliente_celular': '900000001',
  'mercado_id': 1,
  'estado': estado,
  'metodo_pago': metodo,
  'direccion': 'Av. Santa Rosa 123',
  'referencia': 'Portón verde',
  'creado_en': '2026-10-20T12:00:00Z',
  'historial': [],
  'codigo_entrega': '',
  'costo_envio_centavos': 500,
  'distancia_km': 1.2,
  'ganancia_repartidor_centavos': 500,
  'pago_aprobado': metodo == 'yape',
  'pago_simulado': true,
  'puestos': [
    for (var i = 0; i < estados.length; i++)
      {
        'id': 50 + i,
        'codigo_bolsa': 'bolsa-interna-$i',
        'estado': estados[i],
        'parada': i + 1,
        'puesto': {
          'id': i + 1,
          'mercado_id': 1,
          'nombre': i == 0 ? 'Verduras Rosa' : 'Carnicería Huancayo',
          'casero': i == 0 ? 'Rosa' : 'Julio',
          'abierto': true,
        },
        'detalles': [
          {
            'id': 100 + i,
            'nombre': 'Producto',
            'unidad': 'kg',
            'cantidad': '1',
            'precio_estimado_centavos': 400,
          },
        ],
      },
  ],
  'cotizacion': {
    'id': 99,
    'version': 1,
    'estado': 'aceptada',
    'costo_envio_centavos': 500,
    'puestos': [
      for (var i = 0; i < estados.length; i++)
        {
          'pedido_puesto_id': 50 + i,
          'tasa_comision': '0.05',
          'detalles': [
            {
              'pedido_detalle_id': 100 + i,
              'nombre_final': 'Producto',
              'cantidad_real': '1',
              'precio_unitario_centavos': 400,
            },
          ],
        },
    ],
  },
};

Map<String, dynamic> inicioRepartoJson({
  Map<String, dynamic>? actual,
  List<Map<String, dynamic>> ofertas = const [],
}) => {
  'autorizado': true,
  'disponible': true,
  'mercado': {'id': 1, 'nombre': 'Mercado Santa Rosa'},
  'movilidad': 'bicicleta',
  'placa': null,
  'entregas_hoy': 0,
  'ganancia_hoy_centavos': 0,
  'sonido': false,
  'vibracion': false,
  'en_curso': actual,
  'ofertas': ofertas,
  'historial_hoy': [],
};
