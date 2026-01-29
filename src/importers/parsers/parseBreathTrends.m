function data = parseBreathTrends(archivo)
% PARSEBREATHTRENDS - Parsea archivo de BreathTrends del ventilador SERVO-U
%
% Sintaxis:
%   data = parseBreathTrends(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt de BreathTrends (marcador [RECRUITMENT] pero es por respiración)
%
% Salida:
%   data - Estructura con datos normalizados
%
% BreathTrends son datos por respiración individual (más detallados que Trends).
% Tienen el mismo formato que Recruitment pero con intervalos más largos.
%
% Ver también: parseTrends, parseRecruitment
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar estructura de salida
data = struct();
data.version = '2.0';
data.tipo = 'breathtrends';
data.archivoOrigen = archivo;
data.fechaProcesado = datetime('now');
data.erroresImportacion = {};

% Validar archivo
if ~isfile(archivo)
    error('parseBreathTrends:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido completo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('parseBreathTrends:lectura', 'No se pudo abrir el archivo: %s', archivo);
end
contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lineas = contenido{1};

% Eliminar BOM
if ~isempty(lineas) && ~isempty(lineas{1})
    lineas{1} = regexprep(lineas{1}, '^\xEF\xBB\xBF', '');
    if lineas{1}(1) == 65279
        lineas{1} = lineas{1}(2:end);
    end
end

% =====================================================
% PARSEAR METADATOS
% =====================================================
metadatos = struct();
metadatos.marcador = '[RECRUITMENT]';

lineaSeparador = find(startsWith(lineas, '====='), 1);
lineaData = find(strcmp(lineas, '[DATA]'), 1);

if isempty(lineaData)
    error('parseBreathTrends:formato', 'No se encontró marcador [DATA]');
end

% Procesar metadatos
for i = 2:lineaSeparador-1
    linea = lineas{i};
    partes = strsplit(linea, '\t');

    if length(partes) >= 2
        clave = strtrim(partes{1});
        valor = strtrim(partes{2});

        switch clave
            case 'Fecha'
                metadatos.fechaArchivo = valor;
            case 'Archivo'
                metadatos.nombreArchivo = valor;
            case 'Ventilador'
                metadatos.ventiladorID = strtrim(valor);
            case 'Sistema'
                metadatos.sistemaVersion = valor;
        end
    end
end

% Procesar info de intervalo (entre separador y [DATA])
for i = lineaSeparador+1:lineaData-1
    linea = lineas{i};
    if isempty(strtrim(linea))
        continue;
    end

    partes = strsplit(linea, '\t');
    if length(partes) >= 2
        clave = strtrim(partes{1});
        valor = strtrim(partes{2});

        switch clave
            case 'Hora inicio maniobra reclutamiento'
                metadatos.horaInicio = valor;
            case 'Hora final maniobra reclutamiento'
                metadatos.horaFinal = valor;
            case 'Intervalo de tiempo'
                metadatos.intervalo = valor;
        end
    end
end

data.metadatos = metadatos;

% =====================================================
% PARSEAR DATOS
% =====================================================

% Encabezados
lineaEncabezados = lineaData + 1;
encabezadosRaw = strsplit(lineas{lineaEncabezados}, '\t');

nCols = length(encabezadosRaw);
encabezados = cell(1, nCols);
for i = 1:nCols
    encabezados{i} = estandarizarColumnas(encabezadosRaw{i});
end
encabezados = matlab.lang.makeUniqueStrings(encabezados);

% Datos
lineaInicioDatos = lineaEncabezados + 1;
nFilas = length(lineas) - lineaInicioDatos + 1;

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

    % Verificar si es línea vacía de datos
    tieneAlgunValor = false;
    for j = 1:min(length(partes), nCols)
        valor = strtrim(partes{j});
        if j == 1
            datosCelda{i, j} = valor;  % Tiempo
            if ~isempty(valor)
                tieneAlgunValor = true;
            end
        else
            [valorNum, ~] = limpiarValores(valor);
            datosCelda{i, j} = valorNum;
            if ~isnan(valorNum)
                tieneAlgunValor = true;
            end
        end
    end

    if ~tieneAlgunValor
        filasValidas(i) = false;
    end
end

% Filtrar
datosCelda = datosCelda(filasValidas, :);

% Crear tabla
data.tabla = cell2table(datosCelda, 'VariableNames', encabezados);

% Convertir tiempo a datetime
if height(data.tabla) > 0
    try
        tiempoStr = data.tabla{:, 1};
        if iscell(tiempoStr)
            % Formato: "16:58:22" (solo hora)
            tiempoDatetime = datetime(tiempoStr, 'InputFormat', 'HH:mm:ss');
            data.tabla.tiempo_datetime = tiempoDatetime;
        end
    catch
        data.erroresImportacion{end+1} = 'No se pudo convertir tiempo a datetime';
    end
end

% Estadísticas
data.estadisticas = struct();
data.estadisticas.nRegistros = height(data.tabla);
data.estadisticas.nVariables = width(data.tabla);

end
