# Geoportal Backend (FastAPI)

Este backend provee una API RESTful para la gestión de predios y recursos del Geoportal. Está diseñado para integrarse fácilmente con el frontend Flutter.

## Instalación y ejecución

1. Crea un entorno virtual:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
2. Instala dependencias:
   ```bash
   pip install fastapi uvicorn
   ```
3. Ejecuta el servidor:
   ```bash
   uvicorn app.main:app --reload
   ```
   El backend estará disponible en http://localhost:8000

## Endpoints principales

- `GET /` — Prueba de vida
- `GET /predios` — Lista todos los predios
- `GET /predios/{predio_id}` — Detalle de un predio
- `POST /predios` — Crear un predio
- `PUT /predios/{predio_id}` — Actualizar un predio
- `DELETE /predios/{predio_id}` — Eliminar un predio

## Integración Flutter

En tu app Flutter, usa la URL base `http://localhost:8000` para consumir la API. Ejemplo con `http`:

```dart
final response = await http.get(Uri.parse('http://localhost:8000/predios'));
```

Para producción, reemplaza la URL por la del servidor real.

---

Puedes extender los endpoints y modelos según las necesidades del proyecto.
