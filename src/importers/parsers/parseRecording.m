function data = parseRecording(archivo)
% PARSERECORDING - Parsea archivo de grabación del ventilador SERVO-U
%
% Sintaxis:
%   data = parseRecording(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt de grabación (marcador [REC])
%
% Salida:
%   data - Estructura con:
%          .version          - Versión del formato
%          .tipo             - 'recording'
%          .archivoOrigen    - Ruta al archivo original
%          .fechaProcesado   - Datetime de procesamiento
%          .metadatos        - Struct con info del ventilador y configuración
%          .tabla            - Table con datos de curvas
%          .erroresImportacion - Cell array de errores/advertencias
%
% Formato esperado:
%   Línea 1: [REC]
%   Líneas 2-N: Metadatos (Fecha, Ventilador, Config, etc.)
%   Línea con ==========: Separador
%   Líneas siguientes: Más metadatos de configuración
%   Línea [DATA]: Inicio de datos
%   Línea siguiente: Encabezados de columnas
%   Resto: Datos tabulados (~100 Hz)
%
% Ver también: detectarTipoArchivo, limpiarValores, parseTrends
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar estructura de salida
data = struct();
data.version = '2.0';
data.tipo = 'recording';
data.archivoOrigen = archivo;
data.fechaProcesado = datetime('now');
data.erroresImportacion = {};

% Validar archivo
if ~isfile(archivo)
    error('parseRecording:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido completo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('parseRecording:lectura', 'No se pudo abrir el archivo: %s', archivo);
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
if ~startsWith(lineas{1}, '[REC]')
    error('parseRecording:formato', 'El archivo no tiene marcador [REC]');
end

% =====================================================
% PARSEAR METADATOS
% =====================================================
metadatos = struct();
metadatos.marcador = '[REC]';

% Buscar líneas clave
lineaSeparador = find(startsWith(lineas, '====='), 1);
lineaData = find(strcmp(lineas, '[DATA]'), 1);

if isempty(lineaData)
    error('parseRecording:formato', 'No se encontró marcador [DATA]');
end

% Procesar metadatos antes del separador
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
                metadatos.ventiladorID = valor;
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

% Procesar configuración de ventilación (entre separador y [DATA])
for i = lineaSeparador+1:lineaData-1
    linea = lineas{i};
    if isempty(strtrim(linea))
        continue;
    end

    partes = strsplit(linea, '\t');
    if length(partes) >= 2
        clave = strtrim(partes{1});
        valor = strtrim(partes{2});
        unidad = '';
        if length(partes) >= 3
            unidad = strtrim(partes{3});
        end

        switch clave
            case 'Fecha de grabación'
                metadatos.fechaGrabacion = valor;
            case 'Régimen de ventilación'
                metadatos.modoVentilacion = valor;
            case 'Categ. paciente'
                metadatos.categoriaPaciente = valor;
            case 'Automode'
                metadatos.automode = strcmpi(valor, 'sí') || strcmpi(valor, 'si');
            case 'VNI'
                metadatos.VNI = strcmpi(valor, 'sí') || strcmpi(valor, 'si');
            case 'Volumen corriente'
                metadatos.Vt_config = str2double(valor);
                metadatos.Vt_unidad = unidad;
            case 'PEEP'
                metadatos.PEEP_config = str2double(valor);
            case 'F resp.'
                metadatos.FR_config = str2double(valor);
            case 'Conc. de O2'
                metadatos.FiO2_config = str2double(valor);
            case 'I:E'
                metadatos.IE_config = valor;
            case 'T pausa (%)'
                metadatos.Tpausa_config = str2double(valor);
            case 'Triger de flujo'
                metadatos.triggerFlujo = str2double(valor);
        end
    end
end

data.metadatos = metadatos;

% =====================================================
% PARSEAR DATOS
% =====================================================

% Línea de encabezados
lineaEncabezados = lineaData + 1;
encabezadosRaw = strsplit(lineas{lineaEncabezados}, '\t');

% Estandarizar nombres de columnas
nCols = length(encabezadosRaw);
encabezados = cell(1, nCols);
for i = 1:nCols
    encabezados{i} = estandarizarColumnas(encabezadosRaw{i});
end

% Hacer únicos los nombres duplicados
encabezados = matlab.lang.makeUniqueStrings(encabezados);

% Contar líneas de datos
lineaInicioDatos = lineaEncabezados + 1;
nFilas = length(lineas) - lineaInicioDatos + 1;

% Preallocar arrays
tiempo = cell(nFilas, 1);
fase = cell(nFilas, 1);
presion = nan(nFilas, 1);
flujo = nan(nFilas, 1);
volumen = nan(nFilas, 1);
trigger = cell(nFilas, 1);

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

    try
        % Columna 1: Tiempo (formato HH:MM:SS:mmm)
        if length(partes) >= 1
            tiempo{i} = strtrim(partes{1});
        end

        % Columna 2: Fase de respiración
        if length(partes) >= 2
            fase{i} = strtrim(partes{2});
        end

        % Columna 3: Presión
        if length(partes) >= 3
            presion(i) = limpiarValores(partes{3});
        end

        % Columna 4: Flujo
        if length(partes) >= 4
            flujo(i) = limpiarValores(partes{4});
        end

        % Columna 5: Volumen
        if length(partes) >= 5
            volumen(i) = limpiarValores(partes{5});
        end

        % Columna 6: Trigger (opcional)
        if length(partes) >= 6
            trigger{i} = strtrim(partes{6});
        end

    catch ME
        filasValidas(i) = false;
        erroresLinea{end+1} = sprintf('Línea %d: %s', lineaIdx, ME.message);
    end
end

% Filtrar filas válidas
idx = filasValidas;
tiempo = tiempo(idx);
fase = fase(idx);
presion = presion(idx);
flujo = flujo(idx);
volumen = volumen(idx);
trigger = trigger(idx);

% Convertir tiempo a segundos
tiempoSeg = convertirTiempoASegundos(tiempo);

% Crear tabla
data.tabla = table(tiempoSeg, tiempo, fase, presion, flujo, volumen, ...
    'VariableNames', {'tiempo_s', 'tiempo_str', 'fase', 'presion_cmH2O', 'flujo_Lmin', 'volumen_mL'});

% Añadir trigger si hay datos
if any(~cellfun(@isempty, trigger))
    data.tabla.trigger = trigger;
end

% Guardar errores
data.erroresImportacion = erroresLinea;

% Calcular estadísticas básicas
data.estadisticas = struct();
data.estadisticas.nMuestras = height(data.tabla);
data.estadisticas.duracion_s = max(tiempoSeg) - min(tiempoSeg);
data.estadisticas.frecuenciaMuestreo_Hz = data.estadisticas.nMuestras / data.estadisticas.duracion_s;
data.estadisticas.presion_min = min(presion);
data.estadisticas.presion_max = max(presion);
data.estadisticas.volumen_max = max(volumen);

end


function tiempoSeg = convertirTiempoASegundos(tiempoStr)
% Convierte array de strings de tiempo a segundos
% Formato esperado: HH:MM:SS:mmm

n = length(tiempoStr);
tiempoSeg = zeros(n, 1);

for i = 1:n
    if isempty(tiempoStr{i})
        tiempoSeg(i) = NaN;
        continue;
    end

    partes = strsplit(tiempoStr{i}, ':');

    if length(partes) >= 4
        horas = str2double(partes{1});
        minutos = str2double(partes{2});
        segundos = str2double(partes{3});
        miliseg = str2double(partes{4});
        tiempoSeg(i) = horas * 3600 + minutos * 60 + segundos + miliseg/1000;
    elseif length(partes) >= 3
        horas = str2double(partes{1});
        minutos = str2double(partes{2});
        segundos = str2double(partes{3});
        tiempoSeg(i) = horas * 3600 + minutos * 60 + segundos;
    else
        tiempoSeg(i) = NaN;
    end
end

% Normalizar al inicio
if ~all(isnan(tiempoSeg))
    tiempoSeg = tiempoSeg - min(tiempoSeg(~isnan(tiempoSeg)));
end

end
