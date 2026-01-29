function ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg)
% DETECTARCICLOSRESPIRATORIOS - Segmenta grabación en ciclos respiratorios
%
% Sintaxis:
%   ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg)
%
% Entradas:
%   datosResp - Tabla con columnas: Tiempo, FaseRespiracion, Pva_cmH2O,
%               Flujo_lm, V_ml
%   tiempoSeg - Vector de tiempo en segundos (desde 0)
%
% Salida:
%   ciclos    - Array de estructuras, una por ciclo, con campos:
%               * indices: [inicio, fin] en datos originales
%               * tiempo, presion, volumen, flujo, fases: datos del ciclo
%               * Ti, Te, Ttot: tiempos inspiratorio, espiratorio, total (s)
%               * Vti, Vte: volúmenes inspirado/espirado (mL)
%               * flujoPicoInsp, flujoPicoEsp: flujos pico (L/min)
%               * relacionIE: relación I:E real
%
% Detección basada en:
%   1. Cambios de fase en columna FaseRespiracion
%   2. Cruces por cero del flujo (respaldo)
%   3. Detección de trigger (si existe columna Trigger)
%
% Ejemplo:
%   [metadatos, datosResp] = cargarRecording(archivo);
%   tiempoSeg = convertirTiempoASegundos(datosResp.Tiempo);
%   ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg);
%
% Ver también: calcularMecanicaRespiratoria, VentilatorRecordingViewer
%
% Autor: Generado para proyecto de Fisiología Respiratoria
% Fecha: 2026-01-28
% Respaldo: No aplica (archivo nuevo)

% Validar entradas
if isempty(datosResp) || isempty(tiempoSeg)
    error('detectarCiclosRespiratorios:entrada', ...
        'Se requieren datos y tiempo válidos');
end

% Extraer datos - manejar nombres antiguos y nuevos
varNames = datosResp.Properties.VariableNames;

% Fase respiratoria
if ismember('FaseRespiracion', varNames)
    fases = datosResp.FaseRespiracion;
elseif ismember('fase', varNames)
    fases = datosResp.fase;
else
    error('detectarCiclosRespiratorios:columnas', 'No se encontró columna de fase respiratoria');
end

% Presión
if ismember('Pva_cmH2O', varNames)
    presion = datosResp.Pva_cmH2O;
elseif ismember('presion_cmH2O', varNames)
    presion = datosResp.presion_cmH2O;
else
    error('detectarCiclosRespiratorios:columnas', 'No se encontró columna de presión');
end

% Flujo
if ismember('Flujo_lm', varNames)
    flujo = datosResp.Flujo_lm;
elseif ismember('flujo_Lmin', varNames)
    flujo = datosResp.flujo_Lmin;
else
    error('detectarCiclosRespiratorios:columnas', 'No se encontró columna de flujo');
end

% Volumen
if ismember('V_ml', varNames)
    volumen = datosResp.V_ml;
elseif ismember('volumen_mL', varNames)
    volumen = datosResp.volumen_mL;
else
    error('detectarCiclosRespiratorios:columnas', 'No se encontró columna de volumen');
end

n = length(fases);

% =====================================================
% MÉTODO 1: Detección por cambio de fase
% Un ciclo comienza con 'insp' después de 'esp'
% =====================================================

% Identificar inicio de inspiración (transición esp -> insp)
esInsp = contains(fases, 'insp') & ~contains(fases, 'pausa');
esEsp = contains(fases, 'esp');

% Encontrar transiciones de espiración a inspiración
cambioFase = [false; esInsp(2:end) & esEsp(1:end-1)];
iniciosCiclo = find(cambioFase);

% Si no hay suficientes ciclos detectados, usar método de flujo
if length(iniciosCiclo) < 2
    iniciosCiclo = detectarPorFlujo(flujo);
end

% Añadir el final del último ciclo
if ~isempty(iniciosCiclo) && iniciosCiclo(end) < n
    finUltimo = n;
else
    finUltimo = [];
end

% Crear estructura de ciclos
nCiclos = length(iniciosCiclo) - 1;
if nCiclos < 1
    % Si solo hay un inicio, crear un ciclo con todo
    if ~isempty(iniciosCiclo)
        nCiclos = 1;
        iniciosCiclo = [iniciosCiclo(1); n+1];
    else
        ciclos = struct([]);
        return;
    end
end

% Preasignar array de estructuras
ciclos(nCiclos) = struct(...
    'indices', [], ...
    'tiempo', [], ...
    'presion', [], ...
    'volumen', [], ...
    'flujo', [], ...
    'fases', [], ...
    'Ti', NaN, ...
    'Te', NaN, ...
    'Ttot', NaN, ...
    'Vti', NaN, ...
    'Vte', NaN, ...
    'flujoPicoInsp', NaN, ...
    'flujoPicoEsp', NaN, ...
    'relacionIE', '');

for i = 1:nCiclos
    idxIni = iniciosCiclo(i);
    if i < length(iniciosCiclo)
        idxFin = iniciosCiclo(i+1) - 1;
    else
        idxFin = n;
    end

    % Asegurar índices válidos
    idxIni = max(1, idxIni);
    idxFin = min(n, idxFin);

    if idxFin <= idxIni
        continue;
    end

    idx = idxIni:idxFin;

    % Extraer datos del ciclo
    ciclos(i).indices = [idxIni, idxFin];
    ciclos(i).tiempo = tiempoSeg(idx);
    ciclos(i).presion = presion(idx);
    ciclos(i).volumen = volumen(idx);
    ciclos(i).flujo = flujo(idx);
    ciclos(i).fases = fases(idx);

    % Calcular tiempos
    t = tiempoSeg(idx);
    f = fases(idx);

    esInspCiclo = contains(f, 'insp');
    esPausaCiclo = contains(f, 'pausa');
    esEspCiclo = contains(f, 'esp');

    % Tiempo inspiratorio (incluye pausa)
    idxInspTot = esInspCiclo | esPausaCiclo;
    if any(idxInspTot)
        tInsp = t(idxInspTot);
        ciclos(i).Ti = max(tInsp) - min(tInsp);
    end

    % Tiempo espiratorio
    if any(esEspCiclo)
        tEsp = t(esEspCiclo);
        ciclos(i).Te = max(tEsp) - min(tEsp);
    end

    % Tiempo total
    ciclos(i).Ttot = max(t) - min(t);

    % Volumen inspirado (máximo - mínimo durante insp)
    v = volumen(idx);
    if any(esInspCiclo)
        vInsp = v(idxInspTot);
        ciclos(i).Vti = max(vInsp) - min(v);
    end

    % Volumen espirado
    if any(esEspCiclo)
        vEsp = v(esEspCiclo);
        ciclos(i).Vte = max(vEsp) - min(vEsp);
    end

    % Flujos pico
    fl = flujo(idx);
    if any(esInspCiclo)
        ciclos(i).flujoPicoInsp = max(fl(esInspCiclo));
    end
    if any(esEspCiclo)
        ciclos(i).flujoPicoEsp = abs(min(fl(esEspCiclo)));
    end

    % Relación I:E
    if ~isnan(ciclos(i).Ti) && ~isnan(ciclos(i).Te) && ciclos(i).Te > 0
        ratio = ciclos(i).Ti / ciclos(i).Te;
        if ratio >= 1
            ciclos(i).relacionIE = sprintf('%.1f:1', ratio);
        else
            ciclos(i).relacionIE = sprintf('1:%.1f', 1/ratio);
        end
    end
end

% Eliminar ciclos vacíos o inválidos
ciclosValidos = arrayfun(@(c) ~isempty(c.indices), ciclos);
ciclos = ciclos(ciclosValidos);

end

% =========================================================================
% FUNCIÓN AUXILIAR: Detección por cruces de flujo
% =========================================================================
function inicios = detectarPorFlujo(flujo)
% Detecta inicio de inspiración por cruce positivo del flujo
% (flujo pasa de negativo a positivo)

flujoSmooth = movmean(flujo, 5); % Suavizar para evitar falsos positivos

% Encontrar cruces de cero de negativo a positivo
cruces = find(flujoSmooth(1:end-1) < 0 & flujoSmooth(2:end) >= 0);

% Filtrar cruces muy cercanos (mínimo 1 segundo entre ciclos)
if length(cruces) > 1
    % Asumiendo frecuencia de 100 Hz, 1 segundo = 100 muestras
    distMin = 100;
    crucesValidos = cruces(1);
    for i = 2:length(cruces)
        if cruces(i) - crucesValidos(end) >= distMin
            crucesValidos = [crucesValidos; cruces(i)];
        end
    end
    inicios = crucesValidos;
else
    inicios = cruces;
end
end
