# Changelog

Todos los cambios notables en este proyecto serán documentados aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

---

## [2.1.0] - 2026-01-29

### Añadido
- **Análisis de Resistencias Interactivo** (`figuraResistencias.m`)
  - Selector dropdown para visualizar ciclos individuales o promedio de todos
  - Gráficos de Raw vs Volumen (líneas por ciclo)
  - Gráficos de Conductancia (G = 1/R) vs Volumen
  - Gráficos de Elastancia (dP/dV) vs Volumen
  - Loop P-V del ciclo seleccionado con puntos clave marcados
  - Panel de resumen con Raw y Cst por ciclo
  - Leyenda de colores explicativa para modo promedio
  - Tabla de valores para ciclo individual

- **Cálculos Instantáneos de Resistencia** (`calcularMecanicaRespiratoria.m`)
  - Campo `mecanica.curvasInstantaneas{}` con datos por ciclo:
    - `rawInstantanea`: Resistencia instantánea durante el ciclo
    - `conductanciaInstantanea`: Conductancia (1/Raw)
    - `elastancia`: Elastancia instantánea (dP/dV)
    - `volumen`, `presion`, `flujo`: Datos del ciclo
    - `volumenNorm`: Volumen normalizado (0-1)

- **Soporte para Screenshots** (`VentilatorRecordingViewer.m`, `dbAddSession.m`)
  - Listado de imágenes con prefijo `[SCR]` en el visor
  - Visualización de screenshots en ventana separada con `imshow`
  - Movimiento de imágenes a carpeta `screenshots/` al asignar sesiones

- **Botón de Asignación de Pacientes** (`VentilatorRecordingViewer.m`)
  - Botón "Asignar a Paciente" en panel izquierdo
  - Diálogo para introducir datos: Cama, Sexo, Altura, Peso, Motivo Ingreso
  - Validación de sesiones desde `sin_asignar` únicamente
  - Actualización automática de listas tras asignación

### Mejorado
- **Logs Tab**
  - Corrección de visualización de timeline con colores por categoría
  - Mapeo correcto de colores: Alarma (rojo), Cambio parámetro (azul), etc.
  - Etiquetas de eje Y con nombres de categorías reales
  - Resumen adaptado para datos de logs (conteo por categoría/severidad)

- **Mecánica Tab**
  - Loops P-V ahora se grafican en `AxesMecanica` con gradiente de colores
  - Llamada a `figuraResistencias()` para análisis detallado
  - Línea de compliance estática superpuesta

- **Detección de Ciclos** (`detectarCiclosRespiratorios.m`)
  - Soporte para nombres de columna `FaseRespiratoria` y `Fase_Respiratoria`

### Corregido
- Error de `UITable.Data` no compatible con `datetime` en logs
- Conversión de datos de celdas a strings para tablas
- Variables `hayCurvasInst`, `figRes` no usadas tras refactorización

---

## [2.0.0] - 2026-01-28

### Añadido
- Sistema de base de datos estructurada con índice maestro
- Pipeline de importación automática de archivos .txt
- Visor adaptativo por tipo de dato (REC, Trends, etc.)
- Módulo de cálculo de mecánica respiratoria
- Detección automática de ciclos respiratorios

---

## [1.0.0] - 2026-01-XX

### Inicial
- Visor básico de grabaciones de ventilador
- Parsers para diferentes tipos de archivos SERVO-U
