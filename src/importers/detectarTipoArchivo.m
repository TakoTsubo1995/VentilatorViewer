function [tipo, marcador] = detectarTipoArchivo(archivo)
% DETECTARTIPOARCHIVO - Detecta el tipo de archivo del ventilador SERVO-U
%
% Sintaxis:
%   [tipo, marcador] = detectarTipoArchivo(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt
%
% Salidas:
%   tipo     - string: 'recording', 'trends', 'breathtrends', 'recruitment', 'logs', 'desconocido'
%   marcador - string: marcador encontrado ('[REC]', '[TRE]', etc.)
%
% Detecta el tipo basándose en el marcador de la primera línea:
%   [REC]         -> recording (grabación de curvas ~100Hz)
%   [TRE]         -> trends (tendencias por minuto)
%   [RECRUITMENT] -> breathtrends o recruitment (según contenido)
%   [LOG]         -> logs (eventos y alarmas)
%
% Ejemplo:
%   [tipo, marcador] = detectarTipoArchivo('SERVO-U_42376_260128-172510_Trends.txt');
%   % tipo = 'trends', marcador = '[TRE]'
%
% Ver también: importarArchivo, parseRecording, parseTrends
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Validar entrada
if ~isfile(archivo)
    error('detectarTipoArchivo:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer primeras líneas del archivo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('detectarTipoArchivo:lectura', 'No se pudo abrir el archivo: %s', archivo);
end

primeraLinea = fgetl(fid);
fclose(fid);

% Eliminar BOM UTF-8 si existe
if length(primeraLinea) >= 3 && primeraLinea(1) == 65279
    primeraLinea = primeraLinea(2:end);
end
primeraLinea = strtrim(primeraLinea);

% Detectar marcador
if startsWith(primeraLinea, '[REC]')
    tipo = 'recording';
    marcador = '[REC]';

elseif startsWith(primeraLinea, '[TRE]')
    tipo = 'trends';
    marcador = '[TRE]';

elseif startsWith(primeraLinea, '[LOG]')
    tipo = 'logs';
    marcador = '[LOG]';

elseif startsWith(primeraLinea, '[RECRUITMENT]')
    % Puede ser breathtrends o recruitment real
    % Distinguir por nombre de archivo o contenido
    [~, nombre, ~] = fileparts(archivo);
    if contains(lower(nombre), 'breathtrend')
        tipo = 'breathtrends';
    else
        % Verificar si tiene estructura de maniobra de reclutamiento
        % (intervalos cortos de tiempo, pasos de PEEP)
        tipo = 'recruitment';
    end
    marcador = '[RECRUITMENT]';

else
    tipo = 'desconocido';
    marcador = primeraLinea;
    warning('detectarTipoArchivo:desconocido', ...
        'Tipo de archivo no reconocido. Primera línea: %s', primeraLinea);
end

end
