%% ANALIZARDATOSVENTILADOR - Analisis completo de datos del ventilador SERVO-U
% Script para cargar y visualizar TODOS los tipos de datos:
%   - Recordings: Curvas en tiempo real (100 Hz)
%   - BreathTrends: Datos por cada respiracion
%   - Recruitments: Maniobras de reclutamiento pulmonar
%   - Trends: Tendencias cada minuto
%
% Autor: Generado para Fisiologia Respiratoria
% Fecha: 2026-01-28

%% Configuracion inicial
clear;
clc;
close all;

% Directorio base de datos
dataDir = fullfile(fileparts(mfilename('fullpath')), 'ventilatorData');

disp('================================================================');
disp('       ANALISIS DE DATOS DEL VENTILADOR SERVO-U');
disp('================================================================');
disp(' ');

%% 1. INVENTARIO DE DATOS DISPONIBLES
disp('INVENTARIO DE DATOS DISPONIBLES:');
disp('---------------------------------');

% Recordings
recordingsDir = fullfile(dataDir, 'recordings');
recordingFiles = dir(fullfile(recordingsDir, '*.txt'));
fprintf('  Recordings (curvas tiempo real): %d archivos\n', length(recordingFiles));

% Trends
trendsDir = fullfile(dataDir, 'trends');
trendFiles = dir(fullfile(trendsDir, '*_Trends.txt'));
breathTrendFiles = dir(fullfile(trendsDir, '*_BreathTrends.txt'));
fprintf('  Trends (tendencias/minuto):      %d archivos\n', length(trendFiles));
fprintf('  BreathTrends (por respiracion):  %d archivos\n', length(breathTrendFiles));

% Recruitments
recruitmentsDir = fullfile(dataDir, 'recruitments');
recruitmentFiles = dir(fullfile(recruitmentsDir, '*.txt'));
fprintf('  Recruitments (reclutamiento):    %d archivos\n', length(recruitmentFiles));

disp(' ');

%% 2. CARGAR BREATHTRENDS (Datos por respiracion)
disp('CARGANDO DATOS POR RESPIRACION (BreathTrends)...');
disp('-------------------------------------------------');

if ~isempty(breathTrendFiles)
    % Cargar el archivo mas grande (tiene mas datos)
    [~, maxIdx] = max([breathTrendFiles.bytes]);
    breathTrendFile = fullfile(trendsDir, breathTrendFiles(maxIdx).name);
    fprintf('   Archivo: %s\n', breathTrendFiles(maxIdx).name);
    
    breathData = cargarBreathTrends(breathTrendFile);
    
    fprintf('   %d respiraciones cargadas\n', height(breathData));
    fprintf('   Periodo: %s a %s\n', breathData.Tiempo{1}, breathData.Tiempo{end});
    
    % Mostrar resumen de variables
    disp(' ');
    disp('   Variables disponibles:');
    varNames = breathData.Properties.VariableNames;
    for i = 1:length(varNames)
        fprintf('     - %s\n', varNames{i});
    end
end

%% 3. VISUALIZACION DE TENDENCIAS POR RESPIRACION
if exist('breathData', 'var')
    
    % Convertir tiempo a datetime
    tiempoNum = datetime(breathData.Tiempo, 'InputFormat', 'HH:mm:ss');
    
    % Crear figura principal
    figure('Name', 'Tendencias por Respiracion - SERVO-U', ...
           'Position', [50, 50, 1400, 900], ...
           'Color', 'w');
    
    % Subplot 1: Compliance Dinamica
    subplot(3, 2, 1);
    plot(tiempoNum, breathData.Cdin_mlcmH2O, 'b.-', 'MarkerSize', 4);
    ylabel('Cdin (mL/cmH2O)');
    title('Compliance Dinamica', 'FontWeight', 'bold');
    grid on;
    validData = breathData.Cdin_mlcmH2O(~isnan(breathData.Cdin_mlcmH2O));
    if ~isempty(validData)
        ylim([0, max(validData) * 1.2]);
    end
    
    % Subplot 2: PEEP
    subplot(3, 2, 2);
    plot(tiempoNum, breathData.PEEP_cmH2O, 'r.-', 'MarkerSize', 4);
    ylabel('PEEP (cmH2O)');
    title('PEEP', 'FontWeight', 'bold');
    grid on;
    
    % Subplot 3: Presion End-Inspiratoria
    subplot(3, 2, 3);
    plot(tiempoNum, breathData.Pei_cmH2O, 'Color', [0.6, 0, 0.6], 'LineWidth', 1);
    ylabel('Pei (cmH2O)');
    title('Presion End-Inspiratoria (Plateau)', 'FontWeight', 'bold');
    grid on;
    
    % Subplot 4: Volumen Tidal
    subplot(3, 2, 4);
    plot(tiempoNum, breathData.Vci_ml, 'g.-', 'MarkerSize', 4, 'DisplayName', 'Vci (insp)');
    hold on;
    plot(tiempoNum, breathData.Vce_ml, 'm.-', 'MarkerSize', 4, 'DisplayName', 'Vce (esp)');
    ylabel('Volumen (mL)');
    title('Volumenes Inspiratorio y Espiratorio', 'FontWeight', 'bold');
    legend('Location', 'best');
    grid on;
    
    % Subplot 5: Frecuencia Respiratoria
    subplot(3, 2, 5);
    plot(tiempoNum, breathData.Fresp_respmin, 'k.-', 'MarkerSize', 4);
    ylabel('FR (resp/min)');
    xlabel('Tiempo');
    title('Frecuencia Respiratoria', 'FontWeight', 'bold');
    grid on;
    
    % Subplot 6: Relacion I:E
    subplot(3, 2, 6);
    ieRatios = parseIERatio(breathData.IE);
    plot(tiempoNum, ieRatios, 'Color', [0.8, 0.4, 0], 'LineWidth', 1);
    ylabel('I:E Ratio');
    xlabel('Tiempo');
    title('Relacion Inspiracion/Espiracion', 'FontWeight', 'bold');
    grid on;
    
    sgtitle('Analisis por Respiracion - Ventilador SERVO-U', 'FontSize', 14, 'FontWeight', 'bold');
end

%% 4. CARGAR RECRUITMENT DATA (Maniobra de reclutamiento)
disp(' ');
disp('CARGANDO DATOS DE RECLUTAMIENTO PULMONAR...');
disp('--------------------------------------------');

if ~isempty(recruitmentFiles)
    % Cargar el archivo mas grande
    [~, maxIdx] = max([recruitmentFiles.bytes]);
    recruitmentFile = fullfile(recruitmentsDir, recruitmentFiles(maxIdx).name);
    fprintf('   Archivo: %s\n', recruitmentFiles(maxIdx).name);
    
    recruitData = cargarBreathTrends(recruitmentFile);
    
    fprintf('   %d puntos de datos cargados\n', height(recruitData));
    
    % Visualizar maniobra de reclutamiento
    figure('Name', 'Maniobra de Reclutamiento Pulmonar', ...
           'Position', [100, 100, 1000, 600], ...
           'Color', 'w');
    
    tiempoRecruit = datetime(recruitData.Tiempo, 'InputFormat', 'HH:mm:ss');
    
    subplot(2, 1, 1);
    yyaxis left
    plot(tiempoRecruit, recruitData.PEEP_cmH2O, 'b-', 'LineWidth', 2);
    ylabel('PEEP (cmH2O)', 'Color', 'b');
    
    yyaxis right
    plot(tiempoRecruit, recruitData.Cdin_mlcmH2O, 'r.-', 'MarkerSize', 6);
    ylabel('Cdin (mL/cmH2O)', 'Color', 'r');
    
    title('Maniobra de Reclutamiento: PEEP vs Compliance', 'FontWeight', 'bold');
    xlabel('Tiempo');
    grid on;
    legend('PEEP', 'Compliance', 'Location', 'best');
    
    % Curva P-V durante reclutamiento
    subplot(2, 1, 2);
    scatter(recruitData.PEEP_cmH2O, recruitData.Cdin_mlcmH2O, 50, ...
            1:height(recruitData), 'filled');
    colorbar;
    xlabel('PEEP (cmH2O)');
    ylabel('Compliance Dinamica (mL/cmH2O)');
    title('Relacion PEEP-Compliance durante Reclutamiento', 'FontWeight', 'bold');
    grid on;
    
    sgtitle('Maniobra de Reclutamiento Pulmonar', 'FontSize', 14, 'FontWeight', 'bold');
end

%% 5. CARGAR GRABACION EN TIEMPO REAL
disp(' ');
disp('CARGANDO CURVAS EN TIEMPO REAL...');
disp('----------------------------------');

if ~isempty(recordingFiles)
    % Listar archivos
    for i = 1:length(recordingFiles)
        fprintf('   [%d] %s (%.1f KB)\n', i, recordingFiles(i).name, recordingFiles(i).bytes/1024);
    end
    
    % Cargar el primero
    selectedFile = fullfile(recordingsDir, recordingFiles(1).name);
    fprintf('\n   Cargando: %s\n', recordingFiles(1).name);
    
    [metadatos, datosResp] = cargarRecording(selectedFile);
    
    fprintf('   %d muestras cargadas (%.1f segundos a 100 Hz)\n', ...
            height(datosResp), height(datosResp)/100);
    
    % Visualizar curvas
    tiempoStr = datosResp.Tiempo;
    tiempoSeg = convertirTiempoASegundos(tiempoStr);
    tiempoSeg = tiempoSeg - tiempoSeg(1);
    
    figure('Name', 'Curvas de Ventilacion en Tiempo Real', ...
           'Position', [150, 150, 1200, 700], ...
           'Color', 'w');
    
    subplot(3, 1, 1);
    plot(tiempoSeg, datosResp.Pva_cmH2O, 'b-', 'LineWidth', 1);
    ylabel('Presion (cmH2O)');
    title(sprintf('Modo: %s | Vt: %d mL | FR: %d | PEEP: %.1f', ...
                  metadatos.RegimenVentilacion, metadatos.VolumenCorriente, ...
                  metadatos.FrecResp, metadatos.PEEP), 'FontWeight', 'bold');
    grid on;
    xlim([0, min(20, max(tiempoSeg))]);
    
    subplot(3, 1, 2);
    plot(tiempoSeg, datosResp.Flujo_lm, 'Color', [0, 0.6, 0], 'LineWidth', 1);
    hold on;
    yline(0, 'k--');
    ylabel('Flujo (L/min)');
    grid on;
    xlim([0, min(20, max(tiempoSeg))]);
    
    subplot(3, 1, 3);
    plot(tiempoSeg, datosResp.V_ml, 'Color', [0.8, 0.4, 0], 'LineWidth', 1);
    ylabel('Volumen (mL)');
    xlabel('Tiempo (s)');
    grid on;
    xlim([0, min(20, max(tiempoSeg))]);
    
    sgtitle('Monitor de Ventilacion - SERVO-U', 'FontSize', 14, 'FontWeight', 'bold');
end

%% 6. RESUMEN ESTADISTICO
disp(' ');
disp('RESUMEN ESTADISTICO:');
disp('================================================================');

if exist('breathData', 'var')
    fprintf('\nEstadisticas de BreathTrends (%d respiraciones):\n', height(breathData));
    disp('---------------------------------------------------');
    
    validCdin = breathData.Cdin_mlcmH2O(~isnan(breathData.Cdin_mlcmH2O));
    validPEEP = breathData.PEEP_cmH2O(~isnan(breathData.PEEP_cmH2O));
    validVt = breathData.Vci_ml(~isnan(breathData.Vci_ml));
    validFR = breathData.Fresp_respmin(~isnan(breathData.Fresp_respmin));
    
    disp('   Compliance Dinamica:');
    fprintf('     Media: %.1f +/- %.1f mL/cmH2O\n', mean(validCdin), std(validCdin));
    fprintf('     Rango: [%.1f - %.1f] mL/cmH2O\n', min(validCdin), max(validCdin));
    
    disp(' ');
    disp('   PEEP:');
    fprintf('     Media: %.1f +/- %.1f cmH2O\n', mean(validPEEP), std(validPEEP));
    fprintf('     Rango: [%.1f - %.1f] cmH2O\n', min(validPEEP), max(validPEEP));
    
    disp(' ');
    disp('   Volumen Tidal (Vci):');
    fprintf('     Media: %.1f +/- %.1f mL\n', mean(validVt), std(validVt));
    fprintf('     Rango: [%.0f - %.0f] mL\n', min(validVt), max(validVt));
    
    disp(' ');
    disp('   Frecuencia Respiratoria:');
    fprintf('     Media: %.1f +/- %.1f resp/min\n', mean(validFR), std(validFR));
    fprintf('     Rango: [%.0f - %.0f] resp/min\n', min(validFR), max(validFR));
end

disp(' ');
disp('================================================================');
fprintf('Analisis completado. %d figuras generadas.\n', length(findall(0, 'Type', 'figure')));

%% FUNCIONES AUXILIARES

function datos = cargarBreathTrends(archivo)
% CARGARBREATHTRENDS - Carga datos de tendencias por respiracion

    fid = fopen(archivo, 'r', 'n', 'UTF-8');
    contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    lineas = contenido{1};
    
    % Buscar linea [DATA]
    lineaData = find(startsWith(lineas, '[DATA]'));
    
    % Leer encabezado
    encabezado = lineas{lineaData + 1};
    columnas = strsplit(encabezado, '\t');
    
    % Preparar arrays
    nLineas = length(lineas) - (lineaData + 1);
    
    tiempo = cell(nLineas, 1);
    cdin = nan(nLineas, 1);
    pei = nan(nLineas, 1);
    peep = nan(nLineas, 1);
    vce = nan(nLineas, 1);
    vci = nan(nLineas, 1);
    pactividad = nan(nLineas, 1);
    ie = cell(nLineas, 1);
    fresp = nan(nLineas, 1);
    
    for i = 1:nLineas
        linea = lineas{lineaData + 1 + i};
        partes = strsplit(linea, '\t');
        
        if length(partes) >= 9 && ~isempty(partes{1})
            tiempo{i} = partes{1};
            cdin(i) = parseNumero(partes{2});
            pei(i) = parseNumero(partes{3});
            peep(i) = parseNumero(partes{4});
            vce(i) = parseNumero(partes{5});
            vci(i) = parseNumero(partes{6});
            pactividad(i) = parseNumero(partes{7});
            ie{i} = strtrim(partes{8});
            fresp(i) = parseNumero(partes{9});
        end
    end
    
    % Eliminar filas vacias
    validos = ~cellfun(@isempty, tiempo);
    
    datos = table(tiempo(validos), cdin(validos), pei(validos), peep(validos), ...
                  vce(validos), vci(validos), pactividad(validos), ie(validos), fresp(validos), ...
                  'VariableNames', {'Tiempo', 'Cdin_mlcmH2O', 'Pei_cmH2O', 'PEEP_cmH2O', ...
                                    'Vce_ml', 'Vci_ml', 'Pactividad_cmH2O', 'IE', 'Fresp_respmin'});
end

function valor = parseNumero(str)
% Parsear numero, manejando valores especiales
    str = strtrim(str);
    if isempty(str) || strcmp(str, '***') || strcmp(str, ' ')
        valor = NaN;
    else
        str = strrep(str, '#', '');
        valor = str2double(str);
    end
end

function ieRatios = parseIERatio(ieCell)
% Convertir I:E ratio a numero
    n = length(ieCell);
    ieRatios = nan(n, 1);
    
    for i = 1:n
        str = ieCell{i};
        if contains(str, ':')
            partes = strsplit(str, ':');
            if length(partes) == 2
                num1 = str2double(strtrim(partes{1}));
                num2 = str2double(strtrim(partes{2}));
                if ~isnan(num1) && ~isnan(num2) && num2 ~= 0
                    ieRatios(i) = num1 / num2;
                end
            end
        end
    end
end

function [metadatos, datos] = cargarRecording(archivo)
% CARGARRECORDING - Carga un archivo de grabacion del ventilador

    fid = fopen(archivo, 'r', 'n', 'UTF-8');
    contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    lineas = contenido{1};
    
    % Inicializar estructura de metadatos
    metadatos = struct();
    metadatos.Archivo = archivo;
    metadatos.RegimenVentilacion = '';
    metadatos.VolumenCorriente = 0;
    metadatos.PEEP = 0;
    metadatos.FrecResp = 0;
    metadatos.FiO2 = 0;
    
    % Buscar linea de inicio de datos
    lineaData = find(startsWith(lineas, '[DATA]'));
    
    % Procesar metadatos
    for i = 1:lineaData-1
        linea = lineas{i};
        if contains(linea, 'Régimen de ventilación')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.RegimenVentilacion = strtrim(partes{2});
            end
        elseif contains(linea, 'Volumen corriente') && ~contains(linea, 'Vci')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.VolumenCorriente = str2double(partes{2});
            end
        elseif startsWith(linea, 'PEEP')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.PEEP = str2double(partes{2});
            end
        elseif contains(linea, 'F resp.')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.FrecResp = str2double(partes{2});
            end
        elseif contains(linea, 'Conc. de O2')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.FiO2 = str2double(partes{2});
            end
        end
    end
    
    % Leer datos
    nLineasDatos = length(lineas) - (lineaData + 1);
    
    tiempo = cell(nLineasDatos, 1);
    faseResp = cell(nLineasDatos, 1);
    presion = zeros(nLineasDatos, 1);
    flujo = zeros(nLineasDatos, 1);
    volumen = zeros(nLineasDatos, 1);
    trigger = cell(nLineasDatos, 1);
    
    for i = 1:nLineasDatos
        linea = lineas{lineaData + 1 + i};
        partes = strsplit(linea, '\t');
        
        if length(partes) >= 5
            tiempo{i} = partes{1};
            faseResp{i} = partes{2};
            presion(i) = str2double(partes{3});
            flujo(i) = str2double(partes{4});
            volumen(i) = str2double(partes{5});
            if length(partes) >= 6
                trigger{i} = partes{6};
            else
                trigger{i} = '';
            end
        end
    end
    
    filasValidas = ~cellfun(@isempty, tiempo);
    datos = table(tiempo(filasValidas), faseResp(filasValidas), presion(filasValidas), ...
                  flujo(filasValidas), volumen(filasValidas), trigger(filasValidas), ...
                  'VariableNames', {'Tiempo', 'FaseRespiracion', 'Pva_cmH2O', ...
                                    'Flujo_lm', 'V_ml', 'Trigger'});
end

function tiempoSeg = convertirTiempoASegundos(tiempoStr)
    n = length(tiempoStr);
    tiempoSeg = zeros(n, 1);
    
    for i = 1:n
        partes = strsplit(tiempoStr{i}, ':');
        if length(partes) >= 4
            horas = str2double(partes{1});
            minutos = str2double(partes{2});
            segundos = str2double(partes{3});
            miliseg = str2double(partes{4});
            tiempoSeg(i) = horas * 3600 + minutos * 60 + segundos + miliseg/1000;
        end
    end
end
