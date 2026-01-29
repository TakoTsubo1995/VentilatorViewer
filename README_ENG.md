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
