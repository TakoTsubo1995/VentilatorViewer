function exito = dbAddSession(carpetaSesion, infoPaciente)
% DBADDSESSION - Asigna una sesión a un paciente en la base de datos
%
% Sintaxis:
%   exito = dbAddSession(carpetaSesion, infoPaciente)
%
% Entradas:
%   carpetaSesion - Ruta a la carpeta de sesión en sin_asignar/
%   infoPaciente  - Estructura con info del paciente:
%                   .cama          - Número/nombre de cama (obligatorio)
%                   .fecha         - Fecha de ingreso (datetime u string)
%                   .motivoIngreso - Motivo de ingreso (string)
%                   .sexo          - 'M' o 'F'
%                   .edad          - Edad en años
%                   .altura_cm     - Altura en cm
%                   .peso_kg       - Peso en kg
%                   .notas         - Notas adicionales
%
% Salida:
%   exito - true si se asignó correctamente
%
% Ejemplo:
%   paciente = struct('cama', 'Cama_12', 'motivoIngreso', 'SDRA', 'sexo', 'M');
%   dbAddSession('database/sin_asignar/42376_20260128', paciente);
%
% Ver también: dbInit, dbQuery, procesarDatosNuevos
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

exito = false;

% Validar entradas
if ~isfolder(carpetaSesion)
    error('dbAddSession:carpeta', 'No existe la carpeta: %s', carpetaSesion);
end

if ~isfield(infoPaciente, 'cama') || isempty(infoPaciente.cama)
    error('dbAddSession:paciente', 'Se requiere el campo "cama" en infoPaciente');
end

% Normalizar nombre de cama
cama = infoPaciente.cama;
cama = regexprep(cama, '[^a-zA-Z0-9_]', '_');

% Obtener fecha de la sesión
[~, nombreSesion] = fileparts(carpetaSesion);
partes = strsplit(nombreSesion, '_');
if length(partes) >= 2
    fechaSesion = partes{end};
else
    fechaSesion = datestr(now, 'yyyymmdd');
end

% Obtener directorio base de la DB
db = dbInit();

% Crear carpeta del paciente
nombreCarpetaPaciente = sprintf('%s_%s', cama, fechaSesion);
carpetaPaciente = fullfile(db.carpetaPacientes, nombreCarpetaPaciente);

if ~isfolder(carpetaPaciente)
    mkdir(carpetaPaciente);
end

% Determinar número de sesión
sesionesExistentes = dir(fullfile(carpetaPaciente, 'sesion_*'));
nSesion = length(sesionesExistentes) + 1;

% Crear carpeta de sesión
carpetaNuevaSesion = fullfile(carpetaPaciente, sprintf('sesion_%d', nSesion));
mkdir(carpetaNuevaSesion);

% Mover contenido de la sesión original
contenido = dir(carpetaSesion);
for i = 1:length(contenido)
    if startsWith(contenido(i).name, '.')
        continue;
    end

    origen = fullfile(carpetaSesion, contenido(i).name);
    destino = fullfile(carpetaNuevaSesion, contenido(i).name);

    if contenido(i).isdir
        % Es una subcarpeta (recordings, trends, etc.)
        movefile(origen, destino);
    else
        % Es un archivo - verificar si es imagen/screenshot
        [~, ~, ext] = fileparts(contenido(i).name);
        extLower = lower(ext);
        if ismember(extLower, {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tif', '.tiff'})
            % Crear carpeta screenshots si no existe
            carpetaScreenshots = fullfile(carpetaNuevaSesion, 'screenshots');
            if ~isfolder(carpetaScreenshots)
                mkdir(carpetaScreenshots);
            end
            destino = fullfile(carpetaScreenshots, contenido(i).name);
            movefile(origen, destino);
        elseif ismember(extLower, {'.mat', '.txt'})
            % Archivos de datos - mover directamente
            movefile(origen, destino);
        end
    end
end

% Crear archivo de info del paciente
pacienteInfo = struct();
pacienteInfo.cama = infoPaciente.cama;
pacienteInfo.fechaAsignacion = datetime('now');

if isfield(infoPaciente, 'fecha')
    if isdatetime(infoPaciente.fecha)
        pacienteInfo.fechaIngreso = infoPaciente.fecha;
    else
        pacienteInfo.fechaIngreso = datetime(infoPaciente.fecha);
    end
else
    pacienteInfo.fechaIngreso = datetime(fechaSesion, 'InputFormat', 'yyyyMMdd');
end

campos = {'motivoIngreso', 'sexo', 'edad', 'altura_cm', 'peso_kg', 'PBW_kg', 'notas'};
for i = 1:length(campos)
    if isfield(infoPaciente, campos{i})
        pacienteInfo.(campos{i}) = infoPaciente.(campos{i});
    end
end

% Calcular PBW si no está proporcionado
if ~isfield(pacienteInfo, 'PBW_kg') && isfield(pacienteInfo, 'altura_cm') && isfield(pacienteInfo, 'sexo')
    altura = pacienteInfo.altura_cm;
    if strcmpi(pacienteInfo.sexo, 'M')
        pacienteInfo.PBW_kg = 50 + 0.91 * (altura - 152.4);
    else
        pacienteInfo.PBW_kg = 45.5 + 0.91 * (altura - 152.4);
    end
end

% Guardar info del paciente
archivoPacienteInfo = fullfile(carpetaPaciente, 'paciente_info.mat');
save(archivoPacienteInfo, '-struct', 'pacienteInfo');

% Crear info de sesión
sessionInfo = struct();
sessionInfo.numeroSesion = nSesion;
sessionInfo.fechaCreacion = datetime('now');
sessionInfo.origenDatos = carpetaSesion;

archivoSessionInfo = fullfile(carpetaNuevaSesion, 'session_info.mat');
save(archivoSessionInfo, '-struct', 'sessionInfo');

% Eliminar carpeta original si está vacía
contenidoRestante = dir(carpetaSesion);
contenidoRestante = contenidoRestante(~startsWith({contenidoRestante.name}, '.'));
if isempty(contenidoRestante)
    rmdir(carpetaSesion);
end

% Actualizar índice
actualizarIndiceConPaciente(db.archivoIndice, nombreCarpetaPaciente, pacienteInfo);

exito = true;

fprintf('Sesión asignada: %s -> %s/sesion_%d\n', nombreSesion, nombreCarpetaPaciente, nSesion);

end


function actualizarIndiceConPaciente(archivoIndice, nombrePaciente, infoPaciente)
% Actualiza el índice con información del nuevo paciente

if isfile(archivoIndice)
    indexData = load(archivoIndice);
    index = indexData.index;
else
    return;
end

% Añadir paciente si no existe
if ~isfield(index, 'pacientes')
    index.pacientes = {};
end

% Verificar si ya existe
existe = false;
for i = 1:length(index.pacientes)
    if strcmp(index.pacientes{i}.nombre, nombrePaciente)
        existe = true;
        break;
    end
end

if ~existe
    pacienteEntry = struct();
    pacienteEntry.nombre = nombrePaciente;
    pacienteEntry.cama = infoPaciente.cama;
    pacienteEntry.fechaCreacion = datetime('now');
    if isfield(infoPaciente, 'motivoIngreso')
        pacienteEntry.motivoIngreso = infoPaciente.motivoIngreso;
    end
    index.pacientes{end+1} = pacienteEntry;
end

index.ultimaActualizacion = datetime('now');
save(archivoIndice, 'index');

end
