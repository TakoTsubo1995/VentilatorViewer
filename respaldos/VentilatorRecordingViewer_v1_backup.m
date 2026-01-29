classdef VentilatorRecordingViewer < matlab.apps.AppBase

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
        AxesPVLoop                 matlab.ui.control.UIAxes
        ControlPanel               matlab.ui.container.Panel
        TimeSlider                 matlab.ui.control.Slider
        TimeSliderLabel            matlab.ui.control.Label
        WindowSpinner              matlab.ui.control.Spinner
        WindowSpinnerLabel         matlab.ui.control.Label
        StatusLabel                matlab.ui.control.Label
    end

    % Properties to store data
    properties (Access = private)
        DataDir                    % Directory with recordings
        Metadatos                  % Metadata structure
        DatosResp                  % Respiratory data table
        TiempoSeg                  % Time in seconds
        MaxTiempo                  % Maximum time
    end

    methods (Access = private)

        function scanRecordings(app)
            % Scan for available recording files
            app.DataDir = fullfile(fileparts(mfilename('fullpath')), 'ventilatorData', 'recordings');
            
            if ~isfolder(app.DataDir)
                app.StatusLabel.Text = 'Error: No se encontró carpeta de recordings';
                return;
            end
            
            files = dir(fullfile(app.DataDir, '*.txt'));
            
            if isempty(files)
                app.StatusLabel.Text = 'No se encontraron archivos de grabación';
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
            app.StatusLabel.Text = sprintf('%d grabaciones disponibles', length(files));
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
            
            % Plot P-V Loop
            cla(app.AxesPVLoop);
            hold(app.AxesPVLoop, 'on');
            
            % Color by phase: insp=blue, esp=red, pausa=green
            isInsp = contains(fases, 'insp');
            isEsp = contains(fases, 'esp');
            isPausa = contains(fases, 'pausa');
            
            % Plot each phase with different color
            if any(isInsp)
                plot(app.AxesPVLoop, presion(isInsp), volumen(isInsp), 'b.', 'MarkerSize', 4);
            end
            if any(isEsp)
                plot(app.AxesPVLoop, presion(isEsp), volumen(isEsp), 'r.', 'MarkerSize', 4);
            end
            if any(isPausa)
                plot(app.AxesPVLoop, presion(isPausa), volumen(isPausa), 'g.', 'MarkerSize', 4);
            end
            
            % Draw the loop as a continuous line
            plot(app.AxesPVLoop, presion, volumen, 'k-', 'LineWidth', 0.5, 'Color', [0.5 0.5 0.5]);
            
            hold(app.AxesPVLoop, 'off');
            xlabel(app.AxesPVLoop, 'Presión (cmH2O)');
            ylabel(app.AxesPVLoop, 'Volumen (mL)');
            title(app.AxesPVLoop, 'Loop P-V', 'FontWeight', 'bold');
            grid(app.AxesPVLoop, 'on');
            legend(app.AxesPVLoop, {'Insp', 'Esp', 'Pausa'}, 'Location', 'southeast', 'FontSize', 8);
            
            app.StatusLabel.Text = sprintf('Mostrando: %.1f - %.1f s', startTime, endTime);
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

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            scanRecordings(app);
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
                % Load data
                [app.Metadatos, app.DatosResp] = cargarRecording(app, selectedFile);
                
                % Convert time
                app.TiempoSeg = convertirTiempoASegundos(app, app.DatosResp.Tiempo);
                app.TiempoSeg = app.TiempoSeg - app.TiempoSeg(1);  % Start from 0
                app.MaxTiempo = max(app.TiempoSeg);
                
                % Update slider limits
                app.TimeSlider.Limits = [0, max(0.1, app.MaxTiempo - app.WindowSpinner.Value)];
                app.TimeSlider.Value = 0;
                
                % Update display
                updateMetadataDisplay(app);
                updatePlots(app);
                
                app.StatusLabel.Text = sprintf('Cargado: %d muestras (%.1f s)', ...
                    height(app.DatosResp), app.MaxTiempo);
            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
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

    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1400 800];
            app.UIFigure.Name = 'Visor de Grabaciones - Ventilador SERVO-U';
            app.UIFigure.Color = [0.94 0.94 0.94];

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {250, '1x'};
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

            % Create Recording selection controls
            app.RecordingDropDownLabel = uilabel(app.LeftPanel);
            app.RecordingDropDownLabel.Position = [10 520 200 22];
            app.RecordingDropDownLabel.Text = 'Seleccionar Grabación:';
            app.RecordingDropDownLabel.FontWeight = 'bold';

            app.RecordingDropDown = uidropdown(app.LeftPanel);
            app.RecordingDropDown.Items = {'Cargando...'};
            app.RecordingDropDown.Position = [10 490 220 25];

            app.LoadButton = uibutton(app.LeftPanel, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [10 455 220 30];
            app.LoadButton.Text = '📂 Cargar Grabación';
            app.LoadButton.FontWeight = 'bold';
            app.LoadButton.BackgroundColor = [0.3 0.6 0.9];
            app.LoadButton.FontColor = [1 1 1];

            % Create MetadataPanel
            app.MetadataPanel = uipanel(app.LeftPanel);
            app.MetadataPanel.Title = 'Parámetros del Ventilador';
            app.MetadataPanel.Position = [10 180 220 260];
            app.MetadataPanel.FontWeight = 'bold';
            app.MetadataPanel.BackgroundColor = [0.95 0.97 1];

            % Create metadata labels
            yPos = 210;
            yStep = 32;

            app.ModoLabel = uilabel(app.MetadataPanel);
            app.ModoLabel.Position = [10 yPos 80 22];
            app.ModoLabel.Text = 'Modo:';
            app.ModoLabel.FontWeight = 'bold';
            app.ModoValue = uilabel(app.MetadataPanel);
            app.ModoValue.Position = [90 yPos 120 22];
            app.ModoValue.Text = '-';
            yPos = yPos - yStep;

            app.VtLabel = uilabel(app.MetadataPanel);
            app.VtLabel.Position = [10 yPos 80 22];
            app.VtLabel.Text = 'Vt:';
            app.VtLabel.FontWeight = 'bold';
            app.VtValue = uilabel(app.MetadataPanel);
            app.VtValue.Position = [90 yPos 120 22];
            app.VtValue.Text = '-';
            yPos = yPos - yStep;

            app.PEEPLabel = uilabel(app.MetadataPanel);
            app.PEEPLabel.Position = [10 yPos 80 22];
            app.PEEPLabel.Text = 'PEEP:';
            app.PEEPLabel.FontWeight = 'bold';
            app.PEEPValue = uilabel(app.MetadataPanel);
            app.PEEPValue.Position = [90 yPos 120 22];
            app.PEEPValue.Text = '-';
            yPos = yPos - yStep;

            app.FRLabel = uilabel(app.MetadataPanel);
            app.FRLabel.Position = [10 yPos 80 22];
            app.FRLabel.Text = 'FR:';
            app.FRLabel.FontWeight = 'bold';
            app.FRValue = uilabel(app.MetadataPanel);
            app.FRValue.Position = [90 yPos 120 22];
            app.FRValue.Text = '-';
            yPos = yPos - yStep;

            app.FiO2Label = uilabel(app.MetadataPanel);
            app.FiO2Label.Position = [10 yPos 80 22];
            app.FiO2Label.Text = 'FiO2:';
            app.FiO2Label.FontWeight = 'bold';
            app.FiO2Value = uilabel(app.MetadataPanel);
            app.FiO2Value.Position = [90 yPos 120 22];
            app.FiO2Value.Text = '-';
            yPos = yPos - yStep;

            app.IELabel = uilabel(app.MetadataPanel);
            app.IELabel.Position = [10 yPos 80 22];
            app.IELabel.Text = 'I:E:';
            app.IELabel.FontWeight = 'bold';
            app.IEValue = uilabel(app.MetadataPanel);
            app.IEValue.Position = [90 yPos 120 22];
            app.IEValue.Text = '-';
            yPos = yPos - yStep;

            app.DurationLabel = uilabel(app.MetadataPanel);
            app.DurationLabel.Position = [10 yPos 80 22];
            app.DurationLabel.Text = 'Duración:';
            app.DurationLabel.FontWeight = 'bold';
            app.DurationValue = uilabel(app.MetadataPanel);
            app.DurationValue.Position = [90 yPos 120 22];
            app.DurationValue.Text = '-';

            % Time window controls
            app.WindowSpinnerLabel = uilabel(app.LeftPanel);
            app.WindowSpinnerLabel.Position = [10 140 150 22];
            app.WindowSpinnerLabel.Text = 'Ventana temporal (s):';
            app.WindowSpinnerLabel.FontWeight = 'bold';

            app.WindowSpinner = uispinner(app.LeftPanel);
            app.WindowSpinner.Limits = [1 60];
            app.WindowSpinner.Value = 10;
            app.WindowSpinner.Position = [160 140 70 22];
            app.WindowSpinner.ValueChangedFcn = createCallbackFcn(app, @WindowSpinnerValueChanged, true);

            app.TimeSliderLabel = uilabel(app.LeftPanel);
            app.TimeSliderLabel.Position = [10 100 200 22];
            app.TimeSliderLabel.Text = 'Navegar en el tiempo:';
            app.TimeSliderLabel.FontWeight = 'bold';

            app.TimeSlider = uislider(app.LeftPanel);
            app.TimeSlider.Limits = [0 100];
            app.TimeSlider.Position = [10 85 210 3];
            app.TimeSlider.ValueChangedFcn = createCallbackFcn(app, @TimeSliderValueChanged, true);

            % Create RightPanel for plots
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Curvas de Ventilación';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';
            app.RightPanel.BackgroundColor = [1 1 1];

            % Create Axes for Pressure (top-left)
            app.AxesPressure = uiaxes(app.RightPanel);
            app.AxesPressure.Position = [20 400 520 150];
            app.AxesPressure.XTickLabel = {};
            title(app.AxesPressure, 'Presión de Vía Aérea');
            ylabel(app.AxesPressure, 'Presión (cmH2O)');
            app.AxesPressure.XGrid = 'on';
            app.AxesPressure.YGrid = 'on';

            % Create Axes for Flow (middle-left)
            app.AxesFlow = uiaxes(app.RightPanel);
            app.AxesFlow.Position = [20 220 520 150];
            app.AxesFlow.XTickLabel = {};
            title(app.AxesFlow, 'Flujo');
            ylabel(app.AxesFlow, 'Flujo (L/min)');
            app.AxesFlow.XGrid = 'on';
            app.AxesFlow.YGrid = 'on';

            % Create Axes for Volume (bottom-left)
            app.AxesVolume = uiaxes(app.RightPanel);
            app.AxesVolume.Position = [20 40 520 150];
            title(app.AxesVolume, 'Volumen');
            xlabel(app.AxesVolume, 'Tiempo (s)');
            ylabel(app.AxesVolume, 'Volumen (mL)');
            app.AxesVolume.XGrid = 'on';
            app.AxesVolume.YGrid = 'on';

            % Create Axes for P-V Loop (right side, larger square)
            app.AxesPVLoop = uiaxes(app.RightPanel);
            app.AxesPVLoop.Position = [570 40 500 510];
            title(app.AxesPVLoop, 'Loop Presión-Volumen');
            xlabel(app.AxesPVLoop, 'Presión (cmH2O)');
            ylabel(app.AxesPVLoop, 'Volumen (mL)');
            app.AxesPVLoop.XGrid = 'on';
            app.AxesPVLoop.YGrid = 'on';

            % Create ControlPanel (status bar)
            app.ControlPanel = uipanel(app.GridLayout);
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = [1 2];
            app.ControlPanel.BackgroundColor = [0.2 0.2 0.3];

            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Position = [10 15 1100 22];
            app.StatusLabel.Text = 'Listo. Seleccione una grabación y pulse Cargar.';
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
