%% CARGARDATOSVENTILADOR - Importar y visualizar datos de ventilador SERVO-U
% Script para cargar datos respiratorios desde archivos TXT del ventilador
%
% Autor: Generado automáticamente
% Fecha: 2026-01-28
%
% Este script permite:
%   1. Cargar grabaciones en tiempo real (recordings)
%   2. Cargar tendencias (trends)
%   3. Visualizar las curvas respiratorias
%
%% Configuración inicial
clear; clc; close all;

% Directorio base de datos
dataDir = fullfile(fileparts(mfilename('fullpath')), 'ventilatorData');

%% ========================================================================
% 1. CARGAR GRABACIÓN EN TIEMPO REAL (RECORDINGS)
% =========================================================================

fprintf('=== CARGA DE DATOS DEL VENTILADOR SERVO-U ===\n\n');

% Listar archivos de grabación disponibles
recordingsDir = fullfile(dataDir, 'recordings');
recordingFiles = dir(fullfile(recordingsDir, '*.txt'));

fprintf('Archivos de grabación disponibles:\n');
for i = 1:length(recordingFiles)
    fprintf('  [%d] %s\n', i, recordingFiles(i).name);
end

% Seleccionar primer archivo para demostración
if ~isempty(recordingFiles)
    selectedFile = fullfile(recordingsDir, recordingFiles(1).name);
    fprintf('\nCargando: %s\n', recordingFiles(1).name);
    
    % Cargar datos de grabación
    [metadatos, datosResp] = cargarRecording(selectedFile);
    
    fprintf('\n--- Metadatos de la grabación ---\n');
    disp(metadatos);
    
    fprintf('\n--- Primeras filas de datos ---\n');
    disp(head(datosResp, 10));
end

%% ========================================================================
% 2. VISUALIZACIÓN DE CURVAS RESPIRATORIAS
% =========================================================================

if exist('datosResp', 'var') && ~isempty(datosResp)
    
    % Crear vector de tiempo en segundos desde el inicio
    tiempoStr = datosResp.Tiempo;
    tiempoSeg = convertirTiempoASegundos(tiempoStr);
    tiempoSeg = tiempoSeg - tiempoSeg(1); % Iniciar desde 0
    
    % Extraer señales
    presion = datosResp.Pva_cmH2O;
    flujo = datosResp.Flujo_lm;
    volumen = datosResp.V_ml;
    faseResp = datosResp.FaseRespiracion;
    
    %% FIGURA 1: Panel estándar de ventilación
    figure('Name', 'Curvas de Ventilación Mecánica', ...
           'Position', [100, 100, 1200, 800], ...
           'Color', 'w');
    
    % Subplot 1: Presión de vía aérea
    subplot(3,1,1);
    plot(tiempoSeg, presion, 'b-', 'LineWidth', 1.2);
    hold on;
    yline(metadatos.PEEP, 'r--', 'PEEP', 'LineWidth', 1.5);
    ylabel('Presión (cmH_2O)', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('Ventilación: %s | Vt: %d ml | FR: %d rpm | PEEP: %.1f cmH_2O', ...
          metadatos.RegimenVentilacion, metadatos.VolumenCorriente, ...
          metadatos.FrecResp, metadatos.PEEP), 'FontSize', 14);
    grid on;
    xlim([0, min(30, max(tiempoSeg))]); % Mostrar primeros 30 segundos
    
    % Subplot 2: Flujo
    subplot(3,1,2);
    plot(tiempoSeg, flujo, 'Color', [0, 0.6, 0], 'LineWidth', 1.2);
    hold on;
    yline(0, 'k-', 'LineWidth', 0.5);
    ylabel('Flujo (L/min)', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    xlim([0, min(30, max(tiempoSeg))]);
    
    % Subplot 3: Volumen
    subplot(3,1,3);
    plot(tiempoSeg, volumen, 'Color', [0.8, 0.4, 0], 'LineWidth', 1.2);
    ylabel('Volumen (mL)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Tiempo (s)', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    xlim([0, min(30, max(tiempoSeg))]);
    
    % Ajustar espaciado
    sgtitle('Monitor de Ventilación Mecánica - SERVO-U', 'FontSize', 16, 'FontWeight', 'bold');
    
    %% FIGURA 2: Bucle Presión-Volumen (P-V Loop)
    figure('Name', 'Bucle Presión-Volumen', ...
           'Position', [150, 150, 600, 500], ...
           'Color', 'w');
    
    % Seleccionar un ciclo respiratorio completo
    % Buscar inicio de inspiración (transición esp -> insp)
    esInsp = contains(faseResp, 'insp');
    cambiosInsp = diff([0; esInsp]);
    iniciosInsp = find(cambiosInsp == 1);
    
    if length(iniciosInsp) >= 2
        % Tomar el segundo ciclo completo
        inicioCiclo = iniciosInsp(2);
        finCiclo = iniciosInsp(3) - 1;
        
        plot(presion(inicioCiclo:finCiclo), volumen(inicioCiclo:finCiclo), ...
             'b-', 'LineWidth', 2);
        hold on;
        plot(presion(inicioCiclo), volumen(inicioCiclo), 'go', 'MarkerSize', 10, ...
             'MarkerFaceColor', 'g', 'DisplayName', 'Inicio');
        plot(presion(finCiclo), volumen(finCiclo), 'ro', 'MarkerSize', 10, ...
             'MarkerFaceColor', 'r', 'DisplayName', 'Fin');
        
        xlabel('Presión (cmH_2O)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Volumen (mL)', 'FontSize', 12, 'FontWeight', 'bold');
        title('Bucle Presión-Volumen (P-V Loop)', 'FontSize', 14);
        legend('Ciclo', 'Inicio Insp', 'Fin Ciclo', 'Location', 'northwest');
        grid on;
    end
    
    %% FIGURA 3: Bucle Flujo-Volumen (F-V Loop)
    figure('Name', 'Bucle Flujo-Volumen', ...
           'Position', [200, 200, 600, 500], ...
           'Color', 'w');
    
    if length(iniciosInsp) >= 2
        plot(volumen(inicioCiclo:finCiclo), flujo(inicioCiclo:finCiclo), ...
             'Color', [0.6, 0, 0.6], 'LineWidth', 2);
        hold on;
        yline(0, 'k--');
        xlabel('Volumen (mL)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Flujo (L/min)', 'FontSize', 12, 'FontWeight', 'bold');
        title('Bucle Flujo-Volumen (F-V Loop)', 'FontSize', 14);
        grid on;
    end
    
    %% ANÁLISIS DE MECÁNICA RESPIRATORIA
    fprintf('\n=== ANÁLISIS DE MECÁNICA RESPIRATORIA ===\n');
    fprintf('Volumen tidal medido: %.1f mL\n', max(volumen) - min(volumen));
    fprintf('Presión pico: %.1f cmH2O\n', max(presion));
    fprintf('PEEP configurada: %.1f cmH2O\n', metadatos.PEEP);
    
    % Calcular compliance dinámica aproximada
    deltaV = max(volumen) - min(volumen);
    deltaP = max(presion) - metadatos.PEEP;
    complianceDin = deltaV / deltaP;
    fprintf('Compliance dinámica estimada: %.1f mL/cmH2O\n', complianceDin);
end

%% ========================================================================
% FUNCIONES AUXILIARES
% =========================================================================

function [metadatos, datos] = cargarRecording(archivo)
    % CARGARRECORDING - Carga un archivo de grabación del ventilador
    %
    % Entradas:
    %   archivo - Ruta completa al archivo .txt
    %
    % Salidas:
    %   metadatos - Estructura con información de configuración
    %   datos     - Tabla con los datos de las curvas
    
    % Leer archivo completo
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
    
    % Buscar línea de inicio de datos
    lineaData = find(startsWith(lineas, '[DATA]'));
    
    % Procesar metadatos (antes de [DATA])
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
        elseif contains(linea, 'Fecha de grabación')
            partes = strsplit(linea, '\t');
            if length(partes) >= 2
                metadatos.FechaGrabacion = strtrim(partes{2});
            end
        end
    end
    
    % Leer encabezado de datos
    encabezado = lineas{lineaData + 1};
    columnas = strsplit(encabezado, '\t');
    
    % Leer datos numéricos (desde lineaData+2 hasta el final)
    nLineasDatos = length(lineas) - (lineaData + 1);
    
    % Preparar arrays
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
    
    % Crear tabla
    datos = table(tiempo, faseResp, presion, flujo, volumen, trigger, ...
                  'VariableNames', {'Tiempo', 'FaseRespiracion', 'Pva_cmH2O', ...
                                    'Flujo_lm', 'V_ml', 'Trigger'});
    
    % Eliminar filas vacías
    filasValidas = ~cellfun(@isempty, datos.Tiempo);
    datos = datos(filasValidas, :);
end

function tiempoSeg = convertirTiempoASegundos(tiempoStr)
    % CONVERTIRTIEMPOASEGUNDOS - Convierte tiempo HH:MM:SS:mmm a segundos
    
    n = length(tiempoStr);
    tiempoSeg = zeros(n, 1);
    
    for i = 1:n
        partes = strsplit(tiempoStr{i}, ':');
        if length(partes) >= 4
            horas = str2double(partes{1});
            minutos = str2double(partes{2});
            segundos = str2double(partes{3});
            miliseg = str2double(partes{4});
            tiempoSeg(i) = horas*3600 + minutos*60 + segundos + miliseg/1000;
        end
    end
end
