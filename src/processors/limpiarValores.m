function [valorLimpio, teniaMarcador] = limpiarValores(valor)
% LIMPIARVALORES - Limpia valores numéricos de archivos del ventilador SERVO-U
%
% Sintaxis:
%   [valorLimpio, teniaMarcador] = limpiarValores(valor)
%
% Entrada:
%   valor - Valor a limpiar (string, char, cell, o numérico)
%
% Salidas:
%   valorLimpio  - Valor numérico limpio (NaN si no es convertible)
%   teniaMarcador - true si el valor tenía marcadores especiales (#, ***, etc.)
%
% Maneja los siguientes casos especiales del SERVO-U:
%   '#' prefijo   -> Valor marcado (se elimina #, se conserva número)
%   '***'         -> Sin dato válido -> NaN
%   '-'           -> Sin dato -> NaN
%   ''            -> Vacío -> NaN
%   Espacios      -> Se eliminan
%   BOM UTF-8     -> Se elimina
%
% Ejemplo:
%   [v, m] = limpiarValores('#21.8');  % v = 21.8, m = true
%   [v, m] = limpiarValores('***');    % v = NaN, m = true
%   [v, m] = limpiarValores('25.3');   % v = 25.3, m = false
%
% Ver también: estandarizarColumnas, parseRecording
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar
teniaMarcador = false;

% Si ya es numérico, devolver directamente
if isnumeric(valor)
    valorLimpio = valor;
    return;
end

% Convertir a string si es cell
if iscell(valor)
    if isempty(valor)
        valorLimpio = NaN;
        return;
    end
    valor = valor{1};
end

% Convertir a char para procesamiento
if isstring(valor)
    valor = char(valor);
end

% Si no es char, intentar conversión
if ~ischar(valor)
    try
        valorLimpio = double(valor);
    catch
        valorLimpio = NaN;
    end
    return;
end

% Eliminar BOM UTF-8 si existe (carácter 65279 o secuencia EF BB BF)
if ~isempty(valor) && (valor(1) == 65279 || valor(1) == 239)
    valor = valor(2:end);
end

% Eliminar espacios
valor = strtrim(valor);

% Casos especiales -> NaN
if isempty(valor)
    valorLimpio = NaN;
    return;
end

if strcmp(valor, '***') || strcmp(valor, '-') || strcmp(valor, '--')
    valorLimpio = NaN;
    teniaMarcador = true;
    return;
end

% Detectar y eliminar marcador '#'
if valor(1) == '#'
    teniaMarcador = true;
    valor = valor(2:end);
    valor = strtrim(valor);
end

% Detectar y eliminar marcador '*' al final
if ~isempty(valor) && valor(end) == '*'
    teniaMarcador = true;
    valor = valor(1:end-1);
    valor = strtrim(valor);
end

% Manejar relaciones I:E especiales (ej: "1 : 2.0", "4.5 : 1")
if contains(valor, ':')
    % Es una relación, devolver como string especial o NaN
    % Por ahora devolvemos NaN para valores numéricos
    valorLimpio = NaN;
    return;
end

% Intentar conversión a número
valorLimpio = str2double(valor);

end


function datos = limpiarColumna(columna)
% LIMPIARCOLUMNA - Limpia una columna completa de datos
%
% Sintaxis:
%   datos = limpiarColumna(columna)
%
% Entrada:
%   columna - Vector cell o numérico
%
% Salida:
%   datos - Vector numérico con valores limpios

if isnumeric(columna)
    datos = columna;
    return;
end

n = length(columna);
datos = zeros(n, 1);

for i = 1:n
    datos(i) = limpiarValores(columna{i});
end

end


function texto = limpiarTexto(valor)
% LIMPIARTEXTO - Limpia un valor de texto (no numérico)
%
% Sintaxis:
%   texto = limpiarTexto(valor)
%
% Entrada:
%   valor - Valor de texto a limpiar
%
% Salida:
%   texto - Texto limpio (sin BOM, espacios extra, etc.)

if iscell(valor)
    if isempty(valor)
        texto = '';
        return;
    end
    valor = valor{1};
end

if isstring(valor)
    valor = char(valor);
end

if ~ischar(valor)
    texto = '';
    return;
end

% Eliminar BOM
if ~isempty(valor) && (valor(1) == 65279 || valor(1) == 239)
    valor = valor(2:end);
end

% Limpiar espacios
texto = strtrim(valor);

% Eliminar caracteres HTML como <sub> </sub>
texto = regexprep(texto, '<[^>]+>', '');

end
