function data = parseTrends(archivo)
% PARSETRENDS - Parsea archivo de tendencias del ventilador SERVO-U
%
% Sintaxis:
%   data = parseTrends(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt de tendencias (marcador [TRE])
%
% Salida:
%   data - Estructura con:
%          .version          - Versión del formato
%          .tipo             - 'trends'
%          .archivoOrigen    - Ruta al archivo original
%          .fechaProcesado   - Datetime de procesamiento
%          .metadatos        - Struct con info del ventilador
%          .tabla            - Table con datos de tendencias
%          .erroresImportacion - Cell array de errores/advertencias
%
% Formato esperado:
%   Línea 1: [TRE]
%   Líneas 2-N: Metadatos (Fecha, Ventilador, etc.)
%   Línea con ==========: Separador
%   Línea siguiente: Encabezados (~40 columnas)
%   Resto: Datos tabulados (1 registro/minuto aprox)
%
% Ver también: detectarTipoArchivo, parseRecording, parseBreathTrends
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar estructura de salida
data = struct();
data.version = '2.0';
data.tipo = 'trends';
data.archivoOrigen = archivo;
data.fechaProcesado = datetime('now');
data.erroresImportacion = {};

% Validar archivo
if ~isfile(archivo)
    error('parseTrends:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido completo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('parseTrends:lectura', 'No se pudo abrir el archivo: %s', archivo);
end
contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lineas = contenido{1};

% Eliminar BOM de primera línea si existe
if ~isempty(lineas) && ~isempty(lineas{1})
    lineas{1} = regexprep(lineas{1}, '^\xEF\xBB\xBF', '');
    if lineas{1}(1) == 65279
        lineas{1} = lineas{1}(2:end);
    end
end

% Verificar marcador
if ~startsWith(lineas{1}, '[TRE]')
    error('parseTrends:formato', 'El archivo no tiene marcador [TRE]');
end

% =====================================================
% PARSEAR METADATOS
% =====================================================
metadatos = struct();
metadatos.marcador = '[TRE]';

% Buscar línea separadora
lineaSeparador = find(startsWith(lineas, '====='), 1);

if isempty(lineaSeparador)
    error('parseTrends:formato', 'No se encontró separador =====');
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
            case 'Versión'
                metadatos.softwareVersion = valor;
            case 'Date format'
                metadatos.formatoFecha = valor;
            case 'Language setting'
                metadatos.idioma = valor;
            case 'Decimal separator'
                metadatos.separadorDecimal = valor;
        end
    end
end

data.metadatos = metadatos;

% =====================================================
% PARSEAR DATOS
% =====================================================

% Línea de encabezados (inmediatamente después del separador)
lineaEncabezados = lineaSeparador + 1;
encabezadosRaw = strsplit(lineas{lineaEncabezados}, '\t');

% Estandarizar nombres de columnas
nCols = length(encabezadosRaw);
encabezados = cell(1, nCols);
encabezadosOriginales = cell(1, nCols);

for i = 1:nCols
    encabezadosOriginales{i} = strtrim(encabezadosRaw{i});
    encabezados{i} = estandarizarColumnas(encabezadosRaw{i});
end

% Hacer únicos los nombres duplicados
encabezados = matlab.lang.makeUniqueStrings(encabezados);

% Guardar mapeo de nombres
data.mapeoColumnas = containers.Map(encabezados, encabezadosOriginales);

% Contar líneas de datos
lineaInicioDatos = lineaEncabezados + 1;
nFilas = length(lineas) - lineaInicioDatos + 1;

% Preallocar cell array para todos los datos
datosCelda = cell(nFilas, nCols);
filasValidas = true(nFilas, 1);
erroresLinea = {};

% Parsear cada línea de datos
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

        % Primera columna es siempre tiempo (texto)
        if j == 1
            datosCelda{i, j} = valor;
        else
            % Resto de columnas: intentar convertir a número
            [valorNum, ~] = limpiarValores(valor);
            if isnan(valorNum) && ~isempty(valor) && ~strcmp(valor, '-') && ~strcmp(valor, '***')
                % Es texto (ej: modo de ventilación)
                datosCelda{i, j} = valor;
            else
                datosCelda{i, j} = valorNum;
            end
        end
    end
end

% Filtrar filas válidas
datosCelda = datosCelda(filasValidas, :);
nFilasValidas = sum(filasValidas);

% Convertir a tabla
data.tabla = cell2table(datosCelda, 'VariableNames', encabezados);

% Intentar convertir primera columna (tiempo) a datetime
if nFilasValidas > 0
    try
        tiempoStr = data.tabla{:, 1};
        if iscell(tiempoStr)
            % Formato típico: "28/01/26 17:00:06"
            tiempoDatetime = datetime(tiempoStr, 'InputFormat', 'dd/MM/yy HH:mm:ss');
            data.tabla.tiempo_datetime = tiempoDatetime;
        end
    catch
        % Si falla, dejar como está
        data.erroresImportacion{end+1} = 'No se pudo convertir tiempo a datetime';
    end
end

% Guardar errores
data.erroresImportacion = [data.erroresImportacion, erroresLinea];

% Calcular estadísticas básicas
data.estadisticas = struct();
data.estadisticas.nRegistros = height(data.tabla);
data.estadisticas.nVariables = width(data.tabla);

% Identificar columnas numéricas para estadísticas
colsNumericas = {};
for i = 1:width(data.tabla)
    col = data.tabla{:, i};
    if isnumeric(col) || (iscell(col) && all(cellfun(@isnumeric, col)))
        colsNumericas{end+1} = encabezados{i};
    end
end
data.estadisticas.columnasNumericas = colsNumericas;

end
