-- ============================================================
-- GEOPORTAL PREDIOS - Script SQL para Supabase
-- Ejecuta este script en: Supabase Dashboard > SQL Editor
-- ============================================================

-- 1. Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Tabla propietarios
CREATE TABLE IF NOT EXISTS propietarios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  apellidos TEXT NOT NULL DEFAULT '',
  tipo_persona TEXT NOT NULL DEFAULT 'fisica' CHECK (tipo_persona IN ('fisica', 'moral')),
  razon_social TEXT,
  curp TEXT,
  rfc TEXT,
  telefono TEXT,
  correo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- 3. Tabla predios
CREATE TABLE IF NOT EXISTS predios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  clave_catastral TEXT NOT NULL UNIQUE,
  superficie NUMERIC(12, 2),
  uso_suelo TEXT NOT NULL DEFAULT 'Otro',
  zona TEXT,
  valor_catastral NUMERIC(16, 2),
  descripcion TEXT,
  direccion TEXT,
  colonia TEXT,
  municipio TEXT,
  estado TEXT,
  codigo_postal TEXT,
  latitud NUMERIC(10, 7),
  longitud NUMERIC(10, 7),
  geometry JSONB,          -- GeoJSON geometry del polígono/punto
  propietario_id UUID REFERENCES propietarios(id) ON DELETE SET NULL,
  imagen_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- 4. Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_predios_clave ON predios(clave_catastral);
CREATE INDEX IF NOT EXISTS idx_predios_uso_suelo ON predios(uso_suelo);
CREATE INDEX IF NOT EXISTS idx_predios_propietario ON predios(propietario_id);
CREATE INDEX IF NOT EXISTS idx_predios_municipio ON predios(municipio);

-- 5. Row Level Security (RLS)
ALTER TABLE propietarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE predios ENABLE ROW LEVEL SECURITY;

-- Políticas: solo usuarios autenticados pueden leer/escribir
CREATE POLICY "Usuarios autenticados pueden ver propietarios"
  ON propietarios FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden crear propietarios"
  ON propietarios FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar propietarios"
  ON propietarios FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden eliminar propietarios"
  ON propietarios FOR DELETE
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden ver predios"
  ON predios FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden crear predios"
  ON predios FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar predios"
  ON predios FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden eliminar predios"
  ON predios FOR DELETE
  TO authenticated
  USING (true);

-- 6. Storage bucket para archivos
INSERT INTO storage.buckets (id, name, public)
VALUES ('predios-archivos', 'predios-archivos', false)
ON CONFLICT DO NOTHING;

CREATE POLICY "Usuarios autenticados pueden subir archivos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'predios-archivos');

CREATE POLICY "Usuarios autenticados pueden ver archivos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'predios-archivos');

-- 7. Datos de ejemplo (opcional)
INSERT INTO propietarios (nombre, apellidos, tipo_persona, rfc, telefono, correo)
VALUES 
  ('Juan', 'García López', 'fisica', 'GALJ800101ABC', '5512345678', 'juan.garcia@email.com'),
  ('María', 'Rodríguez Sánchez', 'fisica', 'ROSM900215XYZ', '5587654321', 'maria.rodriguez@email.com'),
  ('Inmobiliaria del Norte', 'S.A. de C.V.', 'moral', 'INO001010DEF', '5511223344', 'contacto@inmobiliarianorte.com')
ON CONFLICT DO NOTHING;

-- Datos de ejemplo de predios (necesita propietarios insertados arriba)
INSERT INTO predios (clave_catastral, superficie, uso_suelo, zona, valor_catastral, direccion, colonia, municipio, estado, latitud, longitud, propietario_id)
SELECT 
  'CAT-001-2024', 250.50, 'Habitacional', 'Norte', 850000.00,
  'Calle Roble 123', 'Col. Las Flores', 'Monterrey', 'Nuevo León',
  25.6866, -100.3161,
  id FROM propietarios WHERE rfc = 'GALJ800101ABC' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO predios (clave_catastral, superficie, uso_suelo, zona, valor_catastral, direccion, colonia, municipio, estado, latitud, longitud, propietario_id)
SELECT 
  'CAT-002-2024', 500.00, 'Comercial', 'Centro', 2500000.00,
  'Av. Principal 456', 'Centro', 'Monterrey', 'Nuevo León',
  25.6753, -100.3183,
  id FROM propietarios WHERE rfc = 'ROSM900215XYZ' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO predios (clave_catastral, superficie, uso_suelo, zona, valor_catastral, direccion, colonia, municipio, estado, latitud, longitud, propietario_id)
SELECT 
  'CAT-003-2024', 1200.00, 'Industrial', 'Sur', 5000000.00,
  'Blvd. Industrial 789', 'Parque Industrial', 'San Nicolás', 'Nuevo León',
  25.7200, -100.2900,
  id FROM propietarios WHERE rfc = 'INO001010DEF' LIMIT 1
ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. Tabla de archivos GeoJSON importados (persistencia)
-- Ejecuta este bloque en Supabase Dashboard > SQL Editor
-- ============================================================
CREATE TABLE IF NOT EXISTS archivos_geojson (
  id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre         TEXT        NOT NULL,
  features_count INTEGER     NOT NULL DEFAULT 0,
  features       JSONB       NOT NULL DEFAULT '[]',
  sincronizado   BOOLEAN     NOT NULL DEFAULT false,
  encontrados    INTEGER     NOT NULL DEFAULT 0,
  creados        INTEGER     NOT NULL DEFAULT 0,
  errores        INTEGER     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ
);

ALTER TABLE archivos_geojson ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ver archivos_geojson"
  ON archivos_geojson FOR SELECT TO authenticated USING (true);
CREATE POLICY "Crear archivos_geojson"
  ON archivos_geojson FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Actualizar archivos_geojson"
  ON archivos_geojson FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Eliminar archivos_geojson"
  ON archivos_geojson FOR DELETE TO authenticated USING (true);

-- ============================================================
-- 9. MIGRACIÓN: Columnas de Gestión para la tabla predios
-- Ejecuta este bloque en Supabase Dashboard > SQL Editor
-- si la tabla predios fue creada con el esquema original (sección 3).
-- ============================================================
ALTER TABLE predios
  ADD COLUMN IF NOT EXISTS tramo              TEXT        NOT NULL DEFAULT 'T1',
  ADD COLUMN IF NOT EXISTS tipo_propiedad     TEXT        NOT NULL DEFAULT 'PRIVADA',
  ADD COLUMN IF NOT EXISTS ejido              TEXT,
  ADD COLUMN IF NOT EXISTS km_inicio          NUMERIC(10,3),
  ADD COLUMN IF NOT EXISTS km_fin             NUMERIC(10,3),
  ADD COLUMN IF NOT EXISTS km_lineales        NUMERIC(10,4),
  ADD COLUMN IF NOT EXISTS km_efectivos       NUMERIC(10,4),
  ADD COLUMN IF NOT EXISTS propietario_nombre TEXT,
  ADD COLUMN IF NOT EXISTS proyecto           TEXT,
  ADD COLUMN IF NOT EXISTS cop                BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cop_firmado        TEXT,
  ADD COLUMN IF NOT EXISTS poligono_dwg       TEXT,
  ADD COLUMN IF NOT EXISTS oficio             TEXT,
  ADD COLUMN IF NOT EXISTS poligono_insertado BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS identificacion     BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS levantamiento      BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS negociacion        BOOLEAN     NOT NULL DEFAULT false;

-- Índices adicionales para búsqueda rápida por gestión
CREATE INDEX IF NOT EXISTS idx_predios_tramo          ON predios(tramo);
CREATE INDEX IF NOT EXISTS idx_predios_tipo_propiedad ON predios(tipo_propiedad);
CREATE INDEX IF NOT EXISTS idx_predios_cop            ON predios(cop);
CREATE INDEX IF NOT EXISTS idx_predios_proyecto       ON predios(proyecto);

-- ============================================================
-- 10. RPC: Endpoint lógico /api/predios/vincular
-- Permite vincular manualmente un polígono con un registro de Gestión.
-- Payload equivalente:
-- {"id_poligono":"...", "id_gestion":"...", "geometry":{...}}
-- ============================================================

-- Columna opcional para guardar el identificador del polígono origen
ALTER TABLE predios
  ADD COLUMN IF NOT EXISTS id_poligono TEXT;

CREATE OR REPLACE FUNCTION public.api_predios_vincular(
  p_id_poligono TEXT,
  p_id_gestion UUID,
  p_geometry JSONB
)
RETURNS SETOF predios
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE predios
  SET
    id_poligono = p_id_poligono,
    geometry = p_geometry,
    poligono_insertado = true,
    updated_at = NOW()
  WHERE id = p_id_gestion;

  RETURN QUERY
    SELECT *
    FROM predios
    WHERE id = p_id_gestion;
END;
$$;

GRANT EXECUTE ON FUNCTION public.api_predios_vincular(TEXT, UUID, JSONB)
TO authenticated;

