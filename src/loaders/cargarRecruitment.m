function [metadatos, datos] = cargarRecruitment(archivo)
% CARGARRECRUITMENT - Carga archivo de maniobra de reclutamiento SERVO-U
%
% Sintaxis:
%   [metadatos, datos] = cargarRecruitment(archivo)
%
% Entrada:
%   archivo - Ruta al archivo de Recruitment (.txt)
%
% Salidas:
%   metadatos - Estructura con información de la maniobra
%   datos     - Tabla con datos de compliance vs PEEP
%
% Ejemplo:
%   [meta, recr] = cargarRecruitment('1769619894247.txt');
%   plot(recr.PEEP, recr.Cdyn);
%   xlabel('PEEP (cmH2O)'); ylabel('Cdyn (mL/cmH2O)');
%
% Ver también: cargarTrends, VentilatorRecordingViewer
%
% Autor: Generado para proyecto de Fisiología Respiratoria
% Fecha: 2026-01-28

% Validar archivo
if ~isfile(archivo)
    error('cargarRecruitment:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido
fid = fopen(archivo, 'r', 'n', 'UTF-8');
contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lineas = contenido{1};

% Inicializar metadatos
metadatos = struct();
metadatos.Archivo = archivo;
metadatos.Tipo = 'Recruitment';

% Encontrar línea de separación
lineaSep = find(startsWith(lineas, '====='));
if isempty(lineaSep)
    error('cargarRecruitment:formato', 'Formato de archivo no reconocido');
end

% Procesar metadatos
for i = 1:lineaSep-1
    linea = lineas{i};
    if contains(linea, 'Fecha') && ~contains(linea, 'format')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.Fecha = strtrim(partes{2});
        end
    elseif contains(linea, 'Hora inicio maniobra')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.HoraInicio = strtrim(partes{2});
        end
    elseif contains(linea, 'Hora final maniobra')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.HoraFinal = strtrim(partes{2});
        end
    elseif contains(linea, 'Intervalo de tiempo')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2
            metadatos.Intervalo = strtrim(partes{2});
        end
    end
end

% Encontrar línea [DATA]
lineaData = find(startsWith(lineas, '[DATA]'));
if isempty(lineaData)
    lineaData = lineaSep;
end

% Línea de encabezados
encabezados = strsplit(lineas{lineaData + 1}, '\t');
encabezados = cellfun(@(s) limpiarNombreVariable(s), encabezados, 'UniformOutput', false);
metadatos.Variables = encabezados;

% Leer datos
nCols = length(encabezados);
nFilas = length(lineas) - lineaData - 1;

% Preasignar arrays para datos numéricos principales
tiempo = cell(nFilas, 1);
Cdyn = nan(nFilas, 1);
Pei = nan(nFilas, 1);
PEEP = nan(nFilas, 1);
Vce = nan(nFilas, 1);
Vci = nan(nFilas, 1);
Fresp = nan(nFilas, 1);
IE = cell(nFilas, 1);

filasValidas = false(nFilas, 1);

for i = 1:nFilas
    lineaIdx = lineaData + 1 + i;
    if lineaIdx > length(lineas)
        continue;
    end

    linea = lineas{lineaIdx};
    if isempty(strtrim(linea))
        continue;
    end

    partes = strsplit(linea, '\t');

    if length(partes) >= 1
        tiempo{i} = strtrim(partes{1});
        filasValidas(i) = ~isempty(tiempo{i});
    end

    if length(partes) >= 2
        val = limpiarValorNumerico(partes{2});
        if ~isnan(val), Cdyn(i) = val; end
    end

    if length(partes) >= 3
        val = limpiarValorNumerico(partes{3});
        if ~isnan(val), Pei(i) = val; end
    end

    if length(partes) >= 4
        val = limpiarValorNumerico(partes{4});
        if ~isnan(val), PEEP(i) = val; end
    end

    if length(partes) >= 5
        val = limpiarValorNumerico(partes{5});
        if ~isnan(val), Vce(i) = val; end
    end

    if length(partes) >= 6
        val = limpiarValorNumerico(partes{6});
        if ~isnan(val), Vci(i) = val; end
    end

    if length(partes) >= 8
        IE{i} = strtrim(partes{8});
    end

    if length(partes) >= 9
        val = limpiarValorNumerico(partes{9});
        if ~isnan(val), Fresp(i) = val; end
    end
end

% Crear tabla con datos válidos
idx = filasValidas;
datos = table(tiempo(idx), Cdyn(idx), Pei(idx), PEEP(idx), ...
    Vce(idx), Vci(idx), IE(idx), Fresp(idx), ...
    'VariableNames', {'Tiempo', 'Cdyn_mL_cmH2O', 'Pei_cmH2O', ...
    'PEEP_cmH2O', 'Vce_mL', 'Vci_mL', ...
    'IE', 'Fresp_rpm'});

% Calcular estadísticas de la maniobra
metadatos.PEEPmin = min(datos.PEEP_cmH2O);
metadatos.PEEPmax = max(datos.PEEP_cmH2O);
metadatos.CdynMax = max(datos.Cdyn_mL_cmH2O);

% Encontrar PEEP óptimo (donde Cdyn es máxima)
[~, idxMax] = max(datos.Cdyn_mL_cmH2O);
if ~isempty(idxMax)
    metadatos.PEEPoptimo = datos.PEEP_cmH2O(idxMax);
end

metadatos.NumRegistros = height(datos);
end

function nombre = limpiarNombreVariable(nombre)
nombre = strtrim(nombre);
nombre = regexprep(nombre, '[^a-zA-Z0-9_]', '_');
if ~isempty(nombre) && ~isletter(nombre(1))
    nombre = ['V_' nombre];
end
if length(nombre) > 63
    nombre = nombre(1:63);
end
if isempty(nombre)
    nombre = 'Variable';
end
end

function val = limpiarValorNumerico(str)
str = strtrim(str);
% Eliminar marcadores como #, *, espacios
str = regexprep(str, '[#*]', '');
str = strtrim(str);

if isempty(str) || strcmp(str, '-') || strcmp(str, '***')
    val = NaN;
else
    val = str2double(str);
end
end
