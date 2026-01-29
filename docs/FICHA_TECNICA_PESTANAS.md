# Ficha Técnica: Sistema de Pestañas del Visor

> **Versión**: 2.0  
> **Fecha**: 2026-01-28  
> **Autor**: Proyecto Fisiología Respiratoria  
> **Respaldo**: `respaldos/VentilatorRecordingViewer_v2_antes_pestanas.m`

---

## Descripción General

Sistema de visualización con 4 pestañas para explorar datos de ventilador SERVO-U. Permite visualizar grabaciones, trends y maniobras de reclutamiento.

## Estructura de Pestañas

| Pestaña | Componente | Función |
|---------|------------|---------|
| Resumen | `UITable` | Estadísticas de todas las variables (min/max/media/desv) |
| Curvas | 4 `UIAxes` + 4 `DropDown` | Gráficos configurables por variable |
| Loops P-V | `UIAxes` grande | Loop presión-volumen |
| Tendencias | `UIAxes` grande | Evolución temporal superpuesta |

---

## Propiedades Añadidas

```matlab
% Sistema de pestañas
TabGroup                   matlab.ui.container.TabGroup
TabResumen                 matlab.ui.container.Tab
TabCurvas                  matlab.ui.container.Tab
TabLoops                   matlab.ui.container.Tab
TabTendencias              matlab.ui.container.Tab

% Tabla resumen
SummaryTable               matlab.ui.control.Table

% Dropdowns para Curvas
Var1Dropdown               matlab.ui.control.DropDown
Var2Dropdown               matlab.ui.control.DropDown
Var3Dropdown               matlab.ui.control.DropDown
Var4Dropdown               matlab.ui.control.DropDown

% Axes adicionales
AxesTrend1                 matlab.ui.control.UIAxes  % P-V loop
AxesTrend2                 matlab.ui.control.UIAxes  % Tendencias
```

---

## Métodos Nuevos

| Método | Ubicación | Función |
|--------|-----------|---------|
| `updateSummaryTable` | L557-598 | Calcula y muestra estadísticas |
| `updateVariableDropdowns` | L600-640 | Pobla dropdowns con columnas disponibles |
| `plotSelectedVariables` | L642-656 | Grafica las 4 variables seleccionadas |
| `plotVar` | L658-681 | Helper: grafica una variable en un axes |
| `updateLoopTab` | L683-718 | Actualiza pestaña P-V |
| `updateTrendsTab` | L720-758 | Actualiza pestaña Tendencias |
| `VarDropdownChanged` | L868-873 | Callback de cambio de dropdown |
| `extractColumnData` | L491-515 | Extrae datos numéricos manejando caracteres especiales |

---

## Flujo de Datos

```
LoadButtonPushed
    ├── cargarRecording/cargarTrends/cargarRecruitment
    ├── updateSummaryTable()      → Llena tabla Resumen
    └── updateVariableDropdowns()
            ├── plotSelectedVariables() → Llena Curvas
            ├── updateLoopTab()         → Llena P-V
            └── updateTrendsTab()       → Llena Tendencias
```

---

## Problemas Conocidos (Pendientes)

### 1. Dropdowns no controlan eje Y
- Solo hay 1 dropdown por gráfico, debería haber X + Y
- El eje X siempre es índice (1, 2, 3...)

### 2. Eje X no usa timestamp
- Grabaciones tienen `TiempoSeg` pero no se usa en Curvas

### 3. P-V no funciona para grabaciones
- Busca `pei`/`peep`/`vci`/`vce` pero grabaciones usan `Presion`/`Volumen`

### 4. P-V muestra scatter sin conectar
- Los puntos no forman un loop visual

---

## Tareas Pendientes

- [ ] Añadir dropdown de eje X para cada gráfico
- [ ] Usar `TiempoSeg` en eje X cuando disponible
- [ ] Expandir búsqueda de columnas P-V para grabaciones
- [ ] Conectar puntos en P-V con línea
- [ ] Colorear P-V por ciclo respiratorio

---

## Dependencias

- `src/loaders/cargarTrends.m` - Modificado para priorizar `[DATA]` sobre `=====`
- `src/loaders/cargarRecording.m`
- `src/loaders/cargarRecruitment.m`
