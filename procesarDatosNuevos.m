function resumen = procesarDatosNuevos(opciones)
% PROCESARDATOSNUEVOS - Procesa archivos nuevos del ventilador y los añade a la base de datos
%
% Sintaxis:
%   resumen = procesarDatosNuevos()
%   resumen = procesarDatosNuevos(opciones)
%
% Opciones:
%   opciones.sobreescribir  - true: reprocesa archivos ya procesados (default: false)
%   opciones.verbose        - true: muestra progreso detallado (default: true)
%   opciones.carpetaOrigen  - Carpeta con datos crudos (default: 'ventilatorData')
%
% Salida:
%   resumen - Estructura con:
%             .archivosEncontrados - Número total de archivos .txt
%             .archivosProcesados  - Número procesados exitosamente
%             .archivosConErrores  - Número con errores
%             .archivosOmitidos    - Número omitidos (ya procesados)
%             .detalles            - Cell array con info de cada archivo
%
% Flujo:
%   1. Escanea ventilatorData/ recursivamente buscando .txt
%   2. Para cada archivo, detecta tipo y lo parsea
%   3. Guarda .mat en database/sin_asignar/{ventilador}_{fecha}/
%   4. Actualiza el índice maestro
%
% Ejemplo:
%   % Procesar todos los archivos nuevos
%   resumen = procesarDatosNuevos();
%
%   % Forzar reprocesamiento
%   resumen = procesarDatosNuevos(struct('sobreescribir', true));
%
% Ver también: importarArchivo, dbInit, dbIndex
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Agregar paths necesarios
baseDir = fileparts(mfilename('fullpath'));
addpath(fullfile(baseDir, 'src', 'importers'));
addpath(fullfile(baseDir, 'src', 'importers', 'parsers'));
addpath(fullfile(baseDir, 'src', 'processors'));
addpath(fullfile(baseDir, 'src', 'database'));

% Opciones por defecto
if nargin < 1
    opciones = struct();
end
if ~isfield(opciones, 'sobreescribir')
    opciones.sobreescribir = false;
end
if ~isfield(opciones, 'verbose')
    opciones.verbose = true;
end
if ~isfield(opciones, 'carpetaOrigen')
    opciones.carpetaOrigen = 'ventilatorData';
end

% Obtener directorio base
baseDir = fileparts(mfilename('fullpath'));
carpetaOrigen = fullfile(baseDir, opciones.carpetaOrigen);
carpetaDB = fullfile(baseDir, 'database');
carpetaSinAsignar = fullfile(carpetaDB, 'sin_asignar');

% Asegurar que existen las carpetas
if ~isfolder(carpetaDB)
    mkdir(carpetaDB);
end
if ~isfolder(carpetaSinAsignar)
    mkdir(carpetaSinAsignar);
end

% Inicializar resumen
resumen = struct();
resumen.archivosEncontrados = 0;
resumen.archivosProcesados = 0;
resumen.archivosConErrores = 0;
resumen.archivosOmitidos = 0;
resumen.detalles = {};

% Buscar archivos .txt recursivamente
archivos = dir(fullfile(carpetaOrigen, '**', '*.txt'));

% Filtrar archivos de sistema
archivos = archivos(~startsWith({archivos.name}, '.'));

resumen.archivosEncontrados = length(archivos);

if opciones.verbose
    fprintf('\n========================================\n');
    fprintf('PROCESAMIENTO DE DATOS DEL VENTILADOR\n');
    fprintf('========================================\n');
    fprintf('Carpeta origen: %s\n', carpetaOrigen);
    fprintf('Archivos encontrados: %d\n\n', length(archivos));
end

% Cargar o crear índice de archivos procesados
archivoIndice = fullfile(carpetaDB, 'index.mat');
if isfile(archivoIndice)
    indexData = load(archivoIndice);
    archivosProcesadosAntes = indexData.index.archivosOrigen;
else
    archivosProcesadosAntes = {};
end

% Procesar cada archivo
for i = 1:length(archivos)
    archivoInfo = archivos(i);
    rutaCompleta = fullfile(archivoInfo.folder, archivoInfo.name);

    % Verificar si ya fue procesado
    if ~opciones.sobreescribir && any(strcmp(archivosProcesadosAntes, rutaCompleta))
        resumen.archivosOmitidos = resumen.archivosOmitidos + 1;
        if opciones.verbose
            fprintf('[%d/%d] OMITIDO (ya procesado): %s\n', i, length(archivos), archivoInfo.name);
        end
        continue;
    end

    if opciones.verbose
        fprintf('[%d/%d] Procesando: %s... ', i, length(archivos), archivoInfo.name);
    end

    try
        % Importar archivo
        data = importarArchivo(rutaCompleta);

        % Determinar carpeta de destino
        if isfield(data.metadatos, 'ventiladorID')
            ventiladorID = data.metadatos.ventiladorID;
        else
            ventiladorID = 'desconocido';
        end

        % Extraer fecha del archivo
        if isfield(data.metadatos, 'fechaArchivo')
            fechaStr = data.metadatos.fechaArchivo;
            % Convertir formato "28/01/26 17:25:10" a "20260128"
            try
                fechaDT = datetime(fechaStr, 'InputFormat', 'dd/MM/yy HH:mm:ss');
                fechaCarpeta = datestr(fechaDT, 'yyyymmdd');
            catch
                fechaCarpeta = datestr(now, 'yyyymmdd');
            end
        else
            fechaCarpeta = datestr(now, 'yyyymmdd');
        end

        % Crear carpeta de destino
        carpetaDestino = fullfile(carpetaSinAsignar, sprintf('%s_%s', ventiladorID, fechaCarpeta));
        if ~isfolder(carpetaDestino)
            mkdir(carpetaDestino);
        end

        % Crear subcarpeta según tipo
        tipoPlural = data.tipo;
        if ~endsWith(tipoPlural, 's')
            tipoPlural = [tipoPlural 's'];  % recording -> recordings
        end
        subcarpeta = fullfile(carpetaDestino, tipoPlural);
        if ~isfolder(subcarpeta)
            mkdir(subcarpeta);
        end

        % Generar nombre de archivo de salida
        [~, nombreBase, ~] = fileparts(archivoInfo.name);
        archivoSalida = fullfile(subcarpeta, [nombreBase '.mat']);

        % Guardar datos procesados
        save(archivoSalida, '-struct', 'data');

        % Registrar éxito
        resumen.archivosProcesados = resumen.archivosProcesados + 1;
        resumen.detalles{end+1} = struct(...
            'archivo', rutaCompleta, ...
            'tipo', data.tipo, ...
            'destino', archivoSalida, ...
            'estado', 'ok', ...
            'nRegistros', height(data.tabla));

        if opciones.verbose
            fprintf('OK (%s, %d registros)\n', data.tipo, height(data.tabla));
        end

    catch ME
        % Registrar error
        resumen.archivosConErrores = resumen.archivosConErrores + 1;
        resumen.detalles{end+1} = struct(...
            'archivo', rutaCompleta, ...
            'tipo', 'error', ...
            'destino', '', ...
            'estado', 'error', ...
            'mensaje', ME.message);

        if opciones.verbose
            fprintf('ERROR: %s\n', ME.message);
        end
    end
end

% Actualizar índice maestro
actualizarIndiceMaestro(carpetaDB, resumen.detalles);

% Procesar screenshots (copiar a carpetas correspondientes)
procesarScreenshots(carpetaOrigen, carpetaSinAsignar, opciones.verbose);

% Mostrar resumen final
if opciones.verbose
    fprintf('\n========================================\n');
    fprintf('RESUMEN DE PROCESAMIENTO\n');
    fprintf('========================================\n');
    fprintf('Archivos encontrados: %d\n', resumen.archivosEncontrados);
    fprintf('Procesados OK:        %d\n', resumen.archivosProcesados);
    fprintf('Con errores:          %d\n', resumen.archivosConErrores);
    fprintf('Omitidos:             %d\n', resumen.archivosOmitidos);
    fprintf('========================================\n\n');

    if resumen.archivosProcesados > 0
        fprintf('Datos guardados en: %s\n', carpetaSinAsignar);
        fprintf('Use asignarAPaciente() para organizar por paciente.\n');
    end
end

end


function actualizarIndiceMaestro(carpetaDB, detalles)
% Actualiza el índice maestro con los nuevos archivos procesados

archivoIndice = fullfile(carpetaDB, 'index.mat');

% Cargar índice existente o crear nuevo
if isfile(archivoIndice)
    indexData = load(archivoIndice);
    index = indexData.index;
else
    index = struct();
    index.version = '2.0';
    index.fechaCreacion = datetime('now');
    index.archivosOrigen = {};
    index.registros = {};
end

index.ultimaActualizacion = datetime('now');

% Añadir nuevos registros
for i = 1:length(detalles)
    det = detalles{i};
    if strcmp(det.estado, 'ok')
        index.archivosOrigen{end+1} = det.archivo;
        index.registros{end+1} = struct(...
            'archivoOrigen', det.archivo, ...
            'archivoProcesado', det.destino, ...
            'tipo', det.tipo, ...
            'nRegistros', det.nRegistros, ...
            'fechaProcesado', datetime('now'));
    end
end

% Guardar
save(archivoIndice, 'index');

end


function procesarScreenshots(carpetaOrigen, carpetaSinAsignar, verbose)
% Copia screenshots a las carpetas de sesión correspondientes

carpetaScreenshots = fullfile(carpetaOrigen, 'screenshots');
if ~isfolder(carpetaScreenshots)
    return;
end

screenshots = dir(fullfile(carpetaScreenshots, '*.png'));

if isempty(screenshots)
    return;
end

if verbose
    fprintf('\nProcesando %d screenshots...\n', length(screenshots));
end

% Buscar carpetas de sesión existentes
sesiones = dir(fullfile(carpetaSinAsignar, '*_*'));
sesiones = sesiones([sesiones.isdir]);

for i = 1:length(screenshots)
    screenshotPath = fullfile(screenshots(i).folder, screenshots(i).name);

    % Extraer fecha del nombre del screenshot (formato: YYMMDD_HHMMSS.png)
    nombreBase = screenshots(i).name;

    % Buscar sesión correspondiente por fecha
    for j = 1:length(sesiones)
        carpetaSesion = fullfile(carpetaSinAsignar, sesiones(j).name);

        % Crear subcarpeta screenshots
        carpetaDestinoScreenshots = fullfile(carpetaSesion, 'screenshots');
        if ~isfolder(carpetaDestinoScreenshots)
            mkdir(carpetaDestinoScreenshots);
        end

        % Copiar screenshot
        destino = fullfile(carpetaDestinoScreenshots, nombreBase);
        if ~isfile(destino)
            copyfile(screenshotPath, destino);
            if verbose
                fprintf('  Copiado: %s -> %s\n', nombreBase, sesiones(j).name);
            end
        end
    end
end

end
