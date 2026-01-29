function inicializarVisor()
% INICIALIZARVISOR - Añade las carpetas del proyecto al path de MATLAB
%
% Ejecutar una vez al inicio de cada sesión o añadir a startup.m
%
% Uso:
%   inicializarVisor
%
% Estructura de carpetas (v2.0):
%   Respiradores/
%   ├── VentilatorRecordingViewer.m    (visor principal)
%   ├── inicializarVisor.m             (este archivo)
%   ├── procesarDatosNuevos.m          (importar datos crudos)
%   ├── src/
%   │   ├── analysis/                  (funciones de análisis)
%   │   ├── importers/                 (importadores de datos)
%   │   │   └── parsers/               (parsers por tipo de archivo)
%   │   ├── processors/                (limpieza y normalización)
%   │   ├── database/                  (gestión de base de datos)
%   │   ├── loaders/                   (carga de datos procesados)
%   │   └── utils/                     (utilidades)
%   ├── database/                      (base de datos estructurada)
%   │   ├── pacientes/                 (datos por paciente)
%   │   └── sin_asignar/               (datos sin asignar)
%   ├── ventilatorData/                (datos crudos originales)
%   ├── tests/                         (tests unitarios)
%   ├── docs/                          (documentación)
%   └── respaldos/                     (backups)
%
% Ver también: procesarDatosNuevos, VentilatorRecordingViewer, dbQuery

% Limpiar cache de clases para evitar problemas con versiones anteriores
if exist('VentilatorRecordingViewer', 'class')
    clear VentilatorRecordingViewer
end

% Obtener directorio base
baseDir = fileparts(mfilename('fullpath'));

% Añadir carpetas al path
addpath(baseDir);

% Módulos de análisis
addpath(fullfile(baseDir, 'src', 'analysis'));

% Módulos de importación (nuevos en v2.0)
addpath(fullfile(baseDir, 'src', 'importers'));
addpath(fullfile(baseDir, 'src', 'importers', 'parsers'));

% Módulos de procesamiento (nuevos en v2.0)
addpath(fullfile(baseDir, 'src', 'processors'));

% Módulos de base de datos (nuevos en v2.0)
addpath(fullfile(baseDir, 'src', 'database'));

% Loaders (simplificados en v2.0)
addpath(fullfile(baseDir, 'src', 'loaders'));

% Utilidades
if isfolder(fullfile(baseDir, 'src', 'utils'))
    addpath(fullfile(baseDir, 'src', 'utils'));
end

% Tests
addpath(fullfile(baseDir, 'tests'));

% Verificar/crear estructura de base de datos
carpetaDB = fullfile(baseDir, 'database');
if ~isfolder(carpetaDB)
    mkdir(carpetaDB);
    mkdir(fullfile(carpetaDB, 'pacientes'));
    mkdir(fullfile(carpetaDB, 'sin_asignar'));
end

% Mostrar información
fprintf('\n');
fprintf('=============================================\n');
fprintf('  VISOR SERVO-U v2.0 - Inicializado\n');
fprintf('=============================================\n');
fprintf('\n');
fprintf('Comandos disponibles:\n');
fprintf('  procesarDatosNuevos()    - Importar archivos nuevos\n');
fprintf('  VentilatorRecordingViewer - Abrir visor\n');
fprintf('  dbQuery()                - Consultar base de datos\n');
fprintf('\n');

% Verificar si hay datos sin procesar
carpetaDatos = fullfile(baseDir, 'ventilatorData');
if isfolder(carpetaDatos)
    archivos = dir(fullfile(carpetaDatos, '**', '*.txt'));
    archivos = archivos(~startsWith({archivos.name}, '.'));

    carpetaSinAsignar = fullfile(carpetaDB, 'sin_asignar');
    datosProcesados = dir(fullfile(carpetaSinAsignar, '*'));
    datosProcesados = datosProcesados([datosProcesados.isdir] & ~startsWith({datosProcesados.name}, '.'));

    if length(archivos) > 0 && length(datosProcesados) == 0
        fprintf('NOTA: Hay %d archivos sin procesar en ventilatorData/\n', length(archivos));
        fprintf('      Ejecute procesarDatosNuevos() para importarlos.\n');
        fprintf('\n');
    end
end

fprintf('=============================================\n');
fprintf('\n');

end
