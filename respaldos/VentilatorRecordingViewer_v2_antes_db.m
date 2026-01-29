classdef VentilatorRecordingViewer < matlab.apps.AppBase
    % VENTILATORRECORDINGVIEWER - Visor avanzado de grabaciones del ventilador SERVO-U
    %
    % Versión mejorada con:
    %   - Cálculos de mecánica respiratoria (Cst, Cdyn, Raw, ΔP, WOB)
    %   - Análisis por ciclo respiratorio
    %   - Loops configurables (P-V, F-V, P-F, V-t)
    %   - Soporte para Trends y Recruitments
    %   - Exportación de datos
    %
    % Uso:
    %   VentilatorRecordingViewer
    %
    % Ver también: calcularMecanicaRespiratoria, detectarCiclosRespiratorios, analizarLoop
    %
    % Autor: Proyecto Fisiología Respiratoria
    % Fecha: 2026-01-28
    % Respaldo: respaldos/VentilatorRecordingViewer_v1_backup.m

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout
        LeftPanel                  matlab.ui.container.Panel
        MetadataPanel              matlab.ui.container.Panel
        RecordingDropDownLabel     matlab.ui.control.Label
        RecordingDropDown          matlab.ui.control.DropDown
        LoadButton                 matlab.ui.control.Button
        ModoLabel                  matlab.ui.control.Label
        ModoValue                  matlab.ui.control.Label
        VtLabel                    matlab.ui.control.Label
        VtValue                    matlab.ui.control.Label
        PEEPLabel                  matlab.ui.control.Label
        PEEPValue                  matlab.ui.control.Label
        FRLabel                    matlab.ui.control.Label
        FRValue                    matlab.ui.control.Label
        FiO2Label                  matlab.ui.control.Label
        FiO2Value                  matlab.ui.control.Label
        IELabel                    matlab.ui.control.Label
        IEValue                    matlab.ui.control.Label
        DurationLabel              matlab.ui.control.Label
        DurationValue              matlab.ui.control.Label
        RightPanel                 matlab.ui.container.Panel
        AxesPressure               matlab.ui.control.UIAxes
        AxesFlow                   matlab.ui.control.UIAxes
        AxesVolume                 matlab.ui.control.UIAxes
        AxesLoop                   matlab.ui.control.UIAxes
        ControlPanel               matlab.ui.container.Panel
        TimeSlider                 matlab.ui.control.Slider
        TimeSliderLabel            matlab.ui.control.Label
        WindowSpinner              matlab.ui.control.Spinner
        WindowSpinnerLabel         matlab.ui.control.Label
        StatusLabel                matlab.ui.control.Label
        % Nuevos componentes para módulos avanzados
        MechanicsPanel             matlab.ui.container.Panel
        CstLabel                   matlab.ui.control.Label
        CstValue                   matlab.ui.control.Label
        CdynLabel                  matlab.ui.control.Label
        CdynValue                  matlab.ui.control.Label
        RawLabel                   matlab.ui.control.Label
        RawValue                   matlab.ui.control.Label
        DrivingPLabel              matlab.ui.control.Label
        DrivingPValue              matlab.ui.control.Label
        WOBLabel                   matlab.ui.control.Label
        WOBValue                   matlab.ui.control.Label
        % Loop configurable
        LoopXDropDown              matlab.ui.control.DropDown
        LoopYDropDown              matlab.ui.control.DropDown
        LoopXLabel                 matlab.ui.control.Label
        LoopYLabel                 matlab.ui.control.Label
        CalcMechanicsButton        matlab.ui.control.Button
        % Selector de tipo de archivo
        FileTypeDropDown           matlab.ui.control.DropDown
        FileTypeLabel              matlab.ui.control.Label
        ExportButton               matlab.ui.control.Button
        % Sistema de pestañas
        TabGroup                   matlab.ui.container.TabGroup
        TabResumen                 matlab.ui.container.Tab
        TabCurvas                  matlab.ui.container.Tab
        TabLoops                   matlab.ui.container.Tab
        TabTendencias              matlab.ui.container.Tab
        % Tabla resumen
        SummaryTable               matlab.ui.control.Table
        % Dropdowns para Curvas tab
        Var1Dropdown               matlab.ui.control.DropDown
        Var2Dropdown               matlab.ui.control.DropDown
        Var3Dropdown               matlab.ui.control.DropDown
        Var4Dropdown               matlab.ui.control.DropDown
        % Axes adicionales para pestañas
        AxesTrend1                 matlab.ui.control.UIAxes
        AxesTrend2                 matlab.ui.control.UIAxes
    end

    % Properties to store data
    properties (Access = private)
        DataDir                    % Directory with recordings
        Metadatos                  % Metadata structure
        DatosResp                  % Respiratory data table
        TiempoSeg                  % Time in seconds
        MaxTiempo                  % Maximum time
        Ciclos                     % Detected respiratory cycles
        Mecanica                   % Respiratory mechanics results
        CurrentFileType            % 'recordings', 'trends', 'recruitments'
    end

    methods (Access = private)

        function scanFiles(app)
            % Scan for available files based on selected type
            baseDir = fullfile(fileparts(mfilename('fullpath')), 'ventilatorData');

            switch app.FileTypeDropDown.Value
                case 'Grabaciones'
                    app.DataDir = fullfile(baseDir, 'recordings');
                    app.CurrentFileType = 'recordings';
                case 'Tendencias'
                    app.DataDir = fullfile(baseDir, 'trends');
                    app.CurrentFileType = 'trends';
                case 'Reclutamiento'
                    app.DataDir = fullfile(baseDir, 'recruitments');
                    app.CurrentFileType = 'recruitments';
            end

            if ~isfolder(app.DataDir)
                app.StatusLabel.Text = 'Error: No se encontró carpeta';
                return;
            end

            files = dir(fullfile(app.DataDir, '*.txt'));

            if isempty(files)
                app.StatusLabel.Text = 'No se encontraron archivos';
                app.RecordingDropDown.Items = {'Sin archivos'};
                return;
            end

            % Create dropdown items with file info
            items = cell(1, length(files));
            for i = 1:length(files)
                sizeMB = files(i).bytes / 1024;
                items{i} = sprintf('%s (%.1f KB)', files(i).name, sizeMB);
            end

            app.RecordingDropDown.Items = items;
            app.RecordingDropDown.ItemsData = {files.name};
            app.StatusLabel.Text = sprintf('%d archivos disponibles', length(files));
        end

        function [metadatos, datos] = cargarRecording(~, archivo)
            % Load a ventilator recording file

            fid = fopen(archivo, 'r', 'n', 'UTF-8');
            contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
            fclose(fid);
            lineas = contenido{1};

            % Initialize metadata structure
            metadatos = struct();
            metadatos.Archivo = archivo;
            metadatos.RegimenVentilacion = '';
            metadatos.VolumenCorriente = 0;
            metadatos.PEEP = 0;
            metadatos.FrecResp = 0;
            metadatos.FiO2 = 0;
            metadatos.IE = '';

            % Find data start line
            lineaData = find(startsWith(lineas, '[DATA]'));

            % Process metadata
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
                elseif startsWith(linea, 'I:E')
                    partes = strsplit(linea, '\t');
                    if length(partes) >= 2
                        metadatos.IE = strtrim(partes{2});
                    end
                end
            end

            % Read data
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

        function tiempoSeg = convertirTiempoASegundos(~, tiempoStr)
            % Convert time strings to seconds
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

        function updatePlots(app)
            % Update the plots based on current slider and window settings
            if isempty(app.TiempoSeg)
                return;
            end

            startTime = app.TimeSlider.Value;
            windowSize = app.WindowSpinner.Value;
            endTime = min(startTime + windowSize, app.MaxTiempo);

            % Find indices for the time window
            idx = app.TiempoSeg >= startTime & app.TiempoSeg <= endTime;
            t = app.TiempoSeg(idx) - startTime;  % Relative time

            presion = app.DatosResp.Pva_cmH2O(idx);
            flujo = app.DatosResp.Flujo_lm(idx);
            volumen = app.DatosResp.V_ml(idx);
            fases = app.DatosResp.FaseRespiracion(idx);

            % Plot pressure
            cla(app.AxesPressure);
            plot(app.AxesPressure, t, presion, 'b-', 'LineWidth', 1);
            ylabel(app.AxesPressure, 'Presión (cmH2O)');
            title(app.AxesPressure, 'Presión de Vía Aérea', 'FontWeight', 'bold');
            grid(app.AxesPressure, 'on');
            xlim(app.AxesPressure, [0, windowSize]);

            % Plot flow
            cla(app.AxesFlow);
            plot(app.AxesFlow, t, flujo, 'Color', [0, 0.6, 0], 'LineWidth', 1);
            hold(app.AxesFlow, 'on');
            yline(app.AxesFlow, 0, 'k--', 'LineWidth', 0.5);
            hold(app.AxesFlow, 'off');
            ylabel(app.AxesFlow, 'Flujo (L/min)');
            title(app.AxesFlow, 'Flujo', 'FontWeight', 'bold');
            grid(app.AxesFlow, 'on');
            xlim(app.AxesFlow, [0, windowSize]);

            % Plot volume
            cla(app.AxesVolume);
            plot(app.AxesVolume, t, volumen, 'Color', [0.8, 0.4, 0], 'LineWidth', 1);
            ylabel(app.AxesVolume, 'Volumen (mL)');
            xlabel(app.AxesVolume, 'Tiempo (s)');
            title(app.AxesVolume, 'Volumen', 'FontWeight', 'bold');
            grid(app.AxesVolume, 'on');
            xlim(app.AxesVolume, [0, windowSize]);

            % Update configurable loop
            updateLoop(app, presion, flujo, volumen, t, fases);

            app.StatusLabel.Text = sprintf('Mostrando: %.1f - %.1f s', startTime, endTime);
        end

        function updateLoop(app, presion, flujo, volumen, tiempo, fases)
            % Update the configurable loop plot

            % Get selected variables
            varX = app.LoopXDropDown.Value;
            varY = app.LoopYDropDown.Value;

            % Map selection to data
            switch varX
                case 'Presión'
                    datoX = presion;
                    labelX = 'Presión (cmH2O)';
                case 'Flujo'
                    datoX = flujo;
                    labelX = 'Flujo (L/min)';
                case 'Volumen'
                    datoX = volumen;
                    labelX = 'Volumen (mL)';
                case 'Tiempo'
                    datoX = tiempo;
                    labelX = 'Tiempo (s)';
            end

            switch varY
                case 'Presión'
                    datoY = presion;
                    labelY = 'Presión (cmH2O)';
                case 'Flujo'
                    datoY = flujo;
                    labelY = 'Flujo (L/min)';
                case 'Volumen'
                    datoY = volumen;
                    labelY = 'Volumen (mL)';
                case 'Tiempo'
                    datoY = tiempo;
                    labelY = 'Tiempo (s)';
            end

            % Plot with phase colors
            cla(app.AxesLoop);
            hold(app.AxesLoop, 'on');

            isInsp = contains(fases, 'insp');
            isEsp = contains(fases, 'esp');
            isPausa = contains(fases, 'pausa');

            if any(isInsp)
                plot(app.AxesLoop, datoX(isInsp), datoY(isInsp), 'b.', 'MarkerSize', 4);
            end
            if any(isEsp)
                plot(app.AxesLoop, datoX(isEsp), datoY(isEsp), 'r.', 'MarkerSize', 4);
            end
            if any(isPausa)
                plot(app.AxesLoop, datoX(isPausa), datoY(isPausa), 'g.', 'MarkerSize', 4);
            end

            % Continuous line
            plot(app.AxesLoop, datoX, datoY, 'k-', 'LineWidth', 0.5, 'Color', [0.5 0.5 0.5]);

            hold(app.AxesLoop, 'off');
            xlabel(app.AxesLoop, labelX);
            ylabel(app.AxesLoop, labelY);
            title(app.AxesLoop, sprintf('Loop %s - %s', varX, varY), 'FontWeight', 'bold');
            grid(app.AxesLoop, 'on');
            legend(app.AxesLoop, {'Insp', 'Esp', 'Pausa'}, 'Location', 'best', 'FontSize', 8);
        end

        function updateMetadataDisplay(app)
            % Update metadata labels
            app.ModoValue.Text = app.Metadatos.RegimenVentilacion;
            app.VtValue.Text = sprintf('%d mL', app.Metadatos.VolumenCorriente);
            app.PEEPValue.Text = sprintf('%.1f cmH2O', app.Metadatos.PEEP);
            app.FRValue.Text = sprintf('%d resp/min', app.Metadatos.FrecResp);
            app.FiO2Value.Text = sprintf('%d%%', app.Metadatos.FiO2);
            app.IEValue.Text = app.Metadatos.IE;
            app.DurationValue.Text = sprintf('%.1f s', app.MaxTiempo);
        end

        function updateMechanicsDisplay(app)
            % Update mechanics panel with calculated values
            if isempty(app.Mecanica)
                return;
            end

            app.CstValue.Text = sprintf('%.1f mL/cmH2O', app.Mecanica.media.Cst);
            app.CdynValue.Text = sprintf('%.1f mL/cmH2O', app.Mecanica.media.Cdyn);
            app.RawValue.Text = sprintf('%.1f cmH2O·s/L', app.Mecanica.media.Raw);
            app.DrivingPValue.Text = sprintf('%.1f cmH2O', app.Mecanica.media.DrivingP);
            app.WOBValue.Text = sprintf('%.2f J/L', app.Mecanica.media.WOB);
        end

        function plotTrendsData(app, datos)
            % Visualize Trends data in the four axes
            n = height(datos);
            x = 1:n;  % Index as X axis

            % Clear all axes
            cla(app.AxesPressure);
            cla(app.AxesFlow);
            cla(app.AxesVolume);
            cla(app.AxesLoop);

            % Get column names
            varNames = datos.Properties.VariableNames;
            varNamesLower = lower(varNames);

            % Find columns
            cdynCol = find(contains(varNamesLower, 'cdyn') | contains(varNamesLower, 'cdin'), 1);
            peepCol = find(contains(varNamesLower, 'peep'), 1);
            vciCol = find(contains(varNamesLower, 'vci'), 1);
            if isempty(vciCol)
                vciCol = find(contains(varNamesLower, 'vce'), 1);
            end

            % Plot 1: Compliance dinámica
            if ~isempty(cdynCol)
                y = app.extractColumnData(datos, cdynCol);
                valid = ~isnan(y);
                if any(valid)
                    plot(app.AxesPressure, x(valid), y(valid), 'b.-', 'LineWidth', 1, 'MarkerSize', 4);
                    ylabel(app.AxesPressure, 'Cdyn (mL/cmH2O)');
                    title(app.AxesPressure, 'Compliance Dinámica', 'FontWeight', 'bold');
                    grid(app.AxesPressure, 'on');
                end
            end

            % Plot 2: PEEP
            if ~isempty(peepCol)
                y = app.extractColumnData(datos, peepCol);
                valid = ~isnan(y);
                if any(valid)
                    plot(app.AxesFlow, x(valid), y(valid), 'g.-', 'LineWidth', 1, 'MarkerSize', 4);
                    ylabel(app.AxesFlow, 'PEEP (cmH2O)');
                    title(app.AxesFlow, 'PEEP', 'FontWeight', 'bold');
                    grid(app.AxesFlow, 'on');
                end
            end

            % Plot 3: Volumen tidal
            if ~isempty(vciCol)
                y = app.extractColumnData(datos, vciCol);
                valid = ~isnan(y);
                if any(valid)
                    plot(app.AxesVolume, x(valid), y(valid), 'Color', [0.8 0.4 0], 'LineWidth', 1, 'MarkerSize', 4);
                    ylabel(app.AxesVolume, 'Volumen (mL)');
                    xlabel(app.AxesVolume, 'Registro #');
                    title(app.AxesVolume, 'Volumen Tidal', 'FontWeight', 'bold');
                    grid(app.AxesVolume, 'on');
                end
            end

            % Plot 4: Cdyn vs PEEP scatter
            if ~isempty(cdynCol) && ~isempty(peepCol)
                cdyn = app.extractColumnData(datos, cdynCol);
                peep = app.extractColumnData(datos, peepCol);
                valid = ~isnan(cdyn) & ~isnan(peep);
                if any(valid)
                    scatter(app.AxesLoop, peep(valid), cdyn(valid), 30, find(valid), 'filled');
                    xlabel(app.AxesLoop, 'PEEP (cmH2O)');
                    ylabel(app.AxesLoop, 'Cdyn (mL/cmH2O)');
                    title(app.AxesLoop, 'Cdyn vs PEEP', 'FontWeight', 'bold');
                    colorbar(app.AxesLoop);
                    grid(app.AxesLoop, 'on');
                end
            end
        end

        function y = extractColumnData(~, datos, colIdx)
            % Extract numeric data from a column, handling special characters
            raw = datos{:, colIdx};
            if isnumeric(raw)
                y = raw;
            elseif iscell(raw)
                y = zeros(size(raw));
                for k = 1:length(raw)
                    val = raw{k};
                    if isnumeric(val)
                        y(k) = val;
                    elseif ischar(val) || isstring(val)
                        val = regexprep(char(val), '^#', '');
                        val = strtrim(val);
                        if isempty(val) || strcmp(val, '***') || strcmp(val, '-')
                            y(k) = NaN;
                        else
                            y(k) = str2double(val);
                        end
                    else
                        y(k) = NaN;
                    end
                end
            else
                y = double(raw);
            end
        end

        function plotRecruitmentData(app, datos, meta)
            % Visualize Recruitment maneuver data

            % Clear all axes
            cla(app.AxesPressure);
            cla(app.AxesFlow);
            cla(app.AxesVolume);
            cla(app.AxesLoop);

            n = height(datos);
            x = 1:n;

            % Get PEEP and Cdyn columns
            peep = datos.PEEP_cmH2O;
            cdyn = datos.Cdyn_mL_cmH2O;

            % Plot 1: Cdyn over time
            plot(app.AxesPressure, x, cdyn, 'b.-', 'LineWidth', 1.5, 'MarkerSize', 8);
            ylabel(app.AxesPressure, 'Cdyn (mL/cmH2O)');
            title(app.AxesPressure, 'Compliance durante Reclutamiento', 'FontWeight', 'bold');
            grid(app.AxesPressure, 'on');

            % Plot 2: PEEP over time
            plot(app.AxesFlow, x, peep, 'g.-', 'LineWidth', 1.5, 'MarkerSize', 8);
            ylabel(app.AxesFlow, 'PEEP (cmH2O)');
            title(app.AxesFlow, 'Escalón de PEEP', 'FontWeight', 'bold');
            grid(app.AxesFlow, 'on');

            % Plot 3: Pressure (Pei)
            if ismember('Pei_cmH2O', datos.Properties.VariableNames)
                pei = datos.Pei_cmH2O;
                plot(app.AxesVolume, x, pei, 'r.-', 'LineWidth', 1.5, 'MarkerSize', 8);
                ylabel(app.AxesVolume, 'Pei (cmH2O)');
                xlabel(app.AxesVolume, 'Paso #');
                title(app.AxesVolume, 'Presión Inspiratoria', 'FontWeight', 'bold');
                grid(app.AxesVolume, 'on');
            end

            % Plot 4: Cdyn vs PEEP curve (main recruitment curve)
            scatter(app.AxesLoop, peep, cdyn, 80, x, 'filled');
            hold(app.AxesLoop, 'on');
            plot(app.AxesLoop, peep, cdyn, 'k-', 'LineWidth', 1);

            % Mark optimal PEEP
            if isfield(meta, 'PEEPoptimo')
                xline(app.AxesLoop, meta.PEEPoptimo, 'r--', 'LineWidth', 2);
                text(app.AxesLoop, meta.PEEPoptimo + 0.5, meta.CdynMax * 0.9, ...
                    sprintf('PEEP óptimo\n%.0f cmH2O', meta.PEEPoptimo), ...
                    'Color', 'r', 'FontWeight', 'bold');
            end

            hold(app.AxesLoop, 'off');
            xlabel(app.AxesLoop, 'PEEP (cmH2O)');
            ylabel(app.AxesLoop, 'Cdyn (mL/cmH2O)');
            title(app.AxesLoop, 'Curva de Reclutamiento', 'FontWeight', 'bold');
            colorbar(app.AxesLoop);
            grid(app.AxesLoop, 'on');
        end

        function updateSummaryTable(app)
            % Update summary table with statistics for all variables
            if isempty(app.DatosResp)
                return;
            end

            datos = app.DatosResp;
            varNames = datos.Properties.VariableNames;

            % Prepare table data
            tableData = cell(0, 6);

            for i = 1:length(varNames)
                varName = varNames{i};
                col = datos{:, i};

                % Extract numeric values
                if isnumeric(col)
                    numVals = col;
                elseif iscell(col)
                    numVals = app.extractColumnData(datos, i);
                else
                    continue;
                end

                % Calculate statistics
                validVals = numVals(~isnan(numVals));
                if isempty(validVals)
                    continue;
                end

                tableData{end+1, 1} = varName;
                tableData{end, 2} = sprintf('%.2f', min(validVals));
                tableData{end, 3} = sprintf('%.2f', max(validVals));
                tableData{end, 4} = sprintf('%.2f', mean(validVals));
                tableData{end, 5} = sprintf('%.2f', std(validVals));
                tableData{end, 6} = sprintf('%d', length(validVals));
            end

            app.SummaryTable.Data = tableData;
        end

        function updateVariableDropdowns(app)
            % Populate variable dropdowns with available columns
            if isempty(app.DatosResp)
                return;
            end

            varNames = app.DatosResp.Properties.VariableNames;

            % Filter to numeric columns only
            numericVars = {};
            for i = 1:length(varNames)
                col = app.DatosResp{:, i};
                if isnumeric(col) || iscell(col)
                    numericVars{end+1} = varNames{i};
                end
            end

            if isempty(numericVars)
                numericVars = {'(Sin datos)'};
            end

            % Set items for all dropdowns
            app.Var1Dropdown.Items = numericVars;
            app.Var2Dropdown.Items = numericVars;
            app.Var3Dropdown.Items = numericVars;
            app.Var4Dropdown.Items = numericVars;

            % Set default values based on number of available variables
            nVars = length(numericVars);
            app.Var1Dropdown.Value = numericVars{min(1, nVars)};
            app.Var2Dropdown.Value = numericVars{min(2, nVars)};
            app.Var3Dropdown.Value = numericVars{min(3, nVars)};
            app.Var4Dropdown.Value = numericVars{min(4, nVars)};

            % Plot selected variables
            plotSelectedVariables(app);

            % Also update P-V and Trends tabs
            updateLoopTab(app);
            updateTrendsTab(app);
        end

        function plotSelectedVariables(app)
            % Plot variables selected in dropdowns
            if isempty(app.DatosResp)
                return;
            end

            n = height(app.DatosResp);
            x = 1:n;

            % Plot each variable
            plotVar(app, app.AxesPressure, app.Var1Dropdown.Value, x, 'b');
            plotVar(app, app.AxesFlow, app.Var2Dropdown.Value, x, 'g');
            plotVar(app, app.AxesVolume, app.Var3Dropdown.Value, x, [0.8 0.4 0]);
            plotVar(app, app.AxesLoop, app.Var4Dropdown.Value, x, 'r');
        end

        function plotVar(app, ax, varName, x, color)
            % Plot a single variable in the specified axes
            cla(ax);

            if strcmp(varName, '(Cargar datos)') || strcmp(varName, '(Sin variables)')
                return;
            end

            % Find column
            idx = find(strcmp(app.DatosResp.Properties.VariableNames, varName), 1);
            if isempty(idx)
                return;
            end

            y = app.extractColumnData(app.DatosResp, idx);
            valid = ~isnan(y);

            if any(valid)
                plot(ax, x(valid), y(valid), '.-', 'Color', color, 'LineWidth', 1, 'MarkerSize', 4);
                title(ax, strrep(varName, '_', ' '), 'FontWeight', 'bold');
                xlabel(ax, 'Registro #');
                grid(ax, 'on');
            end
        end

        function updateLoopTab(app)
            % Update P-V Loop tab
            cla(app.AxesTrend1);

            if isempty(app.DatosResp)
                return;
            end

            varNames = lower(app.DatosResp.Properties.VariableNames);

            % Try to find pressure and volume columns
            presCol = find(contains(varNames, 'presion') | contains(varNames, 'pei') | contains(varNames, 'peep'), 1);
            volCol = find(contains(varNames, 'volumen') | contains(varNames, 'vci') | contains(varNames, 'vce'), 1);

            if ~isempty(presCol) && ~isempty(volCol)
                pres = app.extractColumnData(app.DatosResp, presCol);
                vol = app.extractColumnData(app.DatosResp, volCol);
                valid = ~isnan(pres) & ~isnan(vol);

                if any(valid)
                    scatter(app.AxesTrend1, pres(valid), vol(valid), 20, find(valid), 'filled');
                    xlabel(app.AxesTrend1, 'Presión (cmH2O)');
                    ylabel(app.AxesTrend1, 'Volumen (mL)');
                    title(app.AxesTrend1, 'Loop Presión-Volumen', 'FontWeight', 'bold');
                    colorbar(app.AxesTrend1);
                    grid(app.AxesTrend1, 'on');
                end
            else
                title(app.AxesTrend1, 'No se encontraron variables de Presión/Volumen', 'FontWeight', 'bold');
            end
        end

        function updateTrendsTab(app)
            % Update Trends/Evolution tab
            cla(app.AxesTrend2);

            if isempty(app.DatosResp)
                return;
            end

            n = height(app.DatosResp);
            x = 1:n;

            % Plot first 3 numeric variables on same axes
            varNames = app.DatosResp.Properties.VariableNames;
            colors = {'b', 'r', 'g', 'm', 'c'};
            legends = {};
            hold(app.AxesTrend2, 'on');

            plotCount = 0;
            for i = 1:min(5, length(varNames))
                col = app.DatosResp{:, i};
                if isnumeric(col) || iscell(col)
                    y = app.extractColumnData(app.DatosResp, i);
                    valid = ~isnan(y);
                    if any(valid)
                        plotCount = plotCount + 1;
                        plot(app.AxesTrend2, x(valid), y(valid), 'Color', colors{plotCount}, 'LineWidth', 1);
                        legends{end+1} = strrep(varNames{i}, '_', ' ');
                        if plotCount >= 5
                            break;
                        end
                    end
                end
            end

            hold(app.AxesTrend2, 'off');
            if ~isempty(legends)
                legend(app.AxesTrend2, legends, 'Location', 'best');
            end
            xlabel(app.AxesTrend2, 'Registro #');
            title(app.AxesTrend2, 'Evolución Temporal', 'FontWeight', 'bold');
            grid(app.AxesTrend2, 'on');
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Add required paths automatically
            baseDir = fileparts(mfilename('fullpath'));
            addpath(fullfile(baseDir, 'src', 'loaders'));
            addpath(fullfile(baseDir, 'src', 'analysis'));
            addpath(fullfile(baseDir, 'tests'));

            app.CurrentFileType = 'recordings';
            scanFiles(app);
        end

        % File type changed
        function FileTypeDropDownValueChanged(app, ~)
            scanFiles(app);
        end

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, ~)
            if isempty(app.RecordingDropDown.Value)
                return;
            end

            app.StatusLabel.Text = 'Cargando...';
            drawnow;

            % Get selected file
            selectedFile = fullfile(app.DataDir, app.RecordingDropDown.Value);

            try
                switch app.CurrentFileType
                    case 'recordings'
                        % Load recording data
                        [app.Metadatos, app.DatosResp] = cargarRecording(app, selectedFile);

                        % Convert time
                        app.TiempoSeg = convertirTiempoASegundos(app, app.DatosResp.Tiempo);
                        app.TiempoSeg = app.TiempoSeg - app.TiempoSeg(1);
                        app.MaxTiempo = max(app.TiempoSeg);

                        % Update slider limits
                        app.TimeSlider.Limits = [0, max(0.1, app.MaxTiempo - app.WindowSpinner.Value)];
                        app.TimeSlider.Value = 0;

                        % Update display
                        updateMetadataDisplay(app);
                        updatePlots(app);

                        % Update tabs with data
                        updateSummaryTable(app);
                        updateVariableDropdowns(app);

                        app.StatusLabel.Text = sprintf('Cargado: %d muestras (%.1f s)', ...
                            height(app.DatosResp), app.MaxTiempo);

                    case 'trends'
                        % Load trends using external function
                        [meta, datos] = cargarTrends(selectedFile);
                        app.Metadatos = meta;
                        app.DatosResp = datos;
                        app.TiempoSeg = [];
                        app.MaxTiempo = 0;

                        % Update tabs with data
                        updateSummaryTable(app);
                        updateVariableDropdowns(app);
                        plotTrendsData(app, datos);
                        app.StatusLabel.Text = sprintf('Trends cargado: %d registros', height(datos));

                    case 'recruitments'
                        % Load recruitment using external function
                        [meta, datos] = cargarRecruitment(selectedFile);
                        app.Metadatos = meta;
                        app.DatosResp = datos;
                        app.TiempoSeg = [];
                        app.MaxTiempo = 0;

                        % Update tabs with data
                        updateSummaryTable(app);
                        updateVariableDropdowns(app);
                        plotRecruitmentData(app, datos, meta);
                        app.StatusLabel.Text = sprintf('Reclutamiento: PEEP óptimo = %.1f cmH2O, Cdyn max = %.1f', ...
                            meta.PEEPoptimo, meta.CdynMax);
                end
            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

        % Calculate mechanics button
        function CalcMechanicsButtonPushed(app, ~)
            if isempty(app.DatosResp) || isempty(app.TiempoSeg)
                app.StatusLabel.Text = 'Primero cargue una grabación';
                return;
            end

            app.StatusLabel.Text = 'Calculando mecánica respiratoria...';
            drawnow;

            try
                % Detect cycles
                app.Ciclos = detectarCiclosRespiratorios(app.DatosResp, app.TiempoSeg);

                % Calculate mechanics
                app.Mecanica = calcularMecanicaRespiratoria(app.Ciclos, app.Metadatos);

                % Update display
                updateMechanicsDisplay(app);

                app.StatusLabel.Text = sprintf('Mecánica calculada: %d ciclos analizados', ...
                    app.Mecanica.nCiclos);
            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

        % Export button
        function ExportButtonPushed(app, ~)
            if isempty(app.DatosResp)
                app.StatusLabel.Text = 'No hay datos para exportar';
                return;
            end

            % Select output file
            [file, path] = uiputfile({'*.xlsx', 'Excel (*.xlsx)'; ...
                '*.csv', 'CSV (*.csv)'; ...
                '*.mat', 'MATLAB (*.mat)'}, ...
                'Guardar datos como...');
            if file == 0
                return;
            end

            fullPath = fullfile(path, file);

            try
                [~, ~, ext] = fileparts(fullPath);
                switch ext
                    case '.xlsx'
                        writetable(app.DatosResp, fullPath);
                        if ~isempty(app.Mecanica)
                            mecTable = struct2table(app.Mecanica.media);
                            writetable(mecTable, fullPath, 'Sheet', 'Mecanica');
                        end
                    case '.csv'
                        writetable(app.DatosResp, fullPath);
                    case '.mat'
                        datosExport = struct();
                        datosExport.datos = app.DatosResp;
                        datosExport.metadatos = app.Metadatos;
                        datosExport.mecanica = app.Mecanica;
                        datosExport.ciclos = app.Ciclos;
                        save(fullPath, '-struct', 'datosExport');
                end
                app.StatusLabel.Text = sprintf('Exportado: %s', file);
            catch ME
                app.StatusLabel.Text = ['Error exportando: ' ME.message];
            end
        end

        % Value changed function: TimeSlider
        function TimeSliderValueChanged(app, ~)
            updatePlots(app);
        end

        % Value changed function: WindowSpinner
        function WindowSpinnerValueChanged(app, ~)
            if ~isempty(app.MaxTiempo)
                app.TimeSlider.Limits = [0, max(0.1, app.MaxTiempo - app.WindowSpinner.Value)];
                if app.TimeSlider.Value > app.TimeSlider.Limits(2)
                    app.TimeSlider.Value = app.TimeSlider.Limits(2);
                end
            end
            updatePlots(app);
        end

        % Loop dropdown changed
        function LoopDropDownValueChanged(app, ~)
            if ~isempty(app.DatosResp) && ~isempty(app.TiempoSeg)
                updatePlots(app);
            end
        end

        % Variable dropdown changed (Curvas tab)
        function VarDropdownChanged(app, ~)
            if ~isempty(app.DatosResp)
                plotSelectedVariables(app);
            end
        end

    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1500 900];
            app.UIFigure.Name = 'Visor Avanzado - Ventilador SERVO-U';
            app.UIFigure.Color = [0.94 0.94 0.94];

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {300, '1x'};
            app.GridLayout.RowHeight = {'1x', 50};
            app.GridLayout.ColumnSpacing = 5;
            app.GridLayout.RowSpacing = 5;
            app.GridLayout.Padding = [10 10 10 10];

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Configuración';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.BackgroundColor = [1 1 1];
            app.LeftPanel.Scrollable = 'on';

            % File type selector
            app.FileTypeLabel = uilabel(app.LeftPanel);
            app.FileTypeLabel.Position = [10 750 200 22];
            app.FileTypeLabel.Text = 'Tipo de archivo:';
            app.FileTypeLabel.FontWeight = 'bold';

            app.FileTypeDropDown = uidropdown(app.LeftPanel);
            app.FileTypeDropDown.Items = {'Grabaciones', 'Tendencias', 'Reclutamiento'};
            app.FileTypeDropDown.Position = [10 720 270 25];
            app.FileTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @FileTypeDropDownValueChanged, true);

            % Recording selection controls
            app.RecordingDropDownLabel = uilabel(app.LeftPanel);
            app.RecordingDropDownLabel.Position = [10 685 200 22];
            app.RecordingDropDownLabel.Text = 'Seleccionar Archivo:';
            app.RecordingDropDownLabel.FontWeight = 'bold';

            app.RecordingDropDown = uidropdown(app.LeftPanel);
            app.RecordingDropDown.Items = {'Cargando...'};
            app.RecordingDropDown.Position = [10 655 270 25];

            app.LoadButton = uibutton(app.LeftPanel, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [10 615 130 30];
            app.LoadButton.Text = '📂 Cargar';
            app.LoadButton.FontWeight = 'bold';
            app.LoadButton.BackgroundColor = [0.3 0.6 0.9];
            app.LoadButton.FontColor = [1 1 1];

            app.ExportButton = uibutton(app.LeftPanel, 'push');
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportButtonPushed, true);
            app.ExportButton.Position = [150 615 130 30];
            app.ExportButton.Text = '💾 Exportar';
            app.ExportButton.FontWeight = 'bold';
            app.ExportButton.BackgroundColor = [0.4 0.7 0.4];
            app.ExportButton.FontColor = [1 1 1];

            % Create MetadataPanel
            app.MetadataPanel = uipanel(app.LeftPanel);
            app.MetadataPanel.Title = 'Parámetros del Ventilador';
            app.MetadataPanel.Position = [10 400 270 200];
            app.MetadataPanel.FontWeight = 'bold';
            app.MetadataPanel.BackgroundColor = [0.95 0.97 1];

            % Create metadata labels
            yPos = 155;
            yStep = 24;

            app.ModoLabel = uilabel(app.MetadataPanel);
            app.ModoLabel.Position = [10 yPos 70 22];
            app.ModoLabel.Text = 'Modo:';
            app.ModoLabel.FontWeight = 'bold';
            app.ModoValue = uilabel(app.MetadataPanel);
            app.ModoValue.Position = [80 yPos 180 22];
            app.ModoValue.Text = '-';
            yPos = yPos - yStep;

            app.VtLabel = uilabel(app.MetadataPanel);
            app.VtLabel.Position = [10 yPos 70 22];
            app.VtLabel.Text = 'Vt:';
            app.VtLabel.FontWeight = 'bold';
            app.VtValue = uilabel(app.MetadataPanel);
            app.VtValue.Position = [80 yPos 100 22];
            app.VtValue.Text = '-';
            yPos = yPos - yStep;

            app.PEEPLabel = uilabel(app.MetadataPanel);
            app.PEEPLabel.Position = [10 yPos 70 22];
            app.PEEPLabel.Text = 'PEEP:';
            app.PEEPLabel.FontWeight = 'bold';
            app.PEEPValue = uilabel(app.MetadataPanel);
            app.PEEPValue.Position = [80 yPos 100 22];
            app.PEEPValue.Text = '-';
            yPos = yPos - yStep;

            app.FRLabel = uilabel(app.MetadataPanel);
            app.FRLabel.Position = [10 yPos 70 22];
            app.FRLabel.Text = 'FR:';
            app.FRLabel.FontWeight = 'bold';
            app.FRValue = uilabel(app.MetadataPanel);
            app.FRValue.Position = [80 yPos 100 22];
            app.FRValue.Text = '-';
            yPos = yPos - yStep;

            app.FiO2Label = uilabel(app.MetadataPanel);
            app.FiO2Label.Position = [10 yPos 70 22];
            app.FiO2Label.Text = 'FiO2:';
            app.FiO2Label.FontWeight = 'bold';
            app.FiO2Value = uilabel(app.MetadataPanel);
            app.FiO2Value.Position = [80 yPos 100 22];
            app.FiO2Value.Text = '-';
            yPos = yPos - yStep;

            app.IELabel = uilabel(app.MetadataPanel);
            app.IELabel.Position = [10 yPos 70 22];
            app.IELabel.Text = 'I:E:';
            app.IELabel.FontWeight = 'bold';
            app.IEValue = uilabel(app.MetadataPanel);
            app.IEValue.Position = [80 yPos 100 22];
            app.IEValue.Text = '-';
            yPos = yPos - yStep;

            app.DurationLabel = uilabel(app.MetadataPanel);
            app.DurationLabel.Position = [10 yPos 70 22];
            app.DurationLabel.Text = 'Duración:';
            app.DurationLabel.FontWeight = 'bold';
            app.DurationValue = uilabel(app.MetadataPanel);
            app.DurationValue.Position = [80 yPos 100 22];
            app.DurationValue.Text = '-';

            % Create MechanicsPanel
            app.MechanicsPanel = uipanel(app.LeftPanel);
            app.MechanicsPanel.Title = 'Mecánica Respiratoria';
            app.MechanicsPanel.Position = [10 210 270 180];
            app.MechanicsPanel.FontWeight = 'bold';
            app.MechanicsPanel.BackgroundColor = [0.97 0.95 1];

            app.CalcMechanicsButton = uibutton(app.MechanicsPanel, 'push');
            app.CalcMechanicsButton.ButtonPushedFcn = createCallbackFcn(app, @CalcMechanicsButtonPushed, true);
            app.CalcMechanicsButton.Position = [10 130 250 25];
            app.CalcMechanicsButton.Text = '🔬 Calcular Mecánica';
            app.CalcMechanicsButton.FontWeight = 'bold';
            app.CalcMechanicsButton.BackgroundColor = [0.6 0.4 0.8];
            app.CalcMechanicsButton.FontColor = [1 1 1];

            yPos = 100;
            yStep = 22;

            app.CstLabel = uilabel(app.MechanicsPanel);
            app.CstLabel.Position = [10 yPos 80 22];
            app.CstLabel.Text = 'Cst:';
            app.CstLabel.FontWeight = 'bold';
            app.CstValue = uilabel(app.MechanicsPanel);
            app.CstValue.Position = [90 yPos 160 22];
            app.CstValue.Text = '-';
            yPos = yPos - yStep;

            app.CdynLabel = uilabel(app.MechanicsPanel);
            app.CdynLabel.Position = [10 yPos 80 22];
            app.CdynLabel.Text = 'Cdyn:';
            app.CdynLabel.FontWeight = 'bold';
            app.CdynValue = uilabel(app.MechanicsPanel);
            app.CdynValue.Position = [90 yPos 160 22];
            app.CdynValue.Text = '-';
            yPos = yPos - yStep;

            app.RawLabel = uilabel(app.MechanicsPanel);
            app.RawLabel.Position = [10 yPos 80 22];
            app.RawLabel.Text = 'Raw:';
            app.RawLabel.FontWeight = 'bold';
            app.RawValue = uilabel(app.MechanicsPanel);
            app.RawValue.Position = [90 yPos 160 22];
            app.RawValue.Text = '-';
            yPos = yPos - yStep;

            app.DrivingPLabel = uilabel(app.MechanicsPanel);
            app.DrivingPLabel.Position = [10 yPos 80 22];
            app.DrivingPLabel.Text = 'ΔP:';
            app.DrivingPLabel.FontWeight = 'bold';
            app.DrivingPValue = uilabel(app.MechanicsPanel);
            app.DrivingPValue.Position = [90 yPos 160 22];
            app.DrivingPValue.Text = '-';
            yPos = yPos - yStep;

            app.WOBLabel = uilabel(app.MechanicsPanel);
            app.WOBLabel.Position = [10 yPos 80 22];
            app.WOBLabel.Text = 'WOB:';
            app.WOBLabel.FontWeight = 'bold';
            app.WOBValue = uilabel(app.MechanicsPanel);
            app.WOBValue.Position = [90 yPos 160 22];
            app.WOBValue.Text = '-';

            % Loop configuration
            app.LoopXLabel = uilabel(app.LeftPanel);
            app.LoopXLabel.Position = [10 175 60 22];
            app.LoopXLabel.Text = 'Loop X:';
            app.LoopXLabel.FontWeight = 'bold';

            app.LoopXDropDown = uidropdown(app.LeftPanel);
            app.LoopXDropDown.Items = {'Presión', 'Flujo', 'Volumen', 'Tiempo'};
            app.LoopXDropDown.Value = 'Presión';
            app.LoopXDropDown.Position = [70 175 80 22];
            app.LoopXDropDown.ValueChangedFcn = createCallbackFcn(app, @LoopDropDownValueChanged, true);

            app.LoopYLabel = uilabel(app.LeftPanel);
            app.LoopYLabel.Position = [160 175 30 22];
            app.LoopYLabel.Text = 'Y:';
            app.LoopYLabel.FontWeight = 'bold';

            app.LoopYDropDown = uidropdown(app.LeftPanel);
            app.LoopYDropDown.Items = {'Presión', 'Flujo', 'Volumen', 'Tiempo'};
            app.LoopYDropDown.Value = 'Volumen';
            app.LoopYDropDown.Position = [190 175 80 22];
            app.LoopYDropDown.ValueChangedFcn = createCallbackFcn(app, @LoopDropDownValueChanged, true);

            % Time window controls
            app.WindowSpinnerLabel = uilabel(app.LeftPanel);
            app.WindowSpinnerLabel.Position = [10 135 150 22];
            app.WindowSpinnerLabel.Text = 'Ventana temporal (s):';
            app.WindowSpinnerLabel.FontWeight = 'bold';

            app.WindowSpinner = uispinner(app.LeftPanel);
            app.WindowSpinner.Limits = [1 60];
            app.WindowSpinner.Value = 10;
            app.WindowSpinner.Position = [160 135 70 22];
            app.WindowSpinner.ValueChangedFcn = createCallbackFcn(app, @WindowSpinnerValueChanged, true);

            app.TimeSliderLabel = uilabel(app.LeftPanel);
            app.TimeSliderLabel.Position = [10 100 200 22];
            app.TimeSliderLabel.Text = 'Navegar en el tiempo:';
            app.TimeSliderLabel.FontWeight = 'bold';

            app.TimeSlider = uislider(app.LeftPanel);
            app.TimeSlider.Limits = [0 100];
            app.TimeSlider.Position = [10 85 260 3];
            app.TimeSlider.ValueChangedFcn = createCallbackFcn(app, @TimeSliderValueChanged, true);

            % Create RightPanel for plots
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Visualización de Datos';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';
            app.RightPanel.BackgroundColor = [1 1 1];

            % Create TabGroup inside RightPanel
            app.TabGroup = uitabgroup(app.RightPanel);
            app.TabGroup.Position = [5 5 1140 760];

            % ========== TAB 1: RESUMEN ==========
            app.TabResumen = uitab(app.TabGroup);
            app.TabResumen.Title = 'Resumen';
            app.TabResumen.BackgroundColor = [0.98 0.98 1];

            % Create summary table
            app.SummaryTable = uitable(app.TabResumen);
            app.SummaryTable.Position = [20 20 1100 700];
            app.SummaryTable.ColumnName = {'Variable', 'Min', 'Max', 'Media', 'Desv.Est', 'N válidos'};
            app.SummaryTable.ColumnWidth = {250, 100, 100, 100, 100, 100};
            app.SummaryTable.RowName = {};

            % ========== TAB 2: CURVAS ==========
            app.TabCurvas = uitab(app.TabGroup);
            app.TabCurvas.Title = 'Curvas';
            app.TabCurvas.BackgroundColor = [1 1 1];

            % Variable dropdowns for Curvas tab
            uilabel(app.TabCurvas, 'Position', [20 720 60 22], 'Text', 'Var 1:', 'FontWeight', 'bold');
            app.Var1Dropdown = uidropdown(app.TabCurvas);
            app.Var1Dropdown.Items = {'(Cargar datos)'};
            app.Var1Dropdown.Position = [80 720 200 22];
            app.Var1Dropdown.ValueChangedFcn = createCallbackFcn(app, @VarDropdownChanged, true);

            uilabel(app.TabCurvas, 'Position', [300 720 60 22], 'Text', 'Var 2:', 'FontWeight', 'bold');
            app.Var2Dropdown = uidropdown(app.TabCurvas);
            app.Var2Dropdown.Items = {'(Cargar datos)'};
            app.Var2Dropdown.Position = [360 720 200 22];
            app.Var2Dropdown.ValueChangedFcn = createCallbackFcn(app, @VarDropdownChanged, true);

            uilabel(app.TabCurvas, 'Position', [580 720 60 22], 'Text', 'Var 3:', 'FontWeight', 'bold');
            app.Var3Dropdown = uidropdown(app.TabCurvas);
            app.Var3Dropdown.Items = {'(Cargar datos)'};
            app.Var3Dropdown.Position = [640 720 200 22];
            app.Var3Dropdown.ValueChangedFcn = createCallbackFcn(app, @VarDropdownChanged, true);

            uilabel(app.TabCurvas, 'Position', [860 720 60 22], 'Text', 'Var 4:', 'FontWeight', 'bold');
            app.Var4Dropdown = uidropdown(app.TabCurvas);
            app.Var4Dropdown.Items = {'(Cargar datos)'};
            app.Var4Dropdown.Position = [920 720 200 22];
            app.Var4Dropdown.ValueChangedFcn = createCallbackFcn(app, @VarDropdownChanged, true);

            % Create 4 axes in Curvas tab (2x2 grid)
            app.AxesPressure = uiaxes(app.TabCurvas);
            app.AxesPressure.Position = [20 380 530 320];
            title(app.AxesPressure, 'Variable 1');
            app.AxesPressure.XGrid = 'on';
            app.AxesPressure.YGrid = 'on';

            app.AxesFlow = uiaxes(app.TabCurvas);
            app.AxesFlow.Position = [580 380 530 320];
            title(app.AxesFlow, 'Variable 2');
            app.AxesFlow.XGrid = 'on';
            app.AxesFlow.YGrid = 'on';

            app.AxesVolume = uiaxes(app.TabCurvas);
            app.AxesVolume.Position = [20 30 530 320];
            title(app.AxesVolume, 'Variable 3');
            app.AxesVolume.XGrid = 'on';
            app.AxesVolume.YGrid = 'on';

            app.AxesLoop = uiaxes(app.TabCurvas);
            app.AxesLoop.Position = [580 30 530 320];
            title(app.AxesLoop, 'Variable 4');
            app.AxesLoop.XGrid = 'on';
            app.AxesLoop.YGrid = 'on';

            % ========== TAB 3: LOOPS ==========
            app.TabLoops = uitab(app.TabGroup);
            app.TabLoops.Title = 'Loops P-V';
            app.TabLoops.BackgroundColor = [1 1 1];

            % Large P-V loop axes
            app.AxesTrend1 = uiaxes(app.TabLoops);
            app.AxesTrend1.Position = [50 50 1050 680];
            title(app.AxesTrend1, 'Loop Presión-Volumen');
            xlabel(app.AxesTrend1, 'Presión (cmH2O)');
            ylabel(app.AxesTrend1, 'Volumen (mL)');
            app.AxesTrend1.XGrid = 'on';
            app.AxesTrend1.YGrid = 'on';

            % ========== TAB 4: TENDENCIAS ==========
            app.TabTendencias = uitab(app.TabGroup);
            app.TabTendencias.Title = 'Tendencias';
            app.TabTendencias.BackgroundColor = [1 1 1];

            % Trend axes (2 stacked)
            app.AxesTrend2 = uiaxes(app.TabTendencias);
            app.AxesTrend2.Position = [50 50 1050 680];
            title(app.AxesTrend2, 'Evolución Temporal');
            xlabel(app.AxesTrend2, 'Tiempo');
            app.AxesTrend2.XGrid = 'on';
            app.AxesTrend2.YGrid = 'on';

            % Create ControlPanel (status bar)
            app.ControlPanel = uipanel(app.GridLayout);
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = [1 2];
            app.ControlPanel.BackgroundColor = [0.2 0.2 0.3];

            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Position = [10 15 1200 22];
            app.StatusLabel.Text = 'Listo. Seleccione un tipo de archivo y pulse Cargar.';
            app.StatusLabel.FontColor = [1 1 1];
            app.StatusLabel.FontWeight = 'bold';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = VentilatorRecordingViewer

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
