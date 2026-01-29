function data = importarArchivo(archivo)
% IMPORTARARCHIVO - Importa cualquier archivo del ventilador SERVO-U
%
% Sintaxis:
%   data = importarArchivo(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt del ventilador
%
% Salida:
%   data - Estructura normalizada con los datos (formato depende del tipo)
%
% Esta función detecta automáticamente el tipo de archivo y llama al
% parser correspondiente:
%   - [REC]         -> parseRecording
%   - [TRE]         -> parseTrends
%   - [RECRUITMENT] -> parseBreathTrends o parseRecruitment
%   - [LOG]         -> parseLogs
%
% Ejemplo:
%   data = importarArchivo('ventilatorData/recordings/1769620787164.txt');
%   disp(data.tipo);  % 'recording'
%   disp(data.tabla); % Tabla con datos
%
% Ver también: detectarTipoArchivo, procesarDatosNuevos
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Validar entrada
if nargin < 1 || isempty(archivo)
    error('importarArchivo:entrada', 'Se requiere la ruta del archivo');
end

if ~isfile(archivo)
    error('importarArchivo:archivo', 'No se encontró el archivo: %s', archivo);
end

% Detectar tipo de archivo
[tipo, marcador] = detectarTipoArchivo(archivo);

% Llamar al parser correspondiente
switch tipo
    case 'recording'
        data = parseRecording(archivo);

    case 'trends'
        data = parseTrends(archivo);

    case 'breathtrends'
        data = parseBreathTrends(archivo);

    case 'recruitment'
        data = parseRecruitment(archivo);

    case 'logs'
        data = parseLogs(archivo);

    otherwise
        error('importarArchivo:tipoDesconocido', ...
            'Tipo de archivo no soportado: %s (marcador: %s)', tipo, marcador);
end

% Añadir información común
data.importadoPor = 'importarArchivo v2.0';
data.fechaImportacion = datetime('now');

end
