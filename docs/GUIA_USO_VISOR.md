# Guía de Uso - Visor Avanzado del Ventilador SERVO-U

## Inicio Rápido

```matlab
% 1. Inicializar (añade carpetas al path)
cd 'c:\Users\crisr\MATLAB Drive\Fisiología Respiratoria\Respiradores'
inicializarVisor

% 2. Abrir el visor
VentilatorRecordingViewer
```

---

## Estructura de Carpetas

```
Respiradores/
├── VentilatorRecordingViewer.m     ← Visor principal
├── inicializarVisor.m              ← Ejecutar primero (añade al path)
├── src/
│   ├── analysis/
│   │   ├── calcularMecanicaRespiratoria.m
│   │   ├── detectarCiclosRespiratorios.m
│   │   └── analizarLoop.m
│   ├── loaders/
│   │   ├── cargarTrends.m
│   │   └── cargarRecruitment.m
│   └── utils/
├── tests/
│   └── test_mecanicaRespiratoria.m
├── docs/
│   └── GUIA_USO_VISOR.md           ← Este archivo
├── respaldos/
│   └── VentilatorRecordingViewer_v1_backup.m
└── ventilatorData/
    ├── recordings/    ← Curvas a 100 Hz
    ├── trends/        ← Datos por minuto
    └── recruitments/  ← Maniobras de reclutamiento
```

---

## Loops Configurables

| Combinación | Uso Clínico |
|-------------|-------------|
| **P-V** | Compliance, WOB, histéresis |
| **F-V** | Obstrucción vía aérea, EPOC |
| **P-F** | Resistencia, asincronías |
| **V-t** | Patrón ventilatorio |

---

## Parámetros de Mecánica Respiratoria

| Parámetro | Fórmula | Valores Normales |
|-----------|---------|------------------|
| **Cst** | Vt / (Pplateau - PEEP) | 60-100 mL/cmH2O |
| **Cdyn** | Vt / (Ppico - PEEP) | 40-60 mL/cmH2O |
| **Raw** | (Ppico - Pplateau) / Flujo | 2-4 cmH2O·s/L |
| **ΔP** | Pplateau - PEEP | < 15 cmH2O |
| **WOB** | ∫P·dV | 0.3-0.6 J/L |

---

## Tests

```matlab
% Ejecutar tests automáticos
runtests('test_mecanicaRespiratoria')

% Validación manual (compara con datos del ventilador)
test_mecanicaRespiratoria.validacionManual()
```
