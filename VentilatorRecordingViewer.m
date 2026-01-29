classdef VentilatorRecordingViewer < matlab.apps.AppBase
    % VENTILATORRECORDINGVIEWER - Visor de datos respiratorios SERVO-U v2.0
    %
    % Sistema integrado con base de datos para visualizar:
    %   - Recordings (curvas en tiempo real ~100Hz)
    %   - Trends (datos por minuto)
    %   - BreathTrends (datos por respiracion)
    %   - Recruitments (maniobras de reclutamiento)
    %   - Logs (eventos del ventilador)
    %
    % Caracteristicas:
    %   - Navegacion por paciente/sesion/fecha
    %   - Pestanas adaptativas segun tipo de dato
    %   - Loops configurables (cualquier variable X vs Y)
    %   - Calculo de mecanica respiratoria
    %   - Exportacion de datos
    %
    % Uso:
    %   VentilatorRecordingViewer
    %
    % Ver tambien: procesarDatosNuevos, dbQuery, importarArchivo
    %
    % Autor: Proyecto Fisiologia Respiratoria
    % Fecha: 2026-01-29
    % Version: 2.0

    % =====================================================================
    % PROPIEDADES UI
    % =====================================================================
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout

        % Panel izquierdo - Navegacion
        LeftPanel                  matlab.ui.container.Panel
        PacienteDropDown           matlab.ui.control.DropDown
        PacienteLabel              matlab.ui.control.Label
        SesionListBox              matlab.ui.control.ListBox
        SesionLabel                matlab.ui.control.Label
        ArchivoListBox             matlab.ui.control.ListBox
        ArchivoLabel               matlab.ui.control.Label
        LoadButton                 matlab.ui.control.Button
        RefreshButton              matlab.ui.control.Button

        % Panel de metadatos
        MetadataPanel              matlab.ui.container.Panel
        InfoLabels                 struct

        % Panel derecho - Visualizacion
        RightPanel                 matlab.ui.container.Panel
        TabGroup                   matlab.ui.container.TabGroup

        % Pestanas comunes
        TabResumen                 matlab.ui.container.Tab
        SummaryTable               matlab.ui.control.Table

        % Pestanas para Recordings
        TabCurvas                  matlab.ui.container.Tab
        AxesPressure               matlab.ui.control.UIAxes
        AxesFlow                   matlab.ui.control.UIAxes
        AxesVolume                 matlab.ui.control.UIAxes
        TimeSlider                 matlab.ui.control.Slider
        WindowSpinner              matlab.ui.control.Spinner

        TabLoopRec                 matlab.ui.container.Tab
        AxesLoopRec                matlab.ui.control.UIAxes
        LoopXDropDown              matlab.ui.control.DropDown
        LoopYDropDown              matlab.ui.control.DropDown
        LoopPresetsPanel           matlab.ui.container.ButtonGroup

        TabMecanica                matlab.ui.container.Tab
        AxesMecanica               matlab.ui.control.UIAxes
        MechanicsTable             matlab.ui.control.Table
        CalcMechanicsButton        matlab.ui.control.Button

        % Pestanas para Trends
        TabEvolucion               matlab.ui.container.Tab
        AxesEvolucion              matlab.ui.control.UIAxes
        TrendCheckboxes            struct

        TabScatter                 matlab.ui.container.Tab
        AxesScatter                matlab.ui.control.UIAxes
        ScatterXDropDown           matlab.ui.control.DropDown
        ScatterYDropDown           matlab.ui.control.DropDown

        % Pestanas para Recruitment
        TabRecruitment             matlab.ui.container.Tab
        AxesRecruitCurve           matlab.ui.control.UIAxes
        AxesRecruitSteps           matlab.ui.control.UIAxes
        RecruitInfoPanel           matlab.ui.container.Panel

        % Pestanas para Logs
        TabLogs                    matlab.ui.container.Tab
        AxesTimeline               matlab.ui.control.UIAxes
        LogsTable                  matlab.ui.control.Table
        LogFilterPanel             matlab.ui.container.Panel

        % Barra de estado
        ControlPanel               matlab.ui.container.Panel
        StatusLabel                matlab.ui.control.Label
        ExportButton               matlab.ui.control.Button
        AssignButton               matlab.ui.control.Button
    end

    % =====================================================================
    % PROPIEDADES DE DATOS
    % =====================================================================
    properties (Access = private)
        DB                         % Estructura de base de datos
        SesionesDisponibles        % Cell array de sesiones
        ArchivosCargados           % Archivos en sesion actual

        DatosActuales              % Datos cargados actualmente
        TipoActual                 % Tipo de dato actual
        MetadatosActuales          % Metadatos del archivo actual

        TiempoSeg                  % Tiempo en segundos (recordings)
        MaxTiempo                  % Tiempo maximo
        Ciclos                     % Ciclos respiratorios detectados
        Mecanica                   % Resultados de mecanica
    end

    % =====================================================================
    % METODOS PRIVADOS - NAVEGACION
    % =====================================================================
    methods (Access = private)

        function inicializarDB(app)
            % Inicializa conexion con la base de datos
            try
                app.DB = dbInit();
                app.StatusLabel.Text = 'Base de datos inicializada';
            catch ME
                app.StatusLabel.Text = ['Error DB: ' ME.message];
                app.DB = struct();
            end
        end

        function cargarPacientes(app)
            % Carga lista de pacientes disponibles
            try
                resultados = dbQuery();

                % Extraer pacientes unicos
                pacientes = {'Todos'};
                if ~isempty(resultados.pacientes)
                    for i = 1:length(resultados.pacientes)
                        pacientes{end+1} = resultados.pacientes{i}.nombre;
                    end
                end
                pacientes{end+1} = 'Sin asignar';

                app.PacienteDropDown.Items = pacientes;
                app.PacienteDropDown.Value = 'Todos';

                % Cargar sesiones
                cargarSesiones(app);

            catch ME
                app.StatusLabel.Text = ['Error cargando pacientes: ' ME.message];
            end
        end

        function cargarSesiones(app)
            % Carga sesiones segun paciente seleccionado
            try
                filtros = struct();
                paciente = app.PacienteDropDown.Value;

                if ~strcmp(paciente, 'Todos')
                    if strcmp(paciente, 'Sin asignar')
                        filtros.paciente = 'sin_asignar';
                    else
                        filtros.paciente = paciente;
                    end
                end

                resultados = dbQuery(filtros);
                app.SesionesDisponibles = resultados.sesiones;

                % Crear items para el listbox
                if isempty(app.SesionesDisponibles)
                    app.SesionListBox.Items = {'(Sin sesiones)'};
                    app.SesionListBox.ItemsData = {};
                else
                    items = cell(1, length(app.SesionesDisponibles));
                    for i = 1:length(app.SesionesDisponibles)
                        s = app.SesionesDisponibles{i};
                        fechaStr = datestr(s.fecha, 'dd/mm/yy');
                        items{i} = sprintf('%s - %s (%d arch)', ...
                            fechaStr, s.paciente, s.totalArchivos);
                    end
                    app.SesionListBox.Items = items;
                    app.SesionListBox.ItemsData = 1:length(items);
                end

                % Actualizar resumen
                app.StatusLabel.Text = sprintf('Sesiones: %d | Recordings: %d | Trends: %d', ...
                    length(app.SesionesDisponibles), ...
                    resultados.resumen.recordings, ...
                    resultados.resumen.trends);

                % Si hay sesiones, seleccionar la primera y cargar sus archivos
                if ~isempty(app.SesionesDisponibles)
                    app.SesionListBox.Value = 1;
                    cargarArchivos(app);
                else
                    app.ArchivoListBox.Items = {'(Sin sesiones disponibles)'};
                    app.ArchivoListBox.ItemsData = {};
                end

            catch ME
                app.StatusLabel.Text = ['Error cargando sesiones: ' ME.message];
            end
        end

        function cargarArchivos(app)
            % Carga archivos de la sesion seleccionada
            if isempty(app.SesionListBox.Value) || isempty(app.SesionesDisponibles)
                app.StatusLabel.Text = 'No hay sesion seleccionada';
                return;
            end

            idx = app.SesionListBox.Value;

            % Manejar caso donde Value es el texto en lugar del indice
            if ischar(idx) || isstring(idx)
                % Buscar el indice por nombre
                for k = 1:length(app.SesionListBox.Items)
                    if strcmp(app.SesionListBox.Items{k}, idx)
                        idx = k;
                        break;
                    end
                end
            end

            if ~isnumeric(idx) || idx < 1 || idx > length(app.SesionesDisponibles)
                app.StatusLabel.Text = sprintf('Indice invalido: %s', mat2str(idx));
                return;
            end

            sesion = app.SesionesDisponibles{idx};
            carpeta = sesion.carpeta;

            app.StatusLabel.Text = sprintf('Buscando en: %s', carpeta);

            % Buscar archivos .mat en subcarpetas
            app.ArchivosCargados = {};
            items = {};

            tipos = {'recordings', 'trends', 'breathtrends', 'recruitments', 'logs'};
            iconos = struct('recordings', 'REC', 'trends', 'TRE', ...
                'breathtrends', 'BTR', 'recruitments', 'RCT', 'logs', 'LOG');

            for i = 1:length(tipos)
                tipo = tipos{i};
                carpetaTipo = fullfile(carpeta, tipo);
                if isfolder(carpetaTipo)
                    archivos = dir(fullfile(carpetaTipo, '*.mat'));
                    for j = 1:length(archivos)
                        info = struct();
                        info.ruta = fullfile(carpetaTipo, archivos(j).name);
                        info.nombre = archivos(j).name;
                        info.tipo = tipo(1:end-1);  % sin 's' final
                        app.ArchivosCargados{end+1} = info;
                        items{end+1} = sprintf('[%s] %s', iconos.(tipo), archivos(j).name);
                    end
                end
            end

            % Buscar screenshots (imágenes)
            carpetaScreenshots = fullfile(carpeta, 'screenshots');
            if isfolder(carpetaScreenshots)
                extensiones = {'*.png', '*.jpg', '*.jpeg', '*.bmp', '*.tif'};
                for e = 1:length(extensiones)
                    archivos = dir(fullfile(carpetaScreenshots, extensiones{e}));
                    for j = 1:length(archivos)
                        info = struct();
                        info.ruta = fullfile(carpetaScreenshots, archivos(j).name);
                        info.nombre = archivos(j).name;
                        info.tipo = 'screenshot';
                        app.ArchivosCargados{end+1} = info;
                        items{end+1} = sprintf('[SCR] %s', archivos(j).name);
                    end
                end
            end

            if isempty(items)
                % Si no hay .mat, mostrar mensaje
                app.ArchivoListBox.Items = {'(Sin archivos .mat encontrados)'};
                app.ArchivoListBox.ItemsData = {};
                app.StatusLabel.Text = sprintf('No hay .mat en: %s', carpeta);
            else
                app.ArchivoListBox.Items = items;
                app.ArchivoListBox.ItemsData = 1:length(items);
                app.StatusLabel.Text = sprintf('Encontrados %d archivos. Seleccione uno y pulse Cargar.', length(items));
            end
        end

    end

    % =====================================================================
    % METODOS PRIVADOS - CARGA DE DATOS
    % =====================================================================
    methods (Access = private)

        function cargarArchivo(app)
            % Carga el archivo seleccionado
            if isempty(app.ArchivoListBox.Value) || isempty(app.ArchivosCargados)
                return;
            end

            idx = app.ArchivoListBox.Value;
            if ~isnumeric(idx) || idx < 1 || idx > length(app.ArchivosCargados)
                return;
            end

            info = app.ArchivosCargados{idx};
            app.StatusLabel.Text = 'Cargando...';
            drawnow;

            try
                % Manejo especial para screenshots
                if strcmp(info.tipo, 'screenshot')
                    % Abrir imagen en nueva figura
                    img = imread(info.ruta);
                    figure('Name', ['Screenshot: ' info.nombre], 'NumberTitle', 'off');
                    imshow(img);
                    title(info.nombre, 'Interpreter', 'none');
                    app.StatusLabel.Text = sprintf('Screenshot abierto: %s', info.nombre);
                    return;
                end

                % Cargar archivo .mat
                datos = load(info.ruta);

                % Extraer estructura principal
                campos = fieldnames(datos);
                if length(campos) == 1
                    app.DatosActuales = datos.(campos{1});
                else
                    app.DatosActuales = datos;
                end

                % Determinar tipo
                if isfield(app.DatosActuales, 'tipo')
                    app.TipoActual = app.DatosActuales.tipo;
                else
                    app.TipoActual = info.tipo;
                end

                % Extraer metadatos
                if isfield(app.DatosActuales, 'metadatos')
                    app.MetadatosActuales = app.DatosActuales.metadatos;
                else
                    app.MetadatosActuales = struct();
                end

                % Configurar interfaz segun tipo
                configurarPestanas(app);

                % Actualizar visualizaciones
                actualizarVisualizacion(app);

                app.StatusLabel.Text = sprintf('Cargado: %s (%s)', info.nombre, app.TipoActual);

            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

        function configurarPestanas(app)
            % Configura pestanas visibles segun tipo de dato

            % Ocultar todas las pestanas especificas
            app.TabCurvas.Parent = [];
            app.TabLoopRec.Parent = [];
            app.TabMecanica.Parent = [];
            app.TabEvolucion.Parent = [];
            app.TabScatter.Parent = [];
            app.TabRecruitment.Parent = [];
            app.TabLogs.Parent = [];

            % Mostrar pestanas segun tipo
            switch app.TipoActual
                case 'recording'
                    app.TabCurvas.Parent = app.TabGroup;
                    app.TabLoopRec.Parent = app.TabGroup;
                    app.TabMecanica.Parent = app.TabGroup;
                    configurarLoopDropdowns(app);

                case {'trends', 'breathtrends'}
                    app.TabEvolucion.Parent = app.TabGroup;
                    app.TabScatter.Parent = app.TabGroup;
                    configurarTrendCheckboxes(app);
                    configurarScatterDropdowns(app);

                case 'recruitment'
                    app.TabRecruitment.Parent = app.TabGroup;

                case 'logs'
                    app.TabLogs.Parent = app.TabGroup;
            end

            % Siempre mostrar Resumen primero
            app.TabGroup.SelectedTab = app.TabResumen;
        end

        function configurarLoopDropdowns(app)
            % Configura dropdowns de loops para recordings
            vars = {'Presion', 'Flujo', 'Volumen', 'Tiempo'};
            app.LoopXDropDown.Items = vars;
            app.LoopYDropDown.Items = vars;
            app.LoopXDropDown.Value = 'Presion';
            app.LoopYDropDown.Value = 'Volumen';
        end

        function configurarTrendCheckboxes(app)
            % Configura checkboxes para trends
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            % Obtener variables numericas
            varNames = app.DatosActuales.tabla.Properties.VariableNames;

            % Variables prioritarias para mostrar
            varsDeseadas = {'Cdyn', 'PEEP', 'Vci', 'Vce', 'FR', 'Ppico', 'Pmedia', 'FiO2'};

            % Actualizar scatter dropdowns
            varsNumericas = {};
            for i = 1:length(varNames)
                col = app.DatosActuales.tabla{:, i};
                if isnumeric(col)
                    varsNumericas{end+1} = varNames{i};
                end
            end

            if ~isempty(varsNumericas)
                app.ScatterXDropDown.Items = varsNumericas;
                app.ScatterYDropDown.Items = varsNumericas;

                % Defaults inteligentes
                peepIdx = find(contains(lower(varsNumericas), 'peep'), 1);
                cdynIdx = find(contains(lower(varsNumericas), 'cdyn') | contains(lower(varsNumericas), 'cdin'), 1);

                if ~isempty(peepIdx)
                    app.ScatterXDropDown.Value = varsNumericas{peepIdx};
                else
                    app.ScatterXDropDown.Value = varsNumericas{1};
                end

                if ~isempty(cdynIdx)
                    app.ScatterYDropDown.Value = varsNumericas{cdynIdx};
                elseif length(varsNumericas) > 1
                    app.ScatterYDropDown.Value = varsNumericas{2};
                end
            end
        end

        function configurarScatterDropdowns(app)
            % Ya configurado en configurarTrendCheckboxes
        end

    end

    % =====================================================================
    % METODOS PRIVADOS - VISUALIZACION
    % =====================================================================
    methods (Access = private)

        function actualizarVisualizacion(app)
            % Actualiza todas las visualizaciones segun tipo

            % Siempre actualizar resumen
            actualizarResumen(app);

            % Actualizar segun tipo
            switch app.TipoActual
                case 'recording'
                    actualizarRecording(app);
                case {'trends', 'breathtrends'}
                    actualizarTrends(app);
                case 'recruitment'
                    actualizarRecruitment(app);
                case 'logs'
                    actualizarLogs(app);
            end
        end

        function actualizarResumen(app)
            % Actualiza tabla de resumen
            if ~isfield(app.DatosActuales, 'tabla')
                app.SummaryTable.Data = {};
                return;
            end

            datos = app.DatosActuales.tabla;
            varNames = datos.Properties.VariableNames;

            % Caso especial: Logs (datos textuales)
            if strcmp(app.TipoActual, 'logs')
                % Mostrar conteo por categoría
                tableData = cell(0, 6);

                % Contar eventos totales
                tableData{1, 1} = 'Total eventos';
                tableData{1, 2} = num2str(height(datos));
                tableData{1, 3} = '';
                tableData{1, 4} = '';
                tableData{1, 5} = '';
                tableData{1, 6} = '';

                % Conteo por categoría
                if ismember('categoria', varNames)
                    categorias = datos.categoria;
                    cats = unique(categorias);
                    for i = 1:length(cats)
                        row = i + 1;
                        tableData{row, 1} = cats{i};
                        tableData{row, 2} = num2str(sum(strcmp(categorias, cats{i})));
                        tableData{row, 3} = '';
                        tableData{row, 4} = '';
                        tableData{row, 5} = '';
                        tableData{row, 6} = '';
                    end
                end

                % Conteo por severidad
                if ismember('severidad', varNames)
                    severidades = datos.severidad;
                    criticas = sum(strcmp(severidades, 'critica'));
                    advertencias = sum(strcmp(severidades, 'advertencia'));
                    info = sum(strcmp(severidades, 'info'));

                    row = size(tableData, 1) + 1;
                    tableData{row, 1} = '--- Por severidad ---';
                    tableData{row+1, 1} = 'Críticas';
                    tableData{row+1, 2} = num2str(criticas);
                    tableData{row+2, 1} = 'Advertencias';
                    tableData{row+2, 2} = num2str(advertencias);
                    tableData{row+3, 1} = 'Información';
                    tableData{row+3, 2} = num2str(info);
                end

                app.SummaryTable.Data = tableData;
                app.SummaryTable.ColumnName = {'Métrica', 'Valor', '', '', '', ''};
                return;
            end

            % Caso normal: datos numéricos
            tableData = cell(0, 6);

            for i = 1:length(varNames)
                col = datos{:, i};

                if isnumeric(col)
                    validVals = col(~isnan(col));
                    if isempty(validVals)
                        continue;
                    end

                    tableData{end+1, 1} = varNames{i};
                    tableData{end, 2} = sprintf('%.2f', min(validVals));
                    tableData{end, 3} = sprintf('%.2f', max(validVals));
                    tableData{end, 4} = sprintf('%.2f', mean(validVals));
                    tableData{end, 5} = sprintf('%.2f', std(validVals));
                    tableData{end, 6} = sprintf('%d', length(validVals));
                end
            end

            app.SummaryTable.Data = tableData;
            app.SummaryTable.ColumnName = {'Variable', 'Min', 'Max', 'Media', 'Desv.Est', 'N válidos'};
        end

        function actualizarRecording(app)
            % Actualiza visualizacion de recording
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;

            % Preparar tiempo
            if ismember('tiempo_s', datos.Properties.VariableNames)
                app.TiempoSeg = datos.tiempo_s;
            else
                app.TiempoSeg = (1:height(datos))' / 100;  % Asumir 100Hz
            end
            app.TiempoSeg = app.TiempoSeg - app.TiempoSeg(1);
            app.MaxTiempo = max(app.TiempoSeg);

            % Configurar slider
            app.TimeSlider.Limits = [0, max(0.1, app.MaxTiempo - app.WindowSpinner.Value)];
            app.TimeSlider.Value = 0;

            % Actualizar plots
            actualizarCurvasRecording(app);
            actualizarLoopRecording(app);
        end

        function actualizarCurvasRecording(app)
            % Actualiza curvas P, F, V
            if isempty(app.TiempoSeg) || ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;
            startTime = app.TimeSlider.Value;
            windowSize = app.WindowSpinner.Value;
            endTime = min(startTime + windowSize, app.MaxTiempo);

            idx = app.TiempoSeg >= startTime & app.TiempoSeg <= endTime;
            t = app.TiempoSeg(idx) - startTime;

            % Presion
            cla(app.AxesPressure);
            if ismember('presion_cmH2O', datos.Properties.VariableNames)
                plot(app.AxesPressure, t, datos.presion_cmH2O(idx), 'b-', 'LineWidth', 1);
                ylabel(app.AxesPressure, 'Presion (cmH2O)');
            end
            title(app.AxesPressure, 'Presion', 'FontWeight', 'bold');
            grid(app.AxesPressure, 'on');
            xlim(app.AxesPressure, [0, windowSize]);

            % Flujo
            cla(app.AxesFlow);
            if ismember('flujo_Lmin', datos.Properties.VariableNames)
                plot(app.AxesFlow, t, datos.flujo_Lmin(idx), 'Color', [0 0.6 0], 'LineWidth', 1);
                hold(app.AxesFlow, 'on');
                yline(app.AxesFlow, 0, 'k--', 'LineWidth', 0.5);
                hold(app.AxesFlow, 'off');
                ylabel(app.AxesFlow, 'Flujo (L/min)');
            end
            title(app.AxesFlow, 'Flujo', 'FontWeight', 'bold');
            grid(app.AxesFlow, 'on');
            xlim(app.AxesFlow, [0, windowSize]);

            % Volumen
            cla(app.AxesVolume);
            if ismember('volumen_mL', datos.Properties.VariableNames)
                plot(app.AxesVolume, t, datos.volumen_mL(idx), 'Color', [0.8 0.4 0], 'LineWidth', 1);
                ylabel(app.AxesVolume, 'Volumen (mL)');
            end
            xlabel(app.AxesVolume, 'Tiempo (s)');
            title(app.AxesVolume, 'Volumen', 'FontWeight', 'bold');
            grid(app.AxesVolume, 'on');
            xlim(app.AxesVolume, [0, windowSize]);
        end

        function actualizarLoopRecording(app)
            % Actualiza loop configurable
            if isempty(app.TiempoSeg) || ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;
            startTime = app.TimeSlider.Value;
            windowSize = app.WindowSpinner.Value;
            endTime = min(startTime + windowSize, app.MaxTiempo);

            idx = app.TiempoSeg >= startTime & app.TiempoSeg <= endTime;
            t = app.TiempoSeg(idx) - startTime;

            % Obtener datos segun seleccion
            varX = app.LoopXDropDown.Value;
            varY = app.LoopYDropDown.Value;

            [datoX, labelX] = obtenerDatoLoop(app, datos, varX, idx, t);
            [datoY, labelY] = obtenerDatoLoop(app, datos, varY, idx, t);

            if isempty(datoX) || isempty(datoY)
                return;
            end

            % Plot
            cla(app.AxesLoopRec);
            hold(app.AxesLoopRec, 'on');

            % Colorear por fase si disponible
            if ismember('fase', datos.Properties.VariableNames)
                fases = datos.fase(idx);
                isInsp = contains(fases, 'insp');
                isEsp = contains(fases, 'esp');
                isPausa = contains(fases, 'pausa');

                if any(isInsp)
                    plot(app.AxesLoopRec, datoX(isInsp), datoY(isInsp), 'b.', 'MarkerSize', 6);
                end
                if any(isEsp)
                    plot(app.AxesLoopRec, datoX(isEsp), datoY(isEsp), 'r.', 'MarkerSize', 6);
                end
                if any(isPausa)
                    plot(app.AxesLoopRec, datoX(isPausa), datoY(isPausa), 'g.', 'MarkerSize', 6);
                end

                legend(app.AxesLoopRec, {'Inspiracion', 'Espiracion', 'Pausa'}, ...
                    'Location', 'best', 'FontSize', 8);
            else
                scatter(app.AxesLoopRec, datoX, datoY, 10, t, 'filled');
                colorbar(app.AxesLoopRec);
            end

            % Linea conectora
            plot(app.AxesLoopRec, datoX, datoY, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);

            hold(app.AxesLoopRec, 'off');
            xlabel(app.AxesLoopRec, labelX);
            ylabel(app.AxesLoopRec, labelY);
            title(app.AxesLoopRec, sprintf('Loop %s vs %s', varX, varY), 'FontWeight', 'bold');
            grid(app.AxesLoopRec, 'on');
        end

        function [dato, label] = obtenerDatoLoop(app, datos, variable, idx, t)
            % Obtiene datos para el loop segun variable seleccionada
            dato = [];
            label = '';

            switch variable
                case 'Presion'
                    if ismember('presion_cmH2O', datos.Properties.VariableNames)
                        dato = datos.presion_cmH2O(idx);
                        label = 'Presion (cmH2O)';
                    end
                case 'Flujo'
                    if ismember('flujo_Lmin', datos.Properties.VariableNames)
                        dato = datos.flujo_Lmin(idx);
                        label = 'Flujo (L/min)';
                    end
                case 'Volumen'
                    if ismember('volumen_mL', datos.Properties.VariableNames)
                        dato = datos.volumen_mL(idx);
                        label = 'Volumen (mL)';
                    end
                case 'Tiempo'
                    dato = t;
                    label = 'Tiempo (s)';
            end
        end

        function actualizarTrends(app)
            % Actualiza visualizacion de trends
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;
            n = height(datos);
            x = 1:n;

            % Evolucion temporal
            cla(app.AxesEvolucion);
            hold(app.AxesEvolucion, 'on');

            % Variables a mostrar
            varsPlot = {'Cdyn', 'PEEP', 'Vci', 'FR', 'Ppico'};
            colores = {'b', 'g', [0.8 0.4 0], 'r', 'm'};
            legends = {};

            varNames = datos.Properties.VariableNames;
            varNamesLower = lower(varNames);

            for i = 1:length(varsPlot)
                % Buscar columna
                colIdx = find(contains(varNamesLower, lower(varsPlot{i})), 1);
                if ~isempty(colIdx)
                    y = datos{:, colIdx};
                    if isnumeric(y)
                        valid = ~isnan(y);
                        if any(valid)
                            plot(app.AxesEvolucion, x(valid), y(valid), '.-', ...
                                'Color', colores{i}, 'LineWidth', 1, 'MarkerSize', 4);
                            legends{end+1} = varNames{colIdx};
                        end
                    end
                end
            end

            hold(app.AxesEvolucion, 'off');
            if ~isempty(legends)
                legend(app.AxesEvolucion, legends, 'Location', 'best');
            end
            xlabel(app.AxesEvolucion, 'Registro #');
            title(app.AxesEvolucion, 'Evolucion Temporal', 'FontWeight', 'bold');
            grid(app.AxesEvolucion, 'on');

            % Scatter configurable
            actualizarScatter(app);
        end

        function actualizarScatter(app)
            % Actualiza scatter plot
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;
            varX = app.ScatterXDropDown.Value;
            varY = app.ScatterYDropDown.Value;

            if isempty(varX) || isempty(varY)
                return;
            end

            xData = datos{:, varX};
            yData = datos{:, varY};

            if ~isnumeric(xData) || ~isnumeric(yData)
                return;
            end

            valid = ~isnan(xData) & ~isnan(yData);

            cla(app.AxesScatter);
            if any(valid)
                scatter(app.AxesScatter, xData(valid), yData(valid), 40, find(valid), 'filled');
                colorbar(app.AxesScatter);
                xlabel(app.AxesScatter, strrep(varX, '_', ' '));
                ylabel(app.AxesScatter, strrep(varY, '_', ' '));
                title(app.AxesScatter, sprintf('%s vs %s', varY, varX), 'FontWeight', 'bold');
                grid(app.AxesScatter, 'on');
            end
        end

        function actualizarRecruitment(app)
            % Actualiza visualizacion de reclutamiento
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;
            varNames = datos.Properties.VariableNames;
            varNamesLower = lower(varNames);

            % Buscar PEEP y Cdyn
            peepCol = find(contains(varNamesLower, 'peep'), 1);
            cdynCol = find(contains(varNamesLower, 'cdyn') | contains(varNamesLower, 'cdin'), 1);

            if isempty(peepCol) || isempty(cdynCol)
                return;
            end

            peep = datos{:, peepCol};
            cdyn = datos{:, cdynCol};
            n = height(datos);

            % Curva principal
            cla(app.AxesRecruitCurve);
            hold(app.AxesRecruitCurve, 'on');

            scatter(app.AxesRecruitCurve, peep, cdyn, 80, 1:n, 'filled');
            plot(app.AxesRecruitCurve, peep, cdyn, 'k-', 'LineWidth', 1.5);

            % Marcar PEEP optimo si hay analisis
            if isfield(app.DatosActuales, 'analisis')
                an = app.DatosActuales.analisis;
                if isfield(an, 'PEEP_optimo')
                    xline(app.AxesRecruitCurve, an.PEEP_optimo, 'r--', 'LineWidth', 2);
                    text(app.AxesRecruitCurve, an.PEEP_optimo + 0.5, max(cdyn) * 0.9, ...
                        sprintf('PEEP optimo\n%.0f cmH2O', an.PEEP_optimo), ...
                        'Color', 'r', 'FontWeight', 'bold');
                end
            end

            hold(app.AxesRecruitCurve, 'off');
            xlabel(app.AxesRecruitCurve, 'PEEP (cmH2O)');
            ylabel(app.AxesRecruitCurve, 'Cdyn (mL/cmH2O)');
            title(app.AxesRecruitCurve, 'Curva de Reclutamiento', 'FontWeight', 'bold');
            colorbar(app.AxesRecruitCurve);
            grid(app.AxesRecruitCurve, 'on');

            % Pasos
            cla(app.AxesRecruitSteps);
            x = 1:n;

            yyaxis(app.AxesRecruitSteps, 'left');
            plot(app.AxesRecruitSteps, x, cdyn, 'b.-', 'LineWidth', 1.5, 'MarkerSize', 10);
            ylabel(app.AxesRecruitSteps, 'Cdyn (mL/cmH2O)');

            yyaxis(app.AxesRecruitSteps, 'right');
            plot(app.AxesRecruitSteps, x, peep, 'g.-', 'LineWidth', 1.5, 'MarkerSize', 10);
            ylabel(app.AxesRecruitSteps, 'PEEP (cmH2O)');

            xlabel(app.AxesRecruitSteps, 'Paso #');
            title(app.AxesRecruitSteps, 'Evolucion por Pasos', 'FontWeight', 'bold');
            grid(app.AxesRecruitSteps, 'on');
        end

        function actualizarLogs(app)
            % Actualiza visualizacion de logs
            if ~isfield(app.DatosActuales, 'tabla')
                return;
            end

            datos = app.DatosActuales.tabla;

            % Tabla de logs - convertir todo a texto para UITable
            tableData = cell(height(datos), width(datos));
            varNames = datos.Properties.VariableNames;
            for col = 1:width(datos)
                colData = datos{:, col};
                for row = 1:height(datos)
                    if iscell(colData)
                        val = colData{row};
                    else
                        val = colData(row);
                    end
                    % Convertir a texto
                    if isdatetime(val)
                        tableData{row, col} = char(val);
                    elseif isnumeric(val)
                        tableData{row, col} = num2str(val);
                    elseif isstring(val) || ischar(val)
                        tableData{row, col} = char(val);
                    elseif iscategorical(val)
                        tableData{row, col} = char(val);
                    else
                        tableData{row, col} = '';
                    end
                end
            end
            app.LogsTable.Data = tableData;
            app.LogsTable.ColumnName = varNames;

            % Timeline
            cla(app.AxesTimeline);

            if ismember('tiempo', datos.Properties.VariableNames) && ...
                    ismember('categoria', datos.Properties.VariableNames)

                tiempos = datos.tiempo;
                categorias = datos.categoria;

                % Colores por categoria - nombres reales del parser
                colores = containers.Map();
                colores('Alarma') = [0.9 0.2 0.2];           % Rojo
                colores('Cambio del parámetro') = [0.2 0.2 0.9];  % Azul
                colores('Cambio del límite de alarma') = [0.5 0.2 0.8];  % Morado
                colores('Funciones') = [0.2 0.8 0.2];        % Verde
                colores('Sistema') = [0.5 0.5 0.5];          % Gris

                hold(app.AxesTimeline, 'on');

                cats = unique(categorias);
                yLabels = {};
                for i = 1:length(cats)
                    cat = cats{i};
                    idx = strcmp(categorias, cat);
                    yLabels{i} = cat;

                    if colores.isKey(cat)
                        c = colores(cat);
                    else
                        c = [0.3 0.3 0.3];  % Gris oscuro por defecto
                    end

                    y = ones(sum(idx), 1) * i;

                    if isdatetime(tiempos)
                        x = tiempos(idx);
                    elseif iscell(tiempos)
                        x = find(idx);
                    else
                        x = find(idx);
                    end

                    scatter(app.AxesTimeline, x, y, 80, c, 'filled', 'DisplayName', cat);
                end

                hold(app.AxesTimeline, 'off');
                legend(app.AxesTimeline, 'Location', 'best');
                xlabel(app.AxesTimeline, 'Registro #');
                ylabel(app.AxesTimeline, '');
                yticks(app.AxesTimeline, 1:length(yLabels));
                yticklabels(app.AxesTimeline, yLabels);
                ylim(app.AxesTimeline, [0.5, length(yLabels)+0.5]);
                title(app.AxesTimeline, 'Timeline de Eventos', 'FontWeight', 'bold');
                grid(app.AxesTimeline, 'on');
            end
        end

    end

    % =====================================================================
    % CALLBACKS
    % =====================================================================
    methods (Access = private)

        function startupFcn(app)
            % Inicializacion
            baseDir = fileparts(mfilename('fullpath'));

            % Agregar paths
            addpath(fullfile(baseDir, 'src', 'loaders'));
            addpath(fullfile(baseDir, 'src', 'analysis'));
            addpath(fullfile(baseDir, 'src', 'importers'));
            addpath(fullfile(baseDir, 'src', 'importers', 'parsers'));
            addpath(fullfile(baseDir, 'src', 'processors'));
            addpath(fullfile(baseDir, 'src', 'database'));

            % Inicializar
            inicializarDB(app);
            cargarPacientes(app);
        end

        function PacienteDropDownValueChanged(app, ~)
            cargarSesiones(app);
        end

        function SesionListBoxValueChanged(app, ~)
            app.StatusLabel.Text = 'Cargando archivos de sesion...';
            drawnow;
            cargarArchivos(app);
        end

        function ArchivoListBoxValueChanged(app, ~)
            % Solo preview, no cargar automaticamente
        end

        function LoadButtonPushed(app, ~)
            cargarArchivo(app);
        end

        function RefreshButtonPushed(app, ~)
            cargarPacientes(app);
        end

        function TimeSliderValueChanged(app, ~)
            actualizarCurvasRecording(app);
            actualizarLoopRecording(app);
        end

        function WindowSpinnerValueChanged(app, ~)
            if ~isempty(app.MaxTiempo)
                app.TimeSlider.Limits = [0, max(0.1, app.MaxTiempo - app.WindowSpinner.Value)];
                if app.TimeSlider.Value > app.TimeSlider.Limits(2)
                    app.TimeSlider.Value = app.TimeSlider.Limits(2);
                end
            end
            actualizarCurvasRecording(app);
            actualizarLoopRecording(app);
        end

        function LoopDropDownValueChanged(app, ~)
            actualizarLoopRecording(app);
        end

        function ScatterDropDownValueChanged(app, ~)
            actualizarScatter(app);
        end

        function LoopPresetSelected(app, event)
            % Presets rapidos para loops
            switch event.NewValue.Text
                case 'P-V'
                    app.LoopXDropDown.Value = 'Presion';
                    app.LoopYDropDown.Value = 'Volumen';
                case 'F-V'
                    app.LoopXDropDown.Value = 'Flujo';
                    app.LoopYDropDown.Value = 'Volumen';
                case 'P-F'
                    app.LoopXDropDown.Value = 'Presion';
                    app.LoopYDropDown.Value = 'Flujo';
            end
            actualizarLoopRecording(app);
        end

        function CalcMechanicsButtonPushed(app, ~)
            if isempty(app.DatosActuales) || ~strcmp(app.TipoActual, 'recording')
                app.StatusLabel.Text = 'Cargue un recording primero';
                return;
            end

            app.StatusLabel.Text = 'Calculando mecanica...';
            drawnow;

            try
                % Detectar ciclos
                app.Ciclos = detectarCiclosRespiratorios(app.DatosActuales.tabla, app.TiempoSeg);

                % Calcular mecanica
                app.Mecanica = calcularMecanicaRespiratoria(app.Ciclos, app.MetadatosActuales);

                % Mostrar en tabla
                if ~isempty(app.Mecanica) && isfield(app.Mecanica, 'media')
                    m = app.Mecanica.media;
                    tableData = {
                        'Cst (mL/cmH2O)', sprintf('%.1f', m.Cst);
                        'Cdyn (mL/cmH2O)', sprintf('%.1f', m.Cdyn);
                        'Raw (cmH2O*s/L)', sprintf('%.2f', m.Raw);
                        'Driving P (cmH2O)', sprintf('%.1f', m.DrivingP);
                        'WOB (J/L)', sprintf('%.3f', m.WOB);
                        'Ciclos analizados', sprintf('%d', app.Mecanica.nCiclos)
                        };
                    app.MechanicsTable.Data = tableData;
                end

                % Graficar ciclos en AxesMecanica
                cla(app.AxesMecanica);
                hold(app.AxesMecanica, 'on');

                nCiclos = length(app.Ciclos);
                colores = parula(max(nCiclos, 1));

                for i = 1:nCiclos
                    ciclo = app.Ciclos(i);
                    if ~isempty(ciclo.presion) && ~isempty(ciclo.volumen)
                        % Plotear loop P-V del ciclo
                        plot(app.AxesMecanica, ciclo.presion, ciclo.volumen, ...
                            'Color', colores(i, :), 'LineWidth', 1.5);
                    end
                end

                % Añadir línea de compliance estática si hay datos
                if ~isempty(app.Mecanica) && isfield(app.Mecanica, 'media')
                    % Dibujar línea de compliance (simplificada)
                    Cst = app.Mecanica.media.Cst;
                    if Cst > 0 && Cst < 200
                        pRange = [5, 30];
                        vRange = Cst * (pRange - 5);  % Asumiendo PEEP = 5
                        plot(app.AxesMecanica, pRange, vRange, 'k--', 'LineWidth', 2, ...
                            'DisplayName', sprintf('Cst = %.0f mL/cmH2O', Cst));
                    end
                end

                hold(app.AxesMecanica, 'off');
                xlabel(app.AxesMecanica, 'Presión (cmH2O)');
                ylabel(app.AxesMecanica, 'Volumen (mL)');
                title(app.AxesMecanica, sprintf('Loops P-V (%d ciclos)', nCiclos), 'FontWeight', 'bold');
                legend(app.AxesMecanica, 'off');
                grid(app.AxesMecanica, 'on');
                colorbar(app.AxesMecanica);

                % --- ANÁLISIS DE RESISTENCIAS ---
                % Llamar a función interactiva con selector de ciclo
                figuraResistencias(app.Mecanica, app.Ciclos);

                app.StatusLabel.Text = sprintf('Mecanica calculada: %d ciclos', app.Mecanica.nCiclos);

            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

        function ExportButtonPushed(app, ~)
            if isempty(app.DatosActuales)
                app.StatusLabel.Text = 'No hay datos para exportar';
                return;
            end

            [file, path] = uiputfile({'*.xlsx', 'Excel'; '*.mat', 'MATLAB'; '*.csv', 'CSV'}, ...
                'Guardar como...');

            if file == 0
                return;
            end

            fullPath = fullfile(path, file);

            try
                [~, ~, ext] = fileparts(fullPath);

                switch ext
                    case '.xlsx'
                        if isfield(app.DatosActuales, 'tabla')
                            writetable(app.DatosActuales.tabla, fullPath);
                        end
                    case '.csv'
                        if isfield(app.DatosActuales, 'tabla')
                            writetable(app.DatosActuales.tabla, fullPath);
                        end
                    case '.mat'
                        datosExport = app.DatosActuales;
                        datosExport.mecanica = app.Mecanica;
                        save(fullPath, '-struct', 'datosExport');
                end

                app.StatusLabel.Text = sprintf('Exportado: %s', file);

            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

        function AssignButtonPushed(app, ~)
            % Asignar sesion actual a un paciente
            if isempty(app.SesionesDisponibles)
                app.StatusLabel.Text = 'No hay sesion seleccionada';
                return;
            end

            idx = app.SesionListBox.Value;
            if isempty(idx) || idx < 1 || idx > length(app.SesionesDisponibles)
                app.StatusLabel.Text = 'Seleccione una sesion';
                return;
            end

            sesion = app.SesionesDisponibles{idx};

            % Verificar que sea de sin_asignar
            if ~contains(sesion.carpeta, 'sin_asignar')
                app.StatusLabel.Text = 'Solo se pueden asignar sesiones de "Sin asignar"';
                return;
            end

            % Dialogo para datos del paciente
            prompts = {'Cama (ej: Cama_12):', 'Sexo (M/F):', 'Altura (cm):', 'Peso (kg):', 'Motivo ingreso:'};
            dlgtitle = 'Asignar a Paciente';
            defaults = {'Cama_', 'M', '170', '70', ''};

            respuestas = inputdlg(prompts, dlgtitle, [1 50; 1 20; 1 20; 1 20; 1 50], defaults);

            if isempty(respuestas)
                return;
            end

            % Crear estructura de paciente
            infoPaciente = struct();
            infoPaciente.cama = strtrim(respuestas{1});
            infoPaciente.sexo = upper(strtrim(respuestas{2}));
            infoPaciente.altura_cm = str2double(respuestas{3});
            infoPaciente.peso_kg = str2double(respuestas{4});
            infoPaciente.motivoIngreso = strtrim(respuestas{5});
            infoPaciente.fechaAsignacion = datetime('now');

            % Calcular PBW
            if strcmp(infoPaciente.sexo, 'M')
                infoPaciente.PBW_kg = 50 + 0.91 * (infoPaciente.altura_cm - 152.4);
            else
                infoPaciente.PBW_kg = 45.5 + 0.91 * (infoPaciente.altura_cm - 152.4);
            end

            try
                % Llamar a dbAddSession
                dbAddSession(sesion.carpeta, infoPaciente);
                app.StatusLabel.Text = sprintf('Sesion asignada a %s', infoPaciente.cama);

                % Refrescar lista
                cargarPacientes(app);
                cargarSesiones(app);

            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
            end
        end

    end

    % =====================================================================
    % CREACION DE COMPONENTES
    % =====================================================================
    methods (Access = private)

        function createComponents(app)

            % Crear UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1600 950];
            app.UIFigure.Name = 'Visor de Datos Respiratorios SERVO-U v2.0';
            app.UIFigure.Color = [0.94 0.94 0.94];

            % GridLayout principal
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {320, '1x'};
            app.GridLayout.RowHeight = {'1x', 45};
            app.GridLayout.Padding = [5 5 5 5];
            app.GridLayout.ColumnSpacing = 5;
            app.GridLayout.RowSpacing = 5;

            % ========== PANEL IZQUIERDO ==========
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Navegacion';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.BackgroundColor = [1 1 1];
            app.LeftPanel.Scrollable = 'on';

            % Paciente
            app.PacienteLabel = uilabel(app.LeftPanel);
            app.PacienteLabel.Position = [10 870 100 22];
            app.PacienteLabel.Text = 'Paciente:';
            app.PacienteLabel.FontWeight = 'bold';

            app.PacienteDropDown = uidropdown(app.LeftPanel);
            app.PacienteDropDown.Items = {'Cargando...'};
            app.PacienteDropDown.Position = [10 845 290 25];
            app.PacienteDropDown.ValueChangedFcn = createCallbackFcn(app, @PacienteDropDownValueChanged, true);

            % Botones
            app.RefreshButton = uibutton(app.LeftPanel, 'push');
            app.RefreshButton.Position = [10 810 140 28];
            app.RefreshButton.Text = 'Actualizar';
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshButtonPushed, true);

            app.LoadButton = uibutton(app.LeftPanel, 'push');
            app.LoadButton.Position = [160 810 140 28];
            app.LoadButton.Text = 'Cargar';
            app.LoadButton.FontWeight = 'bold';
            app.LoadButton.BackgroundColor = [0.3 0.6 0.9];
            app.LoadButton.FontColor = [1 1 1];
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);

            % Sesiones
            app.SesionLabel = uilabel(app.LeftPanel);
            app.SesionLabel.Position = [10 775 200 22];
            app.SesionLabel.Text = 'Sesiones disponibles:';
            app.SesionLabel.FontWeight = 'bold';

            app.SesionListBox = uilistbox(app.LeftPanel);
            app.SesionListBox.Items = {'(Cargando...)'};
            app.SesionListBox.Position = [10 590 290 180];
            app.SesionListBox.ValueChangedFcn = createCallbackFcn(app, @SesionListBoxValueChanged, true);

            % Archivos
            app.ArchivoLabel = uilabel(app.LeftPanel);
            app.ArchivoLabel.Position = [10 555 200 22];
            app.ArchivoLabel.Text = 'Archivos en sesion:';
            app.ArchivoLabel.FontWeight = 'bold';

            app.ArchivoListBox = uilistbox(app.LeftPanel);
            app.ArchivoListBox.Items = {'(Seleccione sesion)'};
            app.ArchivoListBox.Position = [10 370 290 180];
            app.ArchivoListBox.ValueChangedFcn = createCallbackFcn(app, @ArchivoListBoxValueChanged, true);

            % Panel de metadatos
            app.MetadataPanel = uipanel(app.LeftPanel);
            app.MetadataPanel.Title = 'Informacion';
            app.MetadataPanel.Position = [10 210 290 150];
            app.MetadataPanel.BackgroundColor = [0.95 0.97 1];

            % Boton de asignacion de paciente
            app.AssignButton = uibutton(app.LeftPanel, 'push');
            app.AssignButton.Position = [10 170 290 32];
            app.AssignButton.Text = 'Asignar a Paciente...';
            app.AssignButton.FontWeight = 'bold';
            app.AssignButton.BackgroundColor = [0.3 0.7 0.4];
            app.AssignButton.FontColor = [1 1 1];
            app.AssignButton.ButtonPushedFcn = createCallbackFcn(app, @AssignButtonPushed, true);

            % Controles de tiempo (para recordings)
            uilabel(app.LeftPanel, 'Position', [10 165 150 22], 'Text', 'Ventana (s):', 'FontWeight', 'bold');
            app.WindowSpinner = uispinner(app.LeftPanel);
            app.WindowSpinner.Limits = [1 60];
            app.WindowSpinner.Value = 10;
            app.WindowSpinner.Position = [110 165 80 22];
            app.WindowSpinner.ValueChangedFcn = createCallbackFcn(app, @WindowSpinnerValueChanged, true);

            uilabel(app.LeftPanel, 'Position', [10 130 150 22], 'Text', 'Navegacion:', 'FontWeight', 'bold');
            app.TimeSlider = uislider(app.LeftPanel);
            app.TimeSlider.Limits = [0 100];
            app.TimeSlider.Position = [10 115 280 3];
            app.TimeSlider.ValueChangedFcn = createCallbackFcn(app, @TimeSliderValueChanged, true);

            % Exportar
            app.ExportButton = uibutton(app.LeftPanel, 'push');
            app.ExportButton.Position = [10 70 290 30];
            app.ExportButton.Text = 'Exportar Datos';
            app.ExportButton.BackgroundColor = [0.4 0.7 0.4];
            app.ExportButton.FontColor = [1 1 1];
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportButtonPushed, true);

            % ========== PANEL DERECHO ==========
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Visualizacion';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';
            app.RightPanel.BackgroundColor = [1 1 1];

            % TabGroup
            app.TabGroup = uitabgroup(app.RightPanel);
            app.TabGroup.Position = [5 5 1230 860];

            % ===== TAB RESUMEN =====
            app.TabResumen = uitab(app.TabGroup);
            app.TabResumen.Title = 'Resumen';
            app.TabResumen.BackgroundColor = [0.98 0.98 1];

            app.SummaryTable = uitable(app.TabResumen);
            app.SummaryTable.Position = [20 20 1190 810];
            app.SummaryTable.ColumnName = {'Variable', 'Min', 'Max', 'Media', 'Desv.Est', 'N'};
            app.SummaryTable.ColumnWidth = {300, 120, 120, 120, 120, 80};

            % ===== TAB CURVAS (Recordings) =====
            app.TabCurvas = uitab(app.TabGroup);
            app.TabCurvas.Title = 'Curvas';
            app.TabCurvas.BackgroundColor = [1 1 1];

            app.AxesPressure = uiaxes(app.TabCurvas);
            app.AxesPressure.Position = [30 560 1170 250];
            title(app.AxesPressure, 'Presion');
            app.AxesPressure.XGrid = 'on';
            app.AxesPressure.YGrid = 'on';

            app.AxesFlow = uiaxes(app.TabCurvas);
            app.AxesFlow.Position = [30 290 1170 250];
            title(app.AxesFlow, 'Flujo');
            app.AxesFlow.XGrid = 'on';
            app.AxesFlow.YGrid = 'on';

            app.AxesVolume = uiaxes(app.TabCurvas);
            app.AxesVolume.Position = [30 20 1170 250];
            title(app.AxesVolume, 'Volumen');
            app.AxesVolume.XGrid = 'on';
            app.AxesVolume.YGrid = 'on';

            % ===== TAB LOOP (Recordings) =====
            app.TabLoopRec = uitab(app.TabGroup);
            app.TabLoopRec.Title = 'Loop';
            app.TabLoopRec.BackgroundColor = [1 1 1];

            % Controles de loop
            uilabel(app.TabLoopRec, 'Position', [30 820 50 22], 'Text', 'Eje X:', 'FontWeight', 'bold');
            app.LoopXDropDown = uidropdown(app.TabLoopRec);
            app.LoopXDropDown.Items = {'Presion', 'Flujo', 'Volumen', 'Tiempo'};
            app.LoopXDropDown.Value = 'Presion';
            app.LoopXDropDown.Position = [80 820 100 22];
            app.LoopXDropDown.ValueChangedFcn = createCallbackFcn(app, @LoopDropDownValueChanged, true);

            uilabel(app.TabLoopRec, 'Position', [200 820 50 22], 'Text', 'Eje Y:', 'FontWeight', 'bold');
            app.LoopYDropDown = uidropdown(app.TabLoopRec);
            app.LoopYDropDown.Items = {'Presion', 'Flujo', 'Volumen', 'Tiempo'};
            app.LoopYDropDown.Value = 'Volumen';
            app.LoopYDropDown.Position = [250 820 100 22];
            app.LoopYDropDown.ValueChangedFcn = createCallbackFcn(app, @LoopDropDownValueChanged, true);

            % Presets
            app.LoopPresetsPanel = uibuttongroup(app.TabLoopRec);
            app.LoopPresetsPanel.Title = 'Presets';
            app.LoopPresetsPanel.Position = [400 810 300 40];
            app.LoopPresetsPanel.SelectionChangedFcn = createCallbackFcn(app, @LoopPresetSelected, true);

            uiradiobutton(app.LoopPresetsPanel, 'Text', 'P-V', 'Position', [10 5 50 22]);
            uiradiobutton(app.LoopPresetsPanel, 'Text', 'F-V', 'Position', [70 5 50 22]);
            uiradiobutton(app.LoopPresetsPanel, 'Text', 'P-F', 'Position', [130 5 50 22]);

            app.AxesLoopRec = uiaxes(app.TabLoopRec);
            app.AxesLoopRec.Position = [30 20 1170 780];
            app.AxesLoopRec.XGrid = 'on';
            app.AxesLoopRec.YGrid = 'on';

            % ===== TAB MECANICA (Recordings) =====
            app.TabMecanica = uitab(app.TabGroup);
            app.TabMecanica.Title = 'Mecanica';
            app.TabMecanica.BackgroundColor = [1 1 1];

            app.CalcMechanicsButton = uibutton(app.TabMecanica, 'push');
            app.CalcMechanicsButton.Position = [30 800 200 35];
            app.CalcMechanicsButton.Text = 'Calcular Mecanica';
            app.CalcMechanicsButton.FontWeight = 'bold';
            app.CalcMechanicsButton.BackgroundColor = [0.6 0.4 0.8];
            app.CalcMechanicsButton.FontColor = [1 1 1];
            app.CalcMechanicsButton.ButtonPushedFcn = createCallbackFcn(app, @CalcMechanicsButtonPushed, true);

            app.MechanicsTable = uitable(app.TabMecanica);
            app.MechanicsTable.Position = [30 500 400 280];
            app.MechanicsTable.ColumnName = {'Parametro', 'Valor'};
            app.MechanicsTable.ColumnWidth = {200, 150};

            app.AxesMecanica = uiaxes(app.TabMecanica);
            app.AxesMecanica.Position = [30 20 1170 450];
            app.AxesMecanica.XGrid = 'on';
            app.AxesMecanica.YGrid = 'on';

            % ===== TAB EVOLUCION (Trends) =====
            app.TabEvolucion = uitab(app.TabGroup);
            app.TabEvolucion.Title = 'Evolucion';
            app.TabEvolucion.BackgroundColor = [1 1 1];

            app.AxesEvolucion = uiaxes(app.TabEvolucion);
            app.AxesEvolucion.Position = [30 20 1170 810];
            app.AxesEvolucion.XGrid = 'on';
            app.AxesEvolucion.YGrid = 'on';

            % ===== TAB SCATTER (Trends) =====
            app.TabScatter = uitab(app.TabGroup);
            app.TabScatter.Title = 'Correlacion';
            app.TabScatter.BackgroundColor = [1 1 1];

            uilabel(app.TabScatter, 'Position', [30 820 50 22], 'Text', 'Eje X:', 'FontWeight', 'bold');
            app.ScatterXDropDown = uidropdown(app.TabScatter);
            app.ScatterXDropDown.Items = {'(Cargar datos)'};
            app.ScatterXDropDown.Position = [80 820 200 22];
            app.ScatterXDropDown.ValueChangedFcn = createCallbackFcn(app, @ScatterDropDownValueChanged, true);

            uilabel(app.TabScatter, 'Position', [300 820 50 22], 'Text', 'Eje Y:', 'FontWeight', 'bold');
            app.ScatterYDropDown = uidropdown(app.TabScatter);
            app.ScatterYDropDown.Items = {'(Cargar datos)'};
            app.ScatterYDropDown.Position = [350 820 200 22];
            app.ScatterYDropDown.ValueChangedFcn = createCallbackFcn(app, @ScatterDropDownValueChanged, true);

            app.AxesScatter = uiaxes(app.TabScatter);
            app.AxesScatter.Position = [30 20 1170 780];
            app.AxesScatter.XGrid = 'on';
            app.AxesScatter.YGrid = 'on';

            % ===== TAB RECRUITMENT =====
            app.TabRecruitment = uitab(app.TabGroup);
            app.TabRecruitment.Title = 'Reclutamiento';
            app.TabRecruitment.BackgroundColor = [1 1 1];

            app.AxesRecruitCurve = uiaxes(app.TabRecruitment);
            app.AxesRecruitCurve.Position = [30 430 1170 400];
            title(app.AxesRecruitCurve, 'Curva de Reclutamiento');
            app.AxesRecruitCurve.XGrid = 'on';
            app.AxesRecruitCurve.YGrid = 'on';

            app.AxesRecruitSteps = uiaxes(app.TabRecruitment);
            app.AxesRecruitSteps.Position = [30 20 1170 380];
            title(app.AxesRecruitSteps, 'Evolucion por Pasos');
            app.AxesRecruitSteps.XGrid = 'on';
            app.AxesRecruitSteps.YGrid = 'on';

            % ===== TAB LOGS =====
            app.TabLogs = uitab(app.TabGroup);
            app.TabLogs.Title = 'Eventos';
            app.TabLogs.BackgroundColor = [1 1 1];

            app.AxesTimeline = uiaxes(app.TabLogs);
            app.AxesTimeline.Position = [30 450 1170 380];
            title(app.AxesTimeline, 'Timeline de Eventos');
            app.AxesTimeline.XGrid = 'on';
            app.AxesTimeline.YGrid = 'on';

            app.LogsTable = uitable(app.TabLogs);
            app.LogsTable.Position = [30 20 1170 400];

            % ========== BARRA DE ESTADO ==========
            app.ControlPanel = uipanel(app.GridLayout);
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = [1 2];
            app.ControlPanel.BackgroundColor = [0.2 0.2 0.3];

            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Position = [15 12 1500 22];
            app.StatusLabel.Text = 'Iniciando...';
            app.StatusLabel.FontColor = [1 1 1];
            app.StatusLabel.FontWeight = 'bold';

            % Ocultar pestanas inicialmente
            app.TabCurvas.Parent = [];
            app.TabLoopRec.Parent = [];
            app.TabMecanica.Parent = [];
            app.TabEvolucion.Parent = [];
            app.TabScatter.Parent = [];
            app.TabRecruitment.Parent = [];
            app.TabLogs.Parent = [];

            % Mostrar figura
            app.UIFigure.Visible = 'on';
        end
    end

    % =====================================================================
    % METODOS PUBLICOS
    % =====================================================================
    methods (Access = public)

        function app = VentilatorRecordingViewer
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end
