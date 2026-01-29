function db = dbInit(baseDir)
% DBINIT - Inicializa la estructura de base de datos
%
% Sintaxis:
%   db = dbInit()
%   db = dbInit(baseDir)
%
% Entrada:
%   baseDir - (opcional) Directorio base del proyecto
%
% Salida:
%   db - Estructura con información de la base de datos
%
% Crea la estructura de carpetas necesaria:
%   database/
%   ├── index.mat
%   ├── pacientes/
%   └── sin_asignar/
%
% Ver también: dbIndex, dbAddSession, procesarDatosNuevos
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

if nargin < 1 || isempty(baseDir)
    baseDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

carpetaDB = fullfile(baseDir, 'database');
carpetaPacientes = fullfile(carpetaDB, 'pacientes');
carpetaSinAsignar = fullfile(carpetaDB, 'sin_asignar');

% Crear carpetas si no existen
carpetas = {carpetaDB, carpetaPacientes, carpetaSinAsignar};
for i = 1:length(carpetas)
    if ~isfolder(carpetas{i})
        mkdir(carpetas{i});
    end
end

% Inicializar o cargar índice
archivoIndice = fullfile(carpetaDB, 'index.mat');
if isfile(archivoIndice)
    indexData = load(archivoIndice);
    index = indexData.index;
else
    index = struct();
    index.version = '2.0';
    index.fechaCreacion = datetime('now');
    index.ultimaActualizacion = datetime('now');
    index.archivosOrigen = {};
    index.registros = {};
    index.pacientes = {};
    save(archivoIndice, 'index');
end

% Devolver información de la DB
db = struct();
db.baseDir = baseDir;
db.carpetaDB = carpetaDB;
db.carpetaPacientes = carpetaPacientes;
db.carpetaSinAsignar = carpetaSinAsignar;
db.archivoIndice = archivoIndice;
db.index = index;
db.version = index.version;

end
