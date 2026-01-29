function tests = test_mecanicaRespiratoria
% TEST_MECANICAORESPIRATORIA - Tests formales para módulos de mecánica respiratoria
%
% Ejecutar con: runtests('test_mecanicaRespiratoria')
% O ejecutar manualmente: test_mecanicaRespiratoria.validacionManual()
%
% Incluye:
%   - Tests unitarios automáticos (para runtests)
%   - Validación manual contra datos del ventilador
%
% Ver también: calcularMecanicaRespiratoria, detectarCiclosRespiratorios

tests = functiontests(localfunctions);
end

% =========================================================================
% TESTS UNITARIOS AUTOMÁTICOS
% =========================================================================

function test_complianceEstaticaCalculoBasico(testCase)
% Test: Compliance estática con valores conocidos
% Cst = Vt / (Pplateau - PEEP)
% Datos: Vt=400mL, Pplateau=25cmH2O, PEEP=8cmH2O
% Esperado: Cst = 400 / (25-8) = 23.53 mL/cmH2O

% Crear ciclo simulado
ciclo = crearCicloSimulado(400, 25, 8, 30);
metadatos = struct('PEEP', 8);

mecanica = calcularMecanicaRespiratoria(ciclo, metadatos);

verifyEqual(testCase, mecanica.Cst(1), 23.53, 'RelTol', 0.05, ...
    'Compliance estática debe ser aproximadamente 23.53 mL/cmH2O');
end

function test_drivingPressure(testCase)
% Test: Driving Pressure
% ΔP = Pplateau - PEEP
% Esperado: 25 - 8 = 17 cmH2O

ciclo = crearCicloSimulado(400, 25, 8, 30);
metadatos = struct('PEEP', 8);

mecanica = calcularMecanicaRespiratoria(ciclo, metadatos);

verifyEqual(testCase, mecanica.DrivingP(1), 17, 'AbsTol', 1, ...
    'Driving Pressure debe ser 17 cmH2O');
end

function test_complianceDinamica(testCase)
% Test: Compliance dinámica
% Cdyn = Vt / (Ppico - PEEP)
% Con Ppico=28, esperado: 400 / (28-8) = 20 mL/cmH2O

ciclo = crearCicloSimulado(400, 25, 8, 28);
metadatos = struct('PEEP', 8);

mecanica = calcularMecanicaRespiratoria(ciclo, metadatos);

verifyEqual(testCase, mecanica.Cdyn(1), 20, 'RelTol', 0.1, ...
    'Compliance dinámica debe ser aproximadamente 20 mL/cmH2O');
end

function test_deteccionCiclosBasica(testCase)
% Test: Detección de ciclos respiratorios
% Crear datos con 3 ciclos claros - primer ciclo puede no detectarse
% porque requiere transición esp->insp

[datosResp, tiempoSeg] = crearDatosRespiratoriosSimulados(3);

ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg);

% Al menos 1 ciclo debe detectarse (2 transiciones = 1 ciclo completo)
verifyGreaterThanOrEqual(testCase, length(ciclos), 1, ...
    'Debe detectar al menos 1 ciclo completo');
end

function test_analizarLoopPV(testCase)
% Test: Análisis de loop P-V
% Crear loop cuadrado de área conocida
% Área = 100 × 10 = 1000 unidades

presion = [10, 20, 20, 10, 10];
volumen = [0, 0, 100, 100, 0];

res = analizarLoop(presion, volumen, 'Presion', 'Volumen');

% El área del cuadrado es 100*10 = 1000
verifyEqual(testCase, res.area, 1000, 'AbsTol', 10, ...
    'Área del loop cuadrado debe ser 1000');
end

function test_analizarLoopEntradaInvalida(testCase)
% Test: Manejo de entrada inválida

verifyError(testCase, @() analizarLoop([1,2,3], [1,2], 'X', 'Y'), ...
    'analizarLoop:dimension', ...
    'Debe lanzar error si vectores tienen diferente longitud');
end

% =========================================================================
% VALIDACIÓN MANUAL
% =========================================================================

function validacionManual()
% Ejecutar: test_mecanicaRespiratoria.validacionManual()
% Compara cálculos propios contra valores del ventilador

fprintf('\n========================================\n');
fprintf('VALIDACIÓN MANUAL - Mecánica Respiratoria\n');
fprintf('========================================\n\n');

% Buscar archivos de recording
baseDir = fileparts(mfilename('fullpath'));
recDir = fullfile(baseDir, '..', 'ventilatorData', 'recordings');
trendDir = fullfile(baseDir, '..', 'ventilatorData', 'trends');

if ~isfolder(recDir)
    fprintf('ERROR: No se encontró carpeta de recordings en:\n%s\n', recDir);
    return;
end

files = dir(fullfile(recDir, '*.txt'));
if isempty(files)
    fprintf('ERROR: No hay archivos de recording disponibles\n');
    return;
end

fprintf('Archivos de recording encontrados: %d\n\n', length(files));

% Cargar primer archivo
archivoRec = fullfile(recDir, files(1).name);
fprintf('Cargando: %s\n', files(1).name);

try
    % Cargar usando función del visor
    addpath(fullfile(baseDir, '..'));
    [metadatos, datosResp] = cargarRecording_standalone(archivoRec);

    % Convertir tiempo
    tiempoSeg = convertirTiempoASegundos_standalone(datosResp.Tiempo);
    tiempoSeg = tiempoSeg - tiempoSeg(1);

    % Detectar ciclos
    ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg);
    fprintf('Ciclos detectados: %d\n\n', length(ciclos));

    % Calcular mecánica
    mecanica = calcularMecanicaRespiratoria(ciclos, metadatos);

    % Mostrar resultados
    fprintf('--- PARÁMETROS DEL VENTILADOR ---\n');
    fprintf('Modo: %s\n', metadatos.RegimenVentilacion);
    fprintf('Vt programado: %d mL\n', metadatos.VolumenCorriente);
    fprintf('PEEP programado: %.1f cmH2O\n', metadatos.PEEP);
    fprintf('FR programada: %d resp/min\n', metadatos.FrecResp);

    fprintf('\n--- CÁLCULOS PROPIOS (medias) ---\n');
    fprintf('Compliance Estática: %.1f ± %.1f mL/cmH2O\n', ...
        mecanica.media.Cst, mecanica.std.Cst);
    fprintf('Compliance Dinámica: %.1f ± %.1f mL/cmH2O\n', ...
        mecanica.media.Cdyn, mecanica.std.Cdyn);
    fprintf('Resistencia: %.1f ± %.1f cmH2O·s/L\n', ...
        mecanica.media.Raw, mecanica.std.Raw);
    fprintf('Driving Pressure: %.1f ± %.1f cmH2O\n', ...
        mecanica.media.DrivingP, mecanica.std.DrivingP);
    fprintf('WOB: %.2f J/L\n', mecanica.media.WOB);
    fprintf('Constante de tiempo: %.2f s\n', mecanica.media.Tau);

    % Buscar Trends para comparar
    fprintf('\n--- COMPARACIÓN CON TRENDS DEL VENTILADOR ---\n');
    trendFiles = dir(fullfile(trendDir, '*Trends.txt'));
    if ~isempty(trendFiles)
        % Cargar trends (formato simplificado)
        fprintf('Archivo Trends: %s\n', trendFiles(1).name);
        fprintf('(Comparar manualmente Cdyn del ventilador con nuestro cálculo)\n');
        fprintf('Valor esperado de Cdyn del ventilador: ~21-22 mL/cmH2O\n');
    end

    fprintf('\n========================================\n');
    fprintf('Validación completada. Revise los valores.\n');
    fprintf('========================================\n');

catch ME
    fprintf('ERROR durante validación: %s\n', ME.message);
    fprintf('Stack:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s (línea %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end
end

% =========================================================================
% FUNCIONES AUXILIARES PARA TESTS
% =========================================================================

function ciclo = crearCicloSimulado(Vt, Pplateau, PEEP, Ppico)
% Crea un ciclo respiratorio simulado para testing

n = 200;  % 2 segundos a 100 Hz

% Inspiración (0-0.6s): presión sube, flujo positivo
nInsp = 60;
% Pausa (0.6-1.0s): presión meseta, flujo ~0
nPausa = 40;
% Espiración (1.0-2.0s): presión baja, flujo negativo
nEsp = 100;

tiempo = (0:n-1)' / 100;
presion = zeros(n, 1);
volumen = zeros(n, 1);
flujo = zeros(n, 1);
fases = cell(n, 1);

% Inspiración
for i = 1:nInsp
    t = i / nInsp;
    presion(i) = PEEP + (Ppico - PEEP) * t;
    volumen(i) = Vt * t;
    flujo(i) = 40;  % Flujo constante ~40 L/min
    fases{i} = 'insp.';
end

% Pausa inspiratoria
for i = nInsp+1:nInsp+nPausa
    presion(i) = Pplateau;
    volumen(i) = Vt;
    flujo(i) = 0;
    fases{i} = 'pausa de ins.';
end

% Espiración
for i = nInsp+nPausa+1:n
    t = (i - nInsp - nPausa) / nEsp;
    presion(i) = Pplateau - (Pplateau - PEEP) * t;
    volumen(i) = Vt * (1 - t);
    flujo(i) = -60 * exp(-3*t);  % Flujo espiratorio exponencial
    fases{i} = 'esp.';
end

ciclo = struct();
ciclo.indices = [1, n];
ciclo.tiempo = tiempo;
ciclo.presion = presion;
ciclo.volumen = volumen;
ciclo.flujo = flujo;
ciclo.fases = fases;
end

function [datosResp, tiempoSeg] = crearDatosRespiratoriosSimulados(nCiclos)
% Crea datos respiratorios simulados con múltiples ciclos

cicloBase = crearCicloSimulado(400, 25, 8, 28);
nPorCiclo = length(cicloBase.tiempo);
n = nPorCiclo * nCiclos;

tiempo = cell(n, 1);
faseResp = cell(n, 1);
presion = zeros(n, 1);
flujo = zeros(n, 1);
volumen = zeros(n, 1);

for c = 1:nCiclos
    idxBase = (c-1) * nPorCiclo;
    for i = 1:nPorCiclo
        idx = idxBase + i;
        tSeg = (c-1) * 2 + cicloBase.tiempo(i);
        tiempo{idx} = sprintf('00:00:%02d:%03d', floor(tSeg), round(mod(tSeg,1)*1000));
        faseResp{idx} = cicloBase.fases{i};
        presion(idx) = cicloBase.presion(i);
        flujo(idx) = cicloBase.flujo(i);
        volumen(idx) = cicloBase.volumen(i);
    end
end

datosResp = table(tiempo, faseResp, presion, flujo, volumen, ...
    'VariableNames', {'Tiempo', 'FaseRespiracion', 'Pva_cmH2O', 'Flujo_lm', 'V_ml'});

tiempoSeg = (0:n-1)' / 100;
end

% Funciones standalone para validación (copias simplificadas)
function [metadatos, datos] = cargarRecording_standalone(archivo)
fid = fopen(archivo, 'r', 'n', 'UTF-8');
contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lineas = contenido{1};

metadatos = struct();
metadatos.Archivo = archivo;
metadatos.RegimenVentilacion = '';
metadatos.VolumenCorriente = 0;
metadatos.PEEP = 0;
metadatos.FrecResp = 0;

lineaData = find(startsWith(lineas, '[DATA]'));

for i = 1:lineaData-1
    linea = lineas{i};
    if contains(linea, 'Régimen de ventilación')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2, metadatos.RegimenVentilacion = strtrim(partes{2}); end
    elseif contains(linea, 'Volumen corriente') && ~contains(linea, 'Vci')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2, metadatos.VolumenCorriente = str2double(partes{2}); end
    elseif startsWith(linea, 'PEEP')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2, metadatos.PEEP = str2double(partes{2}); end
    elseif contains(linea, 'F resp.')
        partes = strsplit(linea, '\t');
        if length(partes) >= 2, metadatos.FrecResp = str2double(partes{2}); end
    end
end

nLineasDatos = length(lineas) - (lineaData + 1);
tiempo = cell(nLineasDatos, 1);
faseResp = cell(nLineasDatos, 1);
presion = zeros(nLineasDatos, 1);
flujo = zeros(nLineasDatos, 1);
volumen = zeros(nLineasDatos, 1);

for i = 1:nLineasDatos
    linea = lineas{lineaData + 1 + i};
    partes = strsplit(linea, '\t');
    if length(partes) >= 5
        tiempo{i} = partes{1};
        faseResp{i} = partes{2};
        presion(i) = str2double(partes{3});
        flujo(i) = str2double(partes{4});
        volumen(i) = str2double(partes{5});
    end
end

filasValidas = ~cellfun(@isempty, tiempo);
datos = table(tiempo(filasValidas), faseResp(filasValidas), ...
    presion(filasValidas), flujo(filasValidas), volumen(filasValidas), ...
    'VariableNames', {'Tiempo', 'FaseRespiracion', 'Pva_cmH2O', 'Flujo_lm', 'V_ml'});
end

function tiempoSeg = convertirTiempoASegundos_standalone(tiempoStr)
n = length(tiempoStr);
tiempoSeg = zeros(n, 1);
for i = 1:n
    partes = strsplit(tiempoStr{i}, ':');
    if length(partes) >= 4
        tiempoSeg(i) = str2double(partes{1})*3600 + str2double(partes{2})*60 + ...
            str2double(partes{3}) + str2double(partes{4})/1000;
    end
end
end
