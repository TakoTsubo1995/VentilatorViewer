# Esquema de Base de Datos - Sistema de Gestión Respiratoria SERVO-U

> **Versión**: 2.0
> **Fecha**: 2026-01-28
> **Autor**: Proyecto Fisiología Respiratoria

---

## Resumen

El sistema utiliza una base de datos basada en archivos `.mat` organizados jerárquicamente por paciente, fecha y sesión. Esto permite:

- Organización clara de datos por paciente
- Búsqueda rápida por fecha o tipo de dato
- Portabilidad (solo archivos, sin servidor)
- Compatibilidad total con MATLAB

---

## Estructura de Carpetas

```
database/
├── index.mat                          ← Índice maestro
├── pacientes/
│   └── {Cama}_{YYYYMMDD}/
│       ├── paciente_info.mat          ← Datos del paciente
│       └── sesion_{N}/
│           ├── session_info.mat       ← Info de la sesión
│           ├── recordings/            ← Grabaciones (~100 Hz)
│           │   └── *.mat
│           ├── trends/                ← Tendencias (por minuto)
│           │   └── *.mat
│           ├── breathtrends/          ← Tendencias por respiración
│           │   └── *.mat
│           ├── recruitments/          ← Maniobras de reclutamiento
│           │   └── *.mat
│           ├── logs/                  ← Eventos y alarmas
│           │   └── *.mat
│           └── screenshots/           ← Capturas de pantalla
│               └── *.png
│
└── sin_asignar/                       ← Datos pendientes de asignar
    └── {VentiladorID}_{YYYYMMDD}/
        └── (misma estructura)
```

---

## Índice Maestro (`index.mat`)

```matlab
index.version = '2.0';
index.fechaCreacion = datetime;
index.ultimaActualizacion = datetime;
index.archivosOrigen = {
    'ventilatorData/recordings/1769620787164.txt',
    ...
};
index.registros = {
    struct('archivoOrigen', '...', 'archivoProcesado', '...', 'tipo', 'recording', ...),
    ...
};
index.pacientes = {
    struct('nombre', 'Cama_12_20260128', 'cama', 'Cama_12', ...),
    ...
};
```

---

## Información del Paciente (`paciente_info.mat`)

```matlab
pacienteInfo.cama = 'Cama_12';
pacienteInfo.fechaIngreso = datetime;
pacienteInfo.fechaAsignacion = datetime;
pacienteInfo.motivoIngreso = 'SDRA post-COVID';
pacienteInfo.sexo = 'M';           % 'M' o 'F'
pacienteInfo.edad = 65;            % años
pacienteInfo.altura_cm = 175;
pacienteInfo.peso_kg = 85;
pacienteInfo.PBW_kg = 70;          % Peso corporal predicho
pacienteInfo.notas = '';
```

**Cálculo de PBW (Peso Corporal Predicho):**
- Hombres: `PBW = 50 + 0.91 × (altura_cm - 152.4)`
- Mujeres: `PBW = 45.5 + 0.91 × (altura_cm - 152.4)`

---

## Estructura de Datos por Tipo

### Recording (Grabación de curvas)

```matlab
data.version = '2.0';
data.tipo = 'recording';
data.archivoOrigen = 'ruta/original.txt';
data.fechaProcesado = datetime;
data.metadatos = struct(
    'ventiladorID', '42376',
    'modoVentilacion', 'Volumen controlado',
    'Vt_config', 400,
    'PEEP_config', 5,
    'FR_config', 15,
    'FiO2_config', 40,
    'IE_config', '1:2'
);
data.tabla = table(
    tiempo_s,           % Tiempo en segundos (desde 0)
    tiempo_str,         % Tiempo original (string)
    fase,               % 'insp.', 'esp.', 'pausa insp.'
    presion_cmH2O,      % Presión vía aérea
    flujo_Lmin,         % Flujo (L/min)
    volumen_mL          % Volumen (mL)
);
data.estadisticas = struct(
    'nMuestras', 15000,
    'duracion_s', 150,
    'frecuenciaMuestreo_Hz', 100
);
```

### Trends (Tendencias por minuto)

```matlab
data.tipo = 'trends';
data.tabla = table(
    tiempo,             % String o datetime
    FR,                 % Frecuencia respiratoria
    Vci_mL,            % Volumen corriente inspirado
    Vce_mL,            % Volumen corriente espirado
    Ppico_cmH2O,       % Presión pico
    PEEP_cmH2O,        % PEEP medido
    Cdyn_mLcmH2O,      % Compliance dinámica
    FiO2_pct,          % FiO2
    modo_vent,         % Modo de ventilación
    ...                 % ~40 variables más
);
```

### BreathTrends (Por respiración)

Similar a Recruitment pero con intervalo más largo (60 min típicamente).

### Recruitment (Maniobra de reclutamiento)

```matlab
data.tipo = 'recruitment';
data.tabla = table(
    tiempo,
    Cdyn_mLcmH2O,
    Pei_cmH2O,
    PEEP_cmH2O,
    Vce_mL,
    Vci_mL,
    IE,
    FR
);
data.analisis = struct(
    'PEEP_optimo', 12,
    'Cdyn_max', 52,
    'nPasos', 5,
    'curvaResumen', struct(...)
);
```

### Logs (Eventos)

```matlab
data.tipo = 'logs';
data.tabla = table(
    tiempo,             % String HH:MM:SS
    fecha,              % String DD/MM/YY
    categoria,          % 'Alarma', 'Cambio del parámetro', 'Funciones'
    mensaje,            % Descripción del evento
    severidad           % 'critica', 'advertencia', 'info'
);
data.resumen = struct(
    'porCategoria', struct(...),
    'porSeveridad', struct('critica', 5, 'advertencia', 12, 'info', 45),
    'alarmasFrecuentes', [...]
);
```

---

## Funciones de Base de Datos

| Función | Descripción |
|---------|-------------|
| `dbInit()` | Inicializa estructura de carpetas |
| `dbAddSession(carpeta, infoPaciente)` | Asigna sesión a paciente |
| `dbQuery(filtros)` | Consulta sesiones por criterios |
| `procesarDatosNuevos()` | Importa archivos nuevos |

### Ejemplos de uso

```matlab
% Inicializar proyecto
inicializarVisor

% Importar datos nuevos
resumen = procesarDatosNuevos();

% Asignar a paciente
paciente = struct('cama', 'Cama_12', 'motivoIngreso', 'SDRA', 'sexo', 'M', 'altura_cm', 175);
dbAddSession('database/sin_asignar/42376_20260128', paciente);

% Consultar datos
res = dbQuery();                                    % Todas las sesiones
res = dbQuery(struct('tipo', 'recording'));         % Solo recordings
res = dbQuery(struct('paciente', 'Cama_12'));       % Por paciente
res = dbQuery(struct('fechaDesde', datetime(2026,1,1))); % Por fecha
```

---

## Migración de Datos Existentes

Si tienes datos en la estructura anterior:

1. Ejecuta `inicializarVisor` para crear la nueva estructura
2. Ejecuta `procesarDatosNuevos()` para importar los archivos de `ventilatorData/`
3. Usa `dbAddSession()` para organizar por paciente

Los archivos originales en `ventilatorData/` NO se modifican.

---

## Notas Técnicas

### Manejo de caracteres especiales en datos

El parser limpia automáticamente:
- `#` prefijo: indica valor marcado por el ventilador
- `***`: sin dato disponible → NaN
- `-`: sin dato → NaN
- BOM UTF-8: eliminado automáticamente
- Etiquetas HTML (`<sub>`, etc.): eliminadas de logs

### Detección de tipo de archivo

Basado en el marcador de primera línea:
- `[REC]` → recording
- `[TRE]` → trends
- `[RECRUITMENT]` → recruitment o breathtrends (según nombre)
- `[LOG]` → logs
