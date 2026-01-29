function data = parseRecruitment(archivo)
% PARSERECRUITMENT - Parsea archivo de maniobra de reclutamiento SERVO-U
%
% Sintaxis:
%   data = parseRecruitment(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt de reclutamiento (marcador [RECRUITMENT])
%
% Salida:
%   data - Estructura con:
%          .version          - Versión del formato
%          .tipo             - 'recruitment'
%          .archivoOrigen    - Ruta al archivo original
%          .fechaProcesado   - Datetime de procesamiento
%          .metadatos        - Struct con info de la maniobra
%          .tabla            - Table con datos por paso
%          .analisis         - Struct con análisis (PEEP óptimo, etc.)
%          .erroresImportacion - Cell array de errores
%
% Ver también: parseBreathTrends, parseTrends
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar estructura de salida
data = struct();
data.version = '2.0';
data.tipo = 'recruitment';
data.archivoOrigen = archivo;
data.fechaProcesado = datetime('now');
data.erroresImportacion = {};

% Validar archivo
if ~isfile(archivo)
    error('parseRecruitment:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido completo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('parseRecruitment:lectura', 'No se pudo abrir el archivo: %s', archivo);
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
    error('parseRecruitment:formato', 'No se encontró marcador [DATA]');
end

% Procesar metadatos de cabecera
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

% Procesar info de maniobra
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

% Preallocar
tiempo = cell(nFilas, 1);
Cdyn = nan(nFilas, 1);
Pei = nan(nFilas, 1);
PEEP = nan(nFilas, 1);
Vce = nan(nFilas, 1);
Vci = nan(nFilas, 1);
Pactividad = nan(nFilas, 1);
IE = cell(nFilas, 1);
FR = nan(nFilas, 1);

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

    % Verificar línea vacía
    tieneValor = false;

    if length(partes) >= 1
        tiempo{i} = strtrim(partes{1});
        if ~isempty(tiempo{i})
            tieneValor = true;
        end
    end

    if length(partes) >= 2
        Cdyn(i) = limpiarValores(partes{2});
        if ~isnan(Cdyn(i)), tieneValor = true; end
    end

    if length(partes) >= 3
        Pei(i) = limpiarValores(partes{3});
    end

    if length(partes) >= 4
        PEEP(i) = limpiarValores(partes{4});
    end

    if length(partes) >= 5
        Vce(i) = limpiarValores(partes{5});
    end

    if length(partes) >= 6
        Vci(i) = limpiarValores(partes{6});
    end

    if length(partes) >= 7
        Pactividad(i) = limpiarValores(partes{7});
    end

    if length(partes) >= 8
        IE{i} = strtrim(partes{8});
    end

    if length(partes) >= 9
        FR(i) = limpiarValores(partes{9});
    end

    if ~tieneValor
        filasValidas(i) = false;
    end
end

% Filtrar filas válidas
idx = filasValidas;
tiempo = tiempo(idx);
Cdyn = Cdyn(idx);
Pei = Pei(idx);
PEEP = PEEP(idx);
Vce = Vce(idx);
Vci = Vci(idx);
Pactividad = Pactividad(idx);
IE = IE(idx);
FR = FR(idx);

% Crear tabla
data.tabla = table(tiempo, Cdyn, Pei, PEEP, Vce, Vci, Pactividad, IE, FR, ...
    'VariableNames', {'tiempo', 'Cdyn_mLcmH2O', 'Pei_cmH2O', 'PEEP_cmH2O', ...
    'Vce_mL', 'Vci_mL', 'Pactividad_cmH2O', 'IE', 'FR'});

% =====================================================
% ANÁLISIS DE RECLUTAMIENTO
% =====================================================
analisis = struct();

% Filtrar valores válidos de Cdyn y PEEP para análisis
idxValido = ~isnan(Cdyn) & ~isnan(PEEP);

if any(idxValido)
    CdynValido = Cdyn(idxValido);
    PEEPValido = PEEP(idxValido);

    % Estadísticas básicas
    analisis.PEEP_min = min(PEEPValido);
    analisis.PEEP_max = max(PEEPValido);
    analisis.Cdyn_min = min(CdynValido);
    analisis.Cdyn_max = max(CdynValido);

    % PEEP óptimo (donde Cdyn es máxima)
    [~, idxMax] = max(CdynValido);
    analisis.PEEP_optimo = PEEPValido(idxMax);
    analisis.Cdyn_en_PEEP_optimo = CdynValido(idxMax);

    % Detectar pasos de PEEP (cambios significativos)
    difPEEP = diff(PEEPValido);
    cambiosPEEP = find(abs(difPEEP) > 2);  % Cambios > 2 cmH2O
    analisis.nPasos = length(cambiosPEEP) + 1;

    % Calcular Cdyn promedio por nivel de PEEP
    nivelesUnicos = unique(round(PEEPValido));
    analisis.curvaResumen = struct();
    analisis.curvaResumen.PEEP = nivelesUnicos;
    analisis.curvaResumen.Cdyn_media = zeros(size(nivelesUnicos));
    analisis.curvaResumen.Cdyn_std = zeros(size(nivelesUnicos));

    for j = 1:length(nivelesUnicos)
        idxNivel = abs(PEEPValido - nivelesUnicos(j)) < 1.5;
        analisis.curvaResumen.Cdyn_media(j) = mean(CdynValido(idxNivel));
        analisis.curvaResumen.Cdyn_std(j) = std(CdynValido(idxNivel));
    end
else
    analisis.PEEP_optimo = NaN;
    analisis.Cdyn_max = NaN;
    analisis.nPasos = 0;
end

data.analisis = analisis;

% Estadísticas generales
data.estadisticas = struct();
data.estadisticas.nRegistros = height(data.tabla);
data.estadisticas.duracion = '';
if ~isempty(metadatos.horaInicio) && ~isempty(metadatos.horaFinal)
    data.estadisticas.duracion = sprintf('%s - %s', metadatos.horaInicio, metadatos.horaFinal);
end

end
