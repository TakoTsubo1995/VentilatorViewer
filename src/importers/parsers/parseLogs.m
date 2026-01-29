function data = parseLogs(archivo)
% PARSELOGS - Parsea archivo de logs del ventilador SERVO-U
%
% Sintaxis:
%   data = parseLogs(archivo)
%
% Entrada:
%   archivo - Ruta al archivo .txt de logs (marcador [LOG])
%
% Salida:
%   data - Estructura con:
%          .version          - Versión del formato
%          .tipo             - 'logs'
%          .archivoOrigen    - Ruta al archivo original
%          .fechaProcesado   - Datetime de procesamiento
%          .metadatos        - Struct con info del ventilador
%          .tabla            - Table con eventos
%          .resumen          - Struct con conteo por categoría
%          .erroresImportacion - Cell array de errores
%
% Categorías de eventos:
%   - Alarma: alertas del sistema (presión alta, desconexión, etc.)
%   - Cambio del parámetro: modificaciones de configuración
%   - Cambio del límite de alarma: ajustes de límites
%   - Funciones: acciones del sistema (silenciar, reclutamiento, etc.)
%
% Ver también: parseRecording, parseTrends
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Inicializar estructura de salida
data = struct();
data.version = '2.0';
data.tipo = 'logs';
data.archivoOrigen = archivo;
data.fechaProcesado = datetime('now');
data.erroresImportacion = {};

% Validar archivo
if ~isfile(archivo)
    error('parseLogs:archivo', 'No se encontró el archivo: %s', archivo);
end

% Leer contenido completo
fid = fopen(archivo, 'r', 'n', 'UTF-8');
if fid == -1
    error('parseLogs:lectura', 'No se pudo abrir el archivo: %s', archivo);
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

% Verificar marcador
if ~startsWith(lineas{1}, '[LOG]')
    error('parseLogs:formato', 'El archivo no tiene marcador [LOG]');
end

% =====================================================
% PARSEAR METADATOS
% =====================================================
metadatos = struct();
metadatos.marcador = '[LOG]';

lineaSeparador = find(startsWith(lineas, '====='), 1);

if isempty(lineaSeparador)
    error('parseLogs:formato', 'No se encontró separador =====');
end

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

data.metadatos = metadatos;

% =====================================================
% PARSEAR EVENTOS
% =====================================================

lineaInicioDatos = lineaSeparador + 1;
nFilas = length(lineas) - lineaInicioDatos + 1;

% Preallocar
tiempoStr = cell(nFilas, 1);
fechaStr = cell(nFilas, 1);
categoria = cell(nFilas, 1);
mensaje = cell(nFilas, 1);
severidad = cell(nFilas, 1);

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

    % Formato típico: "17:24:31, 28/01/26	Alarma	Alarma: Frecuencia respiratoria baja"
    partes = strsplit(linea, '\t');

    if length(partes) >= 3
        % Primera parte: tiempo y fecha
        tiempoFecha = strtrim(partes{1});
        partesTimeFecha = strsplit(tiempoFecha, ', ');
        if length(partesTimeFecha) >= 2
            tiempoStr{i} = strtrim(partesTimeFecha{1});
            fechaStr{i} = strtrim(partesTimeFecha{2});
        else
            tiempoStr{i} = tiempoFecha;
            fechaStr{i} = '';
        end

        % Segunda parte: categoría
        categoria{i} = strtrim(partes{2});

        % Tercera parte: mensaje
        mensaje{i} = limpiarMensajeLog(strtrim(partes{3}));

        % Determinar severidad según categoría y contenido
        severidad{i} = clasificarSeveridad(categoria{i}, mensaje{i});
    else
        filasValidas(i) = false;
    end
end

% Filtrar filas válidas
idx = filasValidas;
tiempoStr = tiempoStr(idx);
fechaStr = fechaStr(idx);
categoria = categoria(idx);
mensaje = mensaje(idx);
severidad = severidad(idx);

% Crear tabla
data.tabla = table(tiempoStr, fechaStr, categoria, mensaje, severidad, ...
    'VariableNames', {'tiempo', 'fecha', 'categoria', 'mensaje', 'severidad'});

% Intentar crear datetime
if height(data.tabla) > 0
    try
        tiempoCompleto = strcat(fechaStr, {' '}, tiempoStr);
        tiempoDatetime = datetime(tiempoCompleto, 'InputFormat', 'dd/MM/yy HH:mm:ss');
        data.tabla.tiempo_datetime = tiempoDatetime;
    catch
        data.erroresImportacion{end+1} = 'No se pudo convertir tiempo a datetime';
    end
end

% =====================================================
% RESUMEN DE EVENTOS
% =====================================================
resumen = struct();

if height(data.tabla) > 0
    % Conteo por categoría
    categorias = data.tabla.categoria;
    categoriasUnicas = unique(categorias);

    resumen.porCategoria = struct();
    for j = 1:length(categoriasUnicas)
        cat = categoriasUnicas{j};
        catLimpia = regexprep(cat, '[^a-zA-Z0-9]', '_');
        resumen.porCategoria.(catLimpia) = sum(strcmp(categorias, cat));
    end

    % Conteo por severidad
    severidades = data.tabla.severidad;
    resumen.porSeveridad = struct();
    resumen.porSeveridad.critica = sum(strcmp(severidades, 'critica'));
    resumen.porSeveridad.advertencia = sum(strcmp(severidades, 'advertencia'));
    resumen.porSeveridad.info = sum(strcmp(severidades, 'info'));

    % Alarmas más frecuentes
    idxAlarmas = strcmp(categorias, 'Alarma');
    if any(idxAlarmas)
        alarmas = mensaje(idxAlarmas);
        [alarmasUnicas, ~, ic] = unique(alarmas);
        conteoAlarmas = accumarray(ic, 1);
        [~, ordenFrec] = sort(conteoAlarmas, 'descend');

        resumen.alarmasFrecuentes = struct();
        for j = 1:min(5, length(ordenFrec))
            resumen.alarmasFrecuentes(j).mensaje = alarmasUnicas{ordenFrec(j)};
            resumen.alarmasFrecuentes(j).conteo = conteoAlarmas(ordenFrec(j));
        end
    end
end

data.resumen = resumen;

% Estadísticas
data.estadisticas = struct();
data.estadisticas.nEventos = height(data.tabla);
data.estadisticas.nCategorias = length(categoriasUnicas);

end


function mensajeLimpio = limpiarMensajeLog(mensaje)
% Limpia mensaje de log eliminando etiquetas HTML

mensajeLimpio = mensaje;

% Eliminar etiquetas HTML como <sub>, </sub>
mensajeLimpio = regexprep(mensajeLimpio, '<[^>]+>', '');

% Normalizar espacios
mensajeLimpio = regexprep(mensajeLimpio, '\s+', ' ');
mensajeLimpio = strtrim(mensajeLimpio);

end


function sev = clasificarSeveridad(categoria, mensaje)
% Clasifica la severidad del evento

sev = 'info';  % Por defecto

if strcmp(categoria, 'Alarma')
    % Alarmas críticas
    if contains(mensaje, 'desconect', 'IgnoreCase', true) || ...
            contains(mensaje, 'alta', 'IgnoreCase', true) || ...
            contains(mensaje, 'Circuito de paciente', 'IgnoreCase', true)
        sev = 'critica';
    else
        sev = 'advertencia';
    end
elseif contains(categoria, 'Cambio del parámetro')
    sev = 'info';
elseif contains(categoria, 'Cambio del límite')
    sev = 'info';
elseif strcmp(categoria, 'Funciones')
    if contains(mensaje, 'RECLUT', 'IgnoreCase', true)
        sev = 'info';
    elseif contains(mensaje, 'silenci', 'IgnoreCase', true)
        sev = 'info';
    end
end

end
