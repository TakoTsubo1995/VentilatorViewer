# Sistema de Gestión de Datos Respiratorios SERVO-U

> **Proyecto**: Fisiología Respiratoria
> **Versión**: 2.1.0
> **Última actualización**: 2026-01-29

---

## Resumen del Sistema

Sistema completo para importar, organizar, visualizar y analizar datos de ventiladores SERVO-U. Incluye:

1. **Pipeline de importación** - Convierte archivos .txt crudos a .mat normalizados
2. **Base de datos estructurada** - Organiza datos por paciente/sesión/fecha
3. **Visor adaptativo** - Interfaz que se adapta al tipo de dato
4. **Módulos de análisis** - Mecánica respiratoria, loops P-V, trends

---

## Estructura del Proyecto

```
Respiradores/
├── VentilatorRecordingViewer.m    # Aplicación principal
├── inicializarVisor.m             # Script de inicialización
├── procesarDatosNuevos.m          # Procesar archivos nuevos
│
├── database/                      # Base de datos estructurada
│   ├── index.mat                  # Índice maestro (auto-generado)
│   ├── pacientes/                 # Datos asignados a pacientes
│   │   └── {Cama}_{Fecha}/
│   │       ├── paciente_info.mat
│   │       └── sesion_{N}/
│   │           ├── session_info.mat
│   │           ├── recordings/*.mat
│   │           ├── trends/*.mat
│   │           ├── breathtrends/*.mat
│   │           ├── recruitments/*.mat
│   │           ├── logs/*.mat
│   │           └── screenshots/*.png
│   │
│   └── sin_asignar/               # Datos pendientes de asignar
│       └── {Ventilador}_{Fecha}/
│           └── sesion_1/...
│
├── ventilatorData/                # Datos crudos originales
│   ├── recordings/                # Archivos [REC]
│   ├── trends/                    # Archivos [TRE] y BreathTrends
│   ├── recruitments/              # Archivos [RECRUITMENT]
│   ├── logs/                      # Archivos [LOG]
│   └── screenshots/               # Capturas de pantalla
│
├── src/
│   ├── importers/                 # Pipeline de importación
│   │   ├── importarArchivo.m      # Punto de entrada único
│   │   ├── detectarTipoArchivo.m  # Detecta tipo por marcador
│   │   └── parsers/
│   │       ├── parseRecording.m   # Parser [REC]
│   │       ├── parseTrends.m      # Parser [TRE]
│   │       ├── parseBreathTrends.m # Parser BreathTrends
│   │       ├── parseRecruitment.m # Parser [RECRUITMENT]
│   │       └── parseLogs.m        # Parser [LOG]
│   │
│   ├── processors/                # Limpieza y normalización
│   │   ├── limpiarValores.m       # Limpia #, ***, -, BOM
│   │   └── estandarizarColumnas.m # Nombres uniformes
│   │
│   ├── database/                  # Gestión de base de datos
│   │   ├── dbInit.m               # Inicializa estructura
│   │   ├── dbAddSession.m         # Asigna sesión a paciente
│   │   └── dbQuery.m              # Consultas por filtros
│   │
│   ├── loaders/                   # Carga de datos procesados
│   │   ├── cargarTrends.m         # (Legado - usar importarArchivo)
│   │   └── cargarRecruitment.m    # (Legado - usar importarArchivo)
│   │
│   └── analysis/                  # Módulos de análisis
│       ├── detectarCiclosRespiratorios.m
│       ├── calcularMecanicaRespiratoria.m
│       └── analizarLoop.m
│
├── docs/                          # Documentación
│   ├── README_TECNICO.md          # Este archivo
│   ├── ESQUEMA_BASE_DATOS.md      # Esquema detallado de la DB
│   ├── GUIA_USO_VISOR.md          # Guía de usuario
│   └── FICHA_TECNICA_PESTANAS.md  # Especificación de pestañas
│
├── respaldos/                     # Versiones anteriores
│
└── tests/                         # Tests unitarios
    └── test_mecanicaRespiratoria.m
```

---

## Flujo de Trabajo

### 1. Importar datos nuevos

```matlab
% Ejecutar desde la carpeta del proyecto
procesarDatosNuevos();

% O con opciones específicas
procesarDatosNuevos(struct('sobreescribir', true, 'verbose', true));
```

Esto:
1. Escanea `ventilatorData/` buscando archivos .txt
2. Detecta el tipo de cada archivo ([REC], [TRE], [RECRUITMENT], [LOG])
3. Parsea y normaliza los datos
4. Guarda .mat en `database/sin_asignar/`
5. Copia screenshots a la sesión correspondiente

### 2. Asignar a paciente

```matlab
% Asignar sesión a un paciente
infoPaciente = struct(...
    'cama', 'Cama_12', ...
    'fechaIngreso', datetime('2026-01-28'), ...
    'motivoIngreso', 'SDRA post-COVID', ...
    'sexo', 'M', ...
    'edad', 65, ...
    'altura_cm', 175, ...
    'peso_kg', 85 ...
);

dbAddSession('database/sin_asignar/42376_20260128/sesion_1', infoPaciente);
```

### 3. Consultar datos

```matlab
% Todas las sesiones
res = dbQuery();

% Solo recordings
res = dbQuery(struct('tipo', 'recording'));

% Paciente específico
res = dbQuery(struct('paciente', 'Cama_12'));

% Rango de fechas
res = dbQuery(struct(...
    'fechaDesde', datetime('2026-01-01'), ...
    'fechaHasta', datetime('2026-01-31') ...
));
```

### 4. Visualizar

```matlab
% Abrir el visor
VentilatorRecordingViewer
```

---

## Tipos de Archivos Soportados

### Recordings ([REC])
- **Fuente**: `ventilatorData/recordings/*.txt`
- **Frecuencia**: Alta (~100 Hz)
- **Variables**: tiempo_s, fase, presion_cmH2O, flujo_Lmin, volumen_mL
- **Uso**: Análisis detallado de curvas, loops P-V configurables

### Trends ([TRE])
- **Fuente**: `ventilatorData/trends/*_Trends.txt`
- **Frecuencia**: 1 registro por minuto
- **Variables**: ~40 parámetros (Cdyn, PEEP, Vt, FR, Ppico, etc.)
- **Uso**: Evolución temporal, correlaciones

### BreathTrends ([RECRUITMENT] con "BreathTrends" en nombre)
- **Fuente**: `ventilatorData/trends/*_BreathTrends.txt`
- **Frecuencia**: 1 registro por respiración
- **Variables**: Cdyn, Pei, PEEP, Vce, Vci, IE, FR, etc.
- **Uso**: Análisis respiración a respiración

### Recruitments ([RECRUITMENT])
- **Fuente**: `ventilatorData/recruitments/*.txt`
- **Contenido**: Pasos de PEEP incremental
- **Análisis automático**: PEEP óptimo, Cdyn máxima, curva PEEP-Cdyn

### Logs ([LOG])
- **Fuente**: `ventilatorData/logs/*.txt`
- **Contenido**: Eventos del ventilador
- **Categorías**: alarma, alarma_alta, parametro, funcion, sistema
- **Uso**: Timeline de eventos, correlación con datos

---

## Componentes Principales

### 1. Pipeline de Importación

| Componente | Función |
|------------|---------|
| `importarArchivo.m` | Punto de entrada único para cualquier archivo |
| `detectarTipoArchivo.m` | Detecta tipo por marcador [REC], [TRE], etc. |
| `parseRecording.m` | Parsea archivos de grabación (~100Hz) |
| `parseTrends.m` | Parsea archivos Trends (por minuto) |
| `parseBreathTrends.m` | Parsea BreathTrends (por respiración) |
| `parseRecruitment.m` | Parsea maniobras de reclutamiento |
| `parseLogs.m` | Parsea logs de eventos |

### 2. Procesadores

| Componente | Función |
|------------|---------|
| `limpiarValores.m` | Limpia marcadores (#), valores especiales (***), BOM UTF-8 |
| `estandarizarColumnas.m` | Convierte nombres de columnas a formato estándar |

### 3. Base de Datos

| Componente | Función |
|------------|---------|
| `dbInit.m` | Inicializa estructura de carpetas y paths |
| `dbAddSession.m` | Asigna sesión a paciente, mueve archivos |
| `dbQuery.m` | Consulta sesiones por filtros |

### 4. Módulos de Análisis

| Componente | Función |
|------------|---------|
| `detectarCiclosRespiratorios.m` | Detecta ciclos inspiración/espiración |
| `calcularMecanicaRespiratoria.m` | Calcula Cst, Cdyn, Raw, ΔP, WOB |
| `analizarLoop.m` | Análisis de loops (área, histéresis, pendientes) |

---

## Estructura de Datos Normalizados

Todos los archivos .mat procesados tienen esta estructura común:

```matlab
data.version = '2.0';
data.tipo = 'recording';  % recording|trends|breathtrends|recruitment|logs
data.archivoOrigen = 'ruta/original.txt';
data.fechaProcesado = datetime;
data.metadatos = struct(...
    'ventiladorID', '42376', ...
    'sistemaVersion', '4.4', ...
    'fecha', datetime, ...
    'paciente', struct('sexo','M','altura',175,'peso',85,'PBW',70)
);
data.erroresImportacion = {};  % Problemas encontrados
data.tabla = table(...);       % Datos limpios
```

### Variables por Tipo

| Tipo | Variables Principales |
|------|----------------------|
| **recording** | tiempo_s, fase, presion_cmH2O, flujo_Lmin, volumen_mL |
| **trends** | tiempo, Cdyn, PEEP, Vt, FR, FiO2, Ppico, Pmedia, VMe, modo |
| **breathtrends** | tiempo, Cdyn, Pei, PEEP, Vce, Vci, IE, FR |
| **recruitment** | tiempo, paso, Cdyn, Pei, PEEP, Vce, Vci |
| **logs** | tiempo, categoria, mensaje, severidad |

---

## Limpieza de Datos

El sistema maneja automáticamente:

| Problema | Solución |
|----------|----------|
| BOM UTF-8 (ï»¿) | Se elimina al inicio del archivo |
| Marcador # en valores | Se elimina, valor se marca como "con trigger" |
| Valores *** | Se convierten a NaN |
| Valores - (guión) | Se convierten a NaN |
| Celdas vacías | Se convierten a NaN |
| Nombres con acentos/símbolos | Se normalizan (Cdyn, PEEP, etc.) |

---

## Identificación de Pacientes

Cada paciente se identifica por:

```matlab
paciente = struct(...
    'cama', 'Cama_12', ...           % Identificador principal
    'fechaIngreso', datetime, ...    % Fecha de ingreso
    'motivoIngreso', 'SDRA', ...     % Motivo clínico
    'sexo', 'M', ...
    'edad', 65, ...
    'altura_cm', 175, ...
    'peso_kg', 85, ...
    'PBW_kg', 70, ...                % Peso corporal predicho
    'notas', '' ...
);
```

La carpeta del paciente se nombra: `Cama_{N}_{YYYYMMDD}/`

---

## Dependencias

- MATLAB R2020b o superior
- No requiere toolboxes adicionales

---

## Documentación Relacionada

- `docs/ESQUEMA_BASE_DATOS.md` - Esquema detallado de la base de datos
- `docs/GUIA_USO_VISOR.md` - Guía de usuario del visor
- `docs/FICHA_TECNICA_PESTANAS.md` - Especificación de pestañas

---

## Historial de Versiones

### v2.0 (2026-01-28)
- Pipeline de importación con parsers especializados
- Base de datos estructurada por paciente/sesión
- Limpieza automática de valores especiales
- Soporte para 5 tipos de archivo
- Loops configurables (X vs Y personalizables)

### v1.0
- Visor básico con sistema de pestañas
- Dropdowns para selección de variables
