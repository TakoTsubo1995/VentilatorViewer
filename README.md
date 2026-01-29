# Who i am ?

Good afternoon, my name is Cristóbal, aka "Takotsubo." 
I am a Spanish nurse who has worked for nine years in critical care units. I am currently studying a master’s in extracorporeal circulation in cardiac surgery, and because of that I am re‑studying physiological, anatomical, and physical fundamentals. By nature I like to investigate and tinker on my own, and while studying respiratory physiology—and because I didn’t understand certain concepts—I ended up “creating” this visualizer that uses MATLAB as the basis for processing the data. First of all I want to say a few things:

- I have very basic programming knowledge; I did all the programming using Claude Code and Antigravity. I wish I had time to learn to program properly, but honestly I neither have the time nor do I think I would do it better; I get by by seeing how things work and poking in areas where the AI gets lost.
- I don’t know how to use GitHub; it seems super counterintuitive to me, but I will try to update it following the way I see it being used.
Now about the project itself:

It is a basic viewer that uses data from the Maquet Servo‑U from my unit. Currently there is a set of test data in the ventiladordata folder, but frankly it is quite poor because it was made with an artificial lung. In any case, the use and handling of the viewer are described in the README. I know there is a lot of room for improvement in the graphical interface and in features like the database, but little by little. I am publishing it in case someone finds it of interest.
Thank you very much.

# SERVO-U Respiratory Data Management System

> **Project**: Respiratory Physiology
> **Version**: 2.1.0
> **Last Updated**: 2026-01-29

---

## System Summary

Complete system for importing, organizing, visualizing, and analyzing SERVO-U ventilator data. Includes:

1.  **Import Pipeline** - Converts raw .txt files to normalized .mat files
2.  **Structured Database** - Organizes data by patient/session/date
3.  **Adaptive Viewer** - Interface that adapts to the data type
4.  **Analysis Modules** - Respiratory mechanics, P-V loops, trends

---

## Project Structure

```
Respiradores/
├── VentilatorRecordingViewer.m    # Main application
├── inicializarVisor.m             # Initialization script
├── procesarDatosNuevos.m          # Process new files script
│
├── database/                      # Structured database
│   ├── index.mat                  # Master index (auto-generated)
│   ├── pacientes/                 # Assigned patient data
│   │   └── {Bed}_{Date}/
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
│   └── sin_asignar/               # Unassigned pending data
│       └── {Ventilator}_{Date}/
│           └── sesion_1/...
│
├── ventilatorData/                # Original raw data
│   ├── recordings/                # [REC] files
│   ├── trends/                    # [TRE] and BreathTrends files
│   ├── recruitments/              # [RECRUITMENT] files
│   ├── logs/                      # [LOG] files
│   └── screenshots/               # Screenshots
│
├── src/
│   ├── importers/                 # Import pipeline
│   │   ├── importarArchivo.m      # Single entry point
│   │   ├── detectarTipoArchivo.m  # Detects type by marker
│   │   └── parsers/
│   │       ├── parseRecording.m   # [REC] parser
│   │       ├── parseTrends.m      # [TRE] parser
│   │       ├── parseBreathTrends.m # BreathTrends parser
│   │       ├── parseRecruitment.m # [RECRUITMENT] parser
│   │       └── parseLogs.m        # [LOG] parser
│   │
│   ├── processors/                # Cleaning and normalization
│   │   ├── limpiarValores.m       # Cleans #, ***, -, BOM
│   │   └── estandarizarColumnas.m # Uniform names
│   │
│   ├── database/                  # Database management
│   │   ├── dbInit.m               # Initialize structure
│   │   ├── dbAddSession.m         # Assign session to patient
│   │   └── dbQuery.m              # Filter queries
│   │
│   ├── loaders/                   # Processed data loading
│   │   ├── cargarTrends.m         # (Legacy - use importarArchivo)
│   │   └── cargarRecruitment.m    # (Legacy - use importarArchivo)
│   │
│   └── analysis/                  # Analysis modules
│       ├── detectarCiclosRespiratorios.m
│       ├── calcularMecanicaRespiratoria.m
│       └── analizarLoop.m
│
├── docs/                          # Documentation
│   ├── README_TECNICO.md          # Technical Readme (Spanish)
│   ├── README_TECHNICAL.md        # This file (English)
│   ├── ESQUEMA_BASE_DATOS.md      # Detailed DB schema
│   ├── GUIA_USO_VISOR.md          # User guide
│   └── FICHA_TECNICA_PESTANAS.md  # Tab specification
│
├── respaldos/                     # Backups
│
└── tests/                         # Unit tests
    └── test_mecanicaRespiratoria.m
```

---

## Workflow

### 1. Import new data

```matlab
% Run from project directory
procesarDatosNuevos();

% Or with specific options
procesarDatosNuevos(struct('sobreescribir', true, 'verbose', true));
```

This:
1.  Scans `ventilatorData/` for .txt files
2.  Detects the type of each file ([REC], [TRE], [RECRUITMENT], [LOG])
3.  Parses and normalizes data
4.  Saves .mat in `database/sin_asignar/`
5.  Copies screenshots to the corresponding session

### 2. Assign to patient

```matlab
% Assign session to a patient
infoPaciente = struct(...
    'cama', 'Bed_12', ...
    'fechaIngreso', datetime('2026-01-28'), ...
    'motivoIngreso', 'ARDS post-COVID', ...
    'sexo', 'M', ...
    'edad', 65, ...
    'altura_cm', 175, ...
    'peso_kg', 85 ...
);

dbAddSession('database/sin_asignar/42376_20260128/sesion_1', infoPaciente);
```

### 3. Query data

```matlab
% All sessions
res = dbQuery();

% Only recordings
res = dbQuery(struct('tipo', 'recording'));

% Specific patient
res = dbQuery(struct('paciente', 'Bed_12'));

% Date range
res = dbQuery(struct(...
    'fechaDesde', datetime('2026-01-01'), ...
    'fechaHasta', datetime('2026-01-31') ...
));
```

### 4. Visualize

```matlab
% Open viewer
VentilatorRecordingViewer
```

---

## Supported File Types

### Recordings ([REC])
-   **Source**: `ventilatorData/recordings/*.txt`
-   **Frequency**: High (~100 Hz)
-   **Variables**: time_s, phase, pressure_cmH2O, flow_Lmin, volume_mL
-   **Use**: Detailed curve analysis, configurable P-V loops

### Trends ([TRE])
-   **Source**: `ventilatorData/trends/*_Trends.txt`
-   **Frequency**: 1 record per minute
-   **Variables**: ~40 parameters (Cdyn, PEEP, Vt, RR, Ppeak, etc.)
-   **Use**: Temporal evolution, correlations

### BreathTrends ([RECRUITMENT] with "BreathTrends" in name)
-   **Source**: `ventilatorData/trends/*_BreathTrends.txt`
-   **Frequency**: 1 record per breath
-   **Variables**: Cdyn, Pei, PEEP, Vce, Vci, IE, RR, etc.
-   **Use**: Breath-by-breath analysis

### Recruitments ([RECRUITMENT])
-   **Source**: `ventilatorData/recruitments/*.txt`
-   **Content**: Incremental PEEP steps
-   **Automatic analysis**: Optimal PEEP, max Cdyn, PEEP-Cdyn curve

### Logs ([LOG])
-   **Source**: `ventilatorData/logs/*.txt`
-   **Content**: Ventilator events
-   **Categories**: alarm, high_alarm, parameter, function, system
-   **Use**: Event timeline, correlation with data

---

## Main Components

### 1. Import Pipeline

| Component | Function |
| :--- | :--- |
| `importarArchivo.m` | Single entry point for any file |
| `detectarTipoArchivo.m` | Detects type by marker [REC], [TRE], etc. |
| `parseRecording.m` | Parses recording files (~100Hz) |
| `parseTrends.m` | Parses Trends files (per minute) |
| `parseBreathTrends.m` | Parses BreathTrends (per breath) |
| `parseRecruitment.m` | Parses recruitment maneuvers |
| `parseLogs.m` | Parses event logs |

### 2. Processors

| Component | Function |
| :--- | :--- |
| `limpiarValores.m` | Cleans markers (#), special values (***), BOM UTF-8 |
| `estandarizarColumnas.m` | Converts column names to standard format |

### 3. Database

| Component | Function |
| :--- | :--- |
| `dbInit.m` | Initializes folder structure and paths |
| `dbAddSession.m` | Assigns session to patient, moves files |
| `dbQuery.m` | Queries sessions by filters |

### 4. Analysis Modules

| Component | Function |
| :--- | :--- |
| `detectarCiclosRespiratorios.m` | Detects inspiration/expiration cycles |
| `calcularMecanicaRespiratoria.m` | Calculates Cst, Cdyn, Raw, ΔP, WOB |
| `analizarLoop.m` | Loop analysis (area, hysteresis, slopes) |
| `figuraResistencias.m` | Interactive resistance analysis with cycle selector |

---

## Normalized Data Structure

All processed .mat files have this common structure:

```matlab
data.version = '2.0';
data.tipo = 'recording';  % recording|trends|breathtrends|recruitment|logs
data.archivoOrigen = 'path/original.txt';
data.fechaProcesado = datetime;
data.metadatos = struct(...
    'ventiladorID', '42376', ...
    'sistemaVersion', '4.4', ...
    'fecha', datetime, ...
    'paciente', struct('sexo','M','altura',175,'peso',85,'PBW',70)
);
data.erroresImportacion = {};  % Problems found
data.tabla = table(...);       % Clean data
```

### Variables by Type

| Type | Main Variables |
| :--- | :--- |
| **recording** | time_s, phase, pressure_cmH2O, flow_Lmin, volume_mL |
| **trends** | time, Cdyn, PEEP, Vt, RR, FiO2, Ppeak, Pmean, VMe, mode |
| **breathtrends** | time, Cdyn, Pei, PEEP, Vce, Vci, IE, RR |
| **recruitment** | time, step, Cdyn, Pei, PEEP, Vce, Vci |
| **logs** | time, category, message, severity |

---

## Data Cleaning

The system automatically handles:

| Problem | Solution |
| :--- | :--- |
| UTF-8 BOM (ï»¿) | Removed at start of file |
| Marker # in values | Removed, value marked as "triggered" |
| Values *** | Converted to NaN |
| Values - (dash) | Converted to NaN |
| Empty cells | Converted to NaN |
| Names with accents/symbols | Normalized (Cdyn, PEEP, etc.) |

---

## Patient Identification

Each patient is identified by:

```matlab
paciente = struct(...
    'cama', 'Bed_12', ...            % Main identifier
    'fechaIngreso', datetime, ...    % Admission date
    'motivoIngreso', 'ARDS', ...     % Clinical reason
    'sexo', 'M', ...
    'edad', 65, ...
    'altura_cm', 175, ...
    'peso_kg', 85, ...
    'PBW_kg', 70, ...                % Predicted Body Weight
    'notas', '' ...
);
```

The patient folder is named: `Bed_{N}_{YYYYMMDD}/`

---

## Dependencies

-   MATLAB R2020b or higher
-   Does not require additional toolboxes

---

## Related Documentation

-   `docs/ESQUEMA_BASE_DATOS.md` - Detailed database schema
-   `docs/GUIA_USO_VISOR.md` - Viewer user guide
-   `docs/FICHA_TECNICA_PESTANAS.md` - Tab specification

---

## Version History
### v2.1.0 (2026-01-29)
- Interactive Resistance Analysis with cycle selector
- Instantaneous calculations of R/G/E
- Support for screenshots
- Patient assignment button

### v2.0 (2026-01-28)
-   Import pipeline with specialized parsers
-   Structured database by patient/session
-   Automatic special value cleaning
-   Support for 5 file types
-   Configurable loops (customizable X vs Y)

### v1.0
-   Basic viewer with tab system
-   Variable selection dropdowns


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
