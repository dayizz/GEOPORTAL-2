class AppStrings {
  AppStrings._();

  static const String appName = 'GEOPORTAL DE GESTION';
  static const String appSubtitle = 'Gestión Catastral';

  // Auth
  static const String iniciarSesion = 'Iniciar Sesión';
  static const String registrarse = 'Registrarse';
  static const String correo = 'Correo electrónico';
  static const String contrasena = 'Contraseña';
  static const String cerrarSesion = 'Cerrar Sesión';
  static const String bienvenido = 'Bienvenido al Geoportal';

  // Navegación
  static const String mapa = 'Mapa';
  static const String predios = 'Predios';
  static const String propietarios = 'Propietarios';
  static const String reportes = 'Reportes';
  static const String cargaArchivos = 'Carga de Archivos';
  static const String configuracion = 'Configuración';

  // Predios
  static const String nuevoPredio = 'Nuevo Predio';
  static const String editarPredio = 'Editar Predio';
  static const String detallePredio = 'Detalle del Predio';
  static const String claveCatastral = 'Clave Catastral';
  static const String superficie = 'Superficie (m²)';
  static const String usoSuelo = 'Uso de Suelo';
  static const String zona = 'Zona';
  static const String valorCatastral = 'Valor Catastral';
  static const String coordenadas = 'Coordenadas';
  static const String latitud = 'Latitud';
  static const String longitud = 'Longitud';
  static const String descripcion = 'Descripción';
  static const String direccion = 'Dirección';
  static const String colonia = 'Colonia';
  static const String municipio = 'Municipio';
  static const String estado = 'Estado';
  static const String codigoPostal = 'Código Postal';

  // Propietarios
  static const String nuevoPropietario = 'Nuevo Propietario';
  static const String editarPropietario = 'Editar Propietario';
  static const String nombre = 'Nombre(s)';
  static const String apellidos = 'Apellidos';
  static const String curp = 'CURP';
  static const String rfc = 'RFC';
  static const String telefono = 'Teléfono';
  static const String correoContacto = 'Correo de contacto';
  static const String tipoPersona = 'Tipo de persona';
  static const String fisica = 'Física';
  static const String moral = 'Moral';
  static const String razonSocial = 'Razón Social';

  // Usos de suelo
  static const List<String> usosSuelo = [
    'Habitacional',
    'Comercial',
    'Industrial',
    'Agrícola',
    'Mixto',
    'Equipamiento',
    'Otro',
  ];

  // Acciones
  static const String guardar = 'Guardar';
  static const String cancelar = 'Cancelar';
  static const String eliminar = 'Eliminar';
  static const String editar = 'Editar';
  static const String buscar = 'Buscar';
  static const String filtrar = 'Filtrar';
  static const String exportar = 'Exportar';
  static const String cargar = 'Cargar Archivo';
  static const String confirmar = 'Confirmar';
  static const String aceptar = 'Aceptar';

  // Mensajes
  static const String errorGenerico = 'Ha ocurrido un error. Inténtalo de nuevo.';
  static const String exitoGuardar = 'Guardado correctamente';
  static const String exitoEliminar = 'Eliminado correctamente';
  static const String confirmacionEliminar = '¿Estás seguro de que deseas eliminar este registro?';
  static const String sinRegistros = 'No se encontraron registros';
  static const String cargando = 'Cargando...';
}
