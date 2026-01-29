function resultados = dbQuery(filtros)
% DBQUERY - Consulta la base de datos de sesiones respiratorias
%
% Sintaxis:
%   resultados = dbQuery()
%   resultados = dbQuery(filtros)
%
% Entrada:
%   filtros - Estructura con criterios de filtrado (todos opcionales):
%             .tipo        - Tipo de datos: 'recording', 'trends', etc.
%             .paciente    - Nombre/cama del paciente
%             .fechaDesde  - Fecha mínima (datetime)
%             .fechaHasta  - Fecha máxima (datetime)
%             .incluyeSinAsignar - Incluir datos sin asignar (default: true)
%
% Salida:
%   resultados - Estructura con:
%                .sesiones    - Cell array de sesiones encontradas
%                .pacientes   - Lista de pacientes
%                .resumen     - Conteo por tipo
%
% Ejemplo:
%   % Todas las sesiones
%   res = dbQuery();
%
%   % Solo recordings
%   res = dbQuery(struct('tipo', 'recording'));
%
%   % Paciente específico
%   res = dbQuery(struct('paciente', 'Cama_12'));
%
% Ver también: dbInit, dbAddSession
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Valores por defecto
if nargin < 1
    filtros = struct();
end
if ~isfield(filtros, 'incluyeSinAsignar')
    filtros.incluyeSinAsignar = true;
end

% Inicializar DB
db = dbInit();

% Inicializar resultados
resultados = struct();
resultados.sesiones = {};
resultados.pacientes = {};
resultados.resumen = struct('recordings', 0, 'trends', 0, 'breathtrends', 0, ...
    'recruitments', 0, 'logs', 0);

% Buscar en pacientes asignados
if isfolder(db.carpetaPacientes)
    pacientes = dir(db.carpetaPacientes);
    pacientes = pacientes([pacientes.isdir] & ~startsWith({pacientes.name}, '.'));

    for i = 1:length(pacientes)
        pacienteNombre = pacientes(i).name;
        carpetaPaciente = fullfile(db.carpetaPacientes, pacienteNombre);

        % Filtrar por paciente si se especificó
        if isfield(filtros, 'paciente') && ~isempty(filtros.paciente)
            if ~contains(lower(pacienteNombre), lower(filtros.paciente))
                continue;
            end
        end

        % Cargar info del paciente
        archivoPacienteInfo = fullfile(carpetaPaciente, 'paciente_info.mat');
        if isfile(archivoPacienteInfo)
            pacienteInfo = load(archivoPacienteInfo);
            resultados.pacientes{end+1} = struct(...
                'nombre', pacienteNombre, ...
                'carpeta', carpetaPaciente, ...
                'info', pacienteInfo);
        end

        % Buscar sesiones
        sesiones = dir(fullfile(carpetaPaciente, 'sesion_*'));
        sesiones = sesiones([sesiones.isdir]);

        for j = 1:length(sesiones)
            sesionInfo = escanearSesion(fullfile(carpetaPaciente, sesiones(j).name), ...
                pacienteNombre, filtros);
            if ~isempty(sesionInfo)
                resultados.sesiones{end+1} = sesionInfo;
                resultados.resumen = actualizarResumen(resultados.resumen, sesionInfo);
            end
        end
    end
end

% Buscar en sin_asignar
if filtros.incluyeSinAsignar && isfolder(db.carpetaSinAsignar)
    sinAsignar = dir(db.carpetaSinAsignar);
    sinAsignar = sinAsignar([sinAsignar.isdir] & ~startsWith({sinAsignar.name}, '.'));

    for i = 1:length(sinAsignar)
        carpetaSesion = fullfile(db.carpetaSinAsignar, sinAsignar(i).name);

        % En sin_asignar, la carpeta es directamente la sesión (no tiene subcarpetas sesion_*)
        sesionInfo = escanearSesion(carpetaSesion, 'Sin asignar', filtros);
        if ~isempty(sesionInfo)
            resultados.sesiones{end+1} = sesionInfo;
            resultados.resumen = actualizarResumen(resultados.resumen, sesionInfo);
        end
    end
end

% Ordenar por fecha
if ~isempty(resultados.sesiones)
    fechas = cellfun(@(s) s.fecha, resultados.sesiones);
    [~, orden] = sort(fechas, 'descend');
    resultados.sesiones = resultados.sesiones(orden);
end

end


function sesionInfo = escanearSesion(carpetaSesion, pacienteNombre, filtros)
% Escanea una carpeta de sesión y devuelve su información

sesionInfo = [];

if ~isfolder(carpetaSesion)
    return;
end

% Extraer fecha del nombre de carpeta
[~, nombreCarpeta] = fileparts(carpetaSesion);

% Intentar extraer fecha
fecha = datetime('now');
partes = strsplit(nombreCarpeta, '_');
for k = 1:length(partes)
    if length(partes{k}) == 8 && all(isstrprop(partes{k}, 'digit'))
        try
            fecha = datetime(partes{k}, 'InputFormat', 'yyyyMMdd');
            break;
        catch
        end
    end
end

% Filtrar por fecha
if isfield(filtros, 'fechaDesde') && ~isempty(filtros.fechaDesde)
    if fecha < filtros.fechaDesde
        return;
    end
end
if isfield(filtros, 'fechaHasta') && ~isempty(filtros.fechaHasta)
    if fecha > filtros.fechaHasta
        return;
    end
end

% Contar archivos por tipo
archivos = struct();
tipos = {'recordings', 'trends', 'breathtrends', 'recruitments', 'logs', 'screenshots'};

for i = 1:length(tipos)
    carpetaTipo = fullfile(carpetaSesion, tipos{i});
    if isfolder(carpetaTipo)
        if strcmp(tipos{i}, 'screenshots')
            files = dir(fullfile(carpetaTipo, '*.png'));
        else
            files = dir(fullfile(carpetaTipo, '*.mat'));
        end
        archivos.(tipos{i}) = length(files);
    else
        archivos.(tipos{i}) = 0;
    end
end

% Filtrar por tipo si se especificó
if isfield(filtros, 'tipo') && ~isempty(filtros.tipo)
    tipoFiltro = [filtros.tipo 's'];  % recordings, trends, etc.
    if ~isfield(archivos, tipoFiltro) || archivos.(tipoFiltro) == 0
        return;
    end
end

% Crear info de sesión
sesionInfo = struct();
sesionInfo.paciente = pacienteNombre;
sesionInfo.carpeta = carpetaSesion;
sesionInfo.nombre = nombreCarpeta;
sesionInfo.fecha = fecha;
sesionInfo.archivos = archivos;
sesionInfo.totalArchivos = archivos.recordings + archivos.trends + ...
    archivos.breathtrends + archivos.recruitments + archivos.logs;

end


function resumen = actualizarResumen(resumen, sesionInfo)
% Actualiza el resumen de conteo

campos = fieldnames(sesionInfo.archivos);
for i = 1:length(campos)
    campo = campos{i};
    if isfield(resumen, campo)
        resumen.(campo) = resumen.(campo) + sesionInfo.archivos.(campo);
    end
end

end
