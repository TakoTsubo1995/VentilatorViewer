function [metadatos, datos] = cargarTrends(archivo)
% CARGARTRENDS - Carga archivo de tendencias del ventilador SERVO-U
%
% Sintaxis:
%   [metadatos, datos] = cargarTrends(archivo)
%
% Entrada:
%   archivo - Ruta al archivo de Trends (.txt)
%
% Salidas:
%   metadatos - Estructura con información del archivo
%   datos     - Tabla con datos de tendencias (>40 variables por minuto)
%
% Ejemplo:
%   [meta, trends] = cargarTrends('SERVO-U_42376_260128-172510_Trends.txt');
%   plot(trends.Tiempo, trends.Cdyn);
%
% Ver también: cargarRecruitment, VentilatorRecordingViewer
%
% Autor: Generado para proyecto de Fisiología Respiratoria
% Fecha: 2026-01-28

% Validar archivo
if ~isfile(archivo)
    error('cargarTrends:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido
fid = fopen(archivo, 'r', 'n', 'UTF-8');
contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lineas = contenido{1};

% Inicializar metadatos
metadatos = struct();
metadatos.Archivo = archivo;
metadatos.Tipo = 'Trends';

% Encontrar línea de separación y encabezados
% Soporta dos formatos: ===== (Trends) o [DATA] (BreathTrends)
% Priorizar [DATA] si existe (BreathTrends tiene ambos marcadores)
lineaSep = find(startsWith(lineas, '====='));
lineaData = find(strcmp(lineas, '[DATA]'));

if ~isempty(lineaData)
    % Formato BreathTrends: encabezados en [DATA]+1, datos en [DATA]+2
    % PRIORIDAD porque BreathTrends tiene ===== Y [DATA]
    lineaEncabezados = lineaData + 1;
    lineaInicioDatos = lineaData + 2;
    metadatos.Tipo = 'BreathTrends';
elseif ~isempty(lineaSep)
    % Formato Trends: encabezados después de =====
    lineaEncabezados = lineaSep + 1;
    lineaInicioDatos = lineaSep + 2;
    metadatos.Tipo = 'Trends';
else
    error('cargarTrends:formato', 'Formato de archivo no reconocido');
end

% Procesar metadatos (antes del separador)
lineaFin = min([lineaSep, lineaData, length(lineas)]);
for i = 1:lineaFin-1
    linea = lineas{i};
    if contains(linea, 'Fecha') && ~contains(linea, 'format')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.Fecha = strtrim(partes{2});
        end
    elseif contains(linea, 'Ventilador')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.Ventilador = strtrim(partes{2});
        end
    end
end

% Línea de encabezados
if lineaEncabezados <= length(lineas)
    encabezados = strsplit(lineas{lineaEncabezados}, '\t');
    encabezados = cellfun(@(s) limpiarNombreVariable(s), encabezados, 'UniformOutput', false);

    % Hacer únicos los nombres duplicados
    encabezados = matlab.lang.makeUniqueStrings(encabezados);

    metadatos.Variables = encabezados;
else
    error('cargarTrends:formato', 'No se encontraron encabezados de datos');
end

% Leer datos
nCols = length(encabezados);
nFilas = length(lineas) - lineaInicioDatos + 1;

% Preasignar
datosCelda = cell(nFilas, nCols);
filasValidas = true(nFilas, 1);

for i = 1:nFilas
    lineaIdx = lineaInicioDatos + i - 1;
    if lineaIdx > length(lineas)
        filasValidas(i) = false;
        continue;
    end

    linea = lineas{lineaIdx};
    if isempty(strtrim(linea))
        filasValidas(i) = false;
        continue;
    end

    partes = strsplit(linea, '\t');

    for j = 1:min(length(partes), nCols)
        valor = strtrim(partes{j});

        % Intentar convertir a número
        if strcmp(valor, '-') || isempty(valor)
            datosCelda{i, j} = NaN;
        else
            numVal = str2double(valor);
            if isnan(numVal)
                datosCelda{i, j} = valor;  % Mantener como texto
            else
                datosCelda{i, j} = numVal;
            end
        end
    end
end

% Filtrar filas vacías
datosCelda = datosCelda(filasValidas, :);

% Crear tabla
datos = cell2table(datosCelda, 'VariableNames', encabezados);

% Convertir columna de tiempo a datetime si existe
if any(contains(encabezados, 'Tiempo'))
    try
        tiempoCol = contains(encabezados, 'Tiempo');
        tiempoStr = datos{:, tiempoCol};
        if iscell(tiempoStr)
            datos.TiempoDatetime = datetime(tiempoStr, 'InputFormat', 'dd/MM/yy HH:mm:ss');
        end
    catch
        % Si falla la conversión, dejar como está
    end
end

metadatos.NumRegistros = height(datos);
end

function nombre = limpiarNombreVariable(nombre)
% Limpia nombre de variable para ser válido en MATLAB
nombre = strtrim(nombre);

% Reemplazar caracteres no válidos
nombre = regexprep(nombre, '[^a-zA-Z0-9_]', '_');

% Asegurar que empiece con letra
if ~isempty(nombre) && ~isletter(nombre(1))
    nombre = ['V_' nombre];
end

% Limitar longitud
if length(nombre) > 63
    nombre = nombre(1:63);
end

if isempty(nombre)
    nombre = 'Variable';
end
end
