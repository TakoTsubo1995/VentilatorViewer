% ventiladorAnalisis.m % Analisis de datos del ventilador SERVO -
    U

        clear clc close all

            dataDir =
    fullfile(fileparts(mfilename('fullpath')), 'ventilatorData');

disp('================================================================')
    disp('       ANALISIS DE DATOS DEL VENTILADOR SERVO-U')
        disp('================================================================')

            recordingsDir = fullfile(dataDir, 'recordings');
recordingFiles = dir(fullfile(recordingsDir, '*.txt'));
fprintf('  Recordings: %d archivos\n', length(recordingFiles))

    trendsDir = fullfile(dataDir, 'trends');
trendFiles = dir(fullfile(trendsDir, '*_Trends.txt'));
breathTrendFiles = dir(fullfile(trendsDir, '*_BreathTrends.txt'));
fprintf('  Trends: %d archivos\n', length(trendFiles))
    fprintf('  BreathTrends: %d archivos\n', length(breathTrendFiles))

        recruitmentsDir = fullfile(dataDir, 'recruitments');
recruitmentFiles = dir(fullfile(recruitmentsDir, '*.txt'));
fprintf('  Recruitments: %d archivos\n', length(recruitmentFiles))

    disp(' ') disp('CARGANDO BREATHTRENDS...')

        if ~isempty(breathTrendFiles)[~, maxIdx] =
            max([breathTrendFiles.bytes]);
breathTrendFile = fullfile(trendsDir, breathTrendFiles(maxIdx).name);
fprintf('   Archivo: %s\n', breathTrendFiles(maxIdx).name)

    breathData = cargarBreathTrendsLocal(breathTrendFile);
fprintf('   %d respiraciones cargadas\n', height(breathData))

    tiempoNum = datetime(breathData.Tiempo, 'InputFormat', 'HH:mm:ss');

figure('Name', 'Tendencias por Respiracion', 'Position', [50 50 1400 900],
       'Color', 'w')

    subplot(3, 2, 1) plot(tiempoNum, breathData.Cdin, 'b.-', 'MarkerSize', 4)
        ylabel('Cdin (mL/cmH2O)') title('Compliance Dinamica') grid on

    subplot(3, 2, 2) plot(tiempoNum, breathData.PEEP, 'r.-', 'MarkerSize', 4)
        ylabel('PEEP (cmH2O)') title('PEEP') grid on

    subplot(3, 2, 3)
        plot(tiempoNum, breathData.Pei, 'Color', [0.6 0 0.6], 'LineWidth', 1)
            ylabel('Pei (cmH2O)') title('Presion Plateau') grid on

    subplot(3, 2, 4)
        plot(tiempoNum, breathData.Vci, 'g.-', 'MarkerSize', 4) hold on
    plot(tiempoNum, breathData.Vce, 'm.-', 'MarkerSize', 4)
        ylabel('Volumen (mL)') title('Volumenes')
            legend('Vci', 'Vce', 'Location', 'best') grid on

    subplot(3, 2, 5) plot(tiempoNum, breathData.Fresp, 'k.-', 'MarkerSize', 4)
        ylabel('FR (resp/min)') xlabel('Tiempo')
            title('Frecuencia Respiratoria') grid on

    subplot(3, 2, 6) validCdin = breathData.Cdin(~isnan(breathData.Cdin));
    histogram(validCdin, 30)
    xlabel('Cdin (mL/cmH2O)')
    ylabel('Frecuencia')
    title('Distribucion Compliance')
    grid on
    
    sgtitle('Analisis por Respiracion - SERVO-U')
end

disp(' ')
disp('CARGANDO RECORDINGS...')

if ~isempty(recordingFiles)
    for i = 1:length(recordingFiles)
        fprintf('   [%d] %s\n', i, recordingFiles(i).name)
    end
    
    selectedFile = fullfile(recordingsDir, recordingFiles(1).name);
    fprintf('\n   Cargando: %s\n', recordingFiles(1).name)

        [metadatos, datosResp] = cargarRecordingLocal(selectedFile);
    fprintf('   %d muestras (%.1f segundos)\n', height(datosResp),
            height(datosResp) / 100)

        tiempoStr = datosResp.Tiempo;
    tiempoSeg = convertirTiempoLocal(tiempoStr);
    tiempoSeg = tiempoSeg - tiempoSeg(1);

    figure('Name', 'Curvas Tiempo Real', 'Position', [150 150 1200 700],
           'Color', 'w')

        subplot(3, 1, 1)
            plot(tiempoSeg, datosResp.Presion, 'b-', 'LineWidth', 1)
                ylabel('Presion (cmH2O)')
                    title(sprintf('Modo: %s | Vt: %d mL | FR: %d | PEEP: %.1f',
                                  ... metadatos.Modo, metadatos.Vt,
                                  metadatos.FR, metadatos.PEEP)) grid on
        xlim([0 min(20, max(tiempoSeg))])

            subplot(3, 1, 2) plot(tiempoSeg, datosResp.Flujo, 'Color',
                                  [0 0.6 0], 'LineWidth', 1) hold on
        yline(0, 'k--') ylabel('Flujo (L/min)') grid on
        xlim([0 min(20, max(tiempoSeg))])

            subplot(3, 1, 3) plot(tiempoSeg, datosResp.Volumen, 'Color',
                                  [0.8 0.4 0], 'LineWidth', 1)
                ylabel('Volumen (mL)') xlabel('Tiempo (s)') grid on
        xlim([0 min(20, max(tiempoSeg))])

            sgtitle('Monitor de Ventilacion - SERVO-U') end

        disp(' ') disp('CARGANDO RECLUTAMIENTO...')

            if ~isempty(recruitmentFiles)[~, maxIdx] =
                max([recruitmentFiles.bytes]);
    recruitmentFile = fullfile(recruitmentsDir, recruitmentFiles(maxIdx).name);

    recruitData = cargarBreathTrendsLocal(recruitmentFile);
    fprintf('   %d puntos cargados\n', height(recruitData))

        figure('Name', 'Maniobra Reclutamiento', 'Position', [100 100 1000 600],
               'Color', 'w')

            tiempoRecruit = datetime(recruitData.Tiempo, 'InputFormat',
                                     'HH:mm:ss');

    subplot(2, 1, 1) yyaxis left
        plot(tiempoRecruit, recruitData.PEEP, 'b-', 'LineWidth', 2)
            ylabel('PEEP (cmH2O)') yyaxis right
        plot(tiempoRecruit, recruitData.Cdin, 'r.-', 'MarkerSize', 6)
            ylabel('Cdin (mL/cmH2O)') title('PEEP vs Compliance')
                xlabel('Tiempo') grid on
        legend('PEEP', 'Compliance', 'Location', 'best')

            subplot(2, 1, 2) scatter(recruitData.PEEP, recruitData.Cdin, 50,
                                     1 : height(recruitData), 'filled') colorbar
        xlabel('PEEP (cmH2O)') ylabel('Compliance (mL/cmH2O)')
            title('Curva PEEP-Compliance') grid on

        sgtitle('Maniobra de Reclutamiento') end

        disp(' ') disp('ESTADISTICAS:') disp('-------------')

            if exist ('breathData', 'var') validCdin =
                breathData.Cdin(~isnan(breathData.Cdin));
    validPEEP = breathData.PEEP(~isnan(breathData.PEEP));
    validVt = breathData.Vci(~isnan(breathData.Vci));

    fprintf('Compliance: %.1f +/- %.1f mL/cmH2O\n', mean(validCdin),
            std(validCdin))
        fprintf('PEEP: %.1f +/- %.1f cmH2O\n', mean(validPEEP), std(validPEEP))
            fprintf('Vt: %.1f +/- %.1f mL\n', mean(validVt), std(validVt)) end

        disp(' ') fprintf('Completado. %d figuras generadas.\n',
                          length(findall(0, 'Type', 'figure')))

            function datos = cargarBreathTrendsLocal(archivo) fid =
                fopen(archivo, 'r', 'n', 'UTF-8');
    contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    lineas = contenido{1};

    lineaData = find(startsWith(lineas, '[DATA]'));
    nLineas = length(lineas) - (lineaData + 1);

    tiempo = cell(nLineas, 1);
    cdin = nan(nLineas, 1);
    pei = nan(nLineas, 1);
    peep = nan(nLineas, 1);
    vce = nan(nLineas, 1);
    vci = nan(nLineas, 1);
    fresp = nan(nLineas, 1);

    for
      i = 1 : nLineas linea = lineas{lineaData + 1 + i};
    partes = strsplit(linea, '\t');

    if length (partes)
      >= 9 && ~isempty(partes{1}) tiempo{i} = partes{1};
    cdin(i) = parseNum(partes{2});
    pei(i) = parseNum(partes{3});
    peep(i) = parseNum(partes{4});
    vce(i) = parseNum(partes{5});
    vci(i) = parseNum(partes{6});
    fresp(i) = parseNum(partes{9});
    end end

        validos = ~cellfun(@isempty, tiempo);
    datos = table(tiempo(validos), cdin(validos), pei(validos), peep(validos),
                  ... vce(validos), vci(validos), fresp(validos),
                  ... 'VariableNames',
                  {'Tiempo', 'Cdin', 'Pei', 'PEEP', 'Vce', 'Vci', 'Fresp'});
    end

        function valor = parseNum(str) str = strtrim(str);
    if isempty (str)
      || strcmp(str, '***') || strcmp(str, ' ') valor = NaN;
    else
      str = strrep(str, '#', '');
    valor = str2double(str);
    end end

        function[metadatos, datos] = cargarRecordingLocal(archivo) fid =
            fopen(archivo, 'r', 'n', 'UTF-8');
    contenido = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    lineas = contenido{1};

    metadatos.Modo = '';
    metadatos.Vt = 0;
    metadatos.PEEP = 0;
    metadatos.FR = 0;

    lineaData = find(startsWith(lineas, '[DATA]'));

    for
      i = 1 : lineaData - 1 linea = lineas{i};
    if contains (linea, 'gimen de ventilaci')
      partes = strsplit(linea, '\t');
    if length (partes)
      >= 2 metadatos.Modo = strtrim(partes{2});
    end elseif contains(linea, 'Volumen corriente') &&
        ~contains(linea, 'Vci') partes = strsplit(linea, '\t');
    if length (partes)
      >= 2 metadatos.Vt = str2double(partes{2});
    end elseif startsWith(linea, 'PEEP') partes = strsplit(linea, '\t');
    if length (partes)
      >= 2 metadatos.PEEP = str2double(partes{2});
    end elseif contains(linea, 'F resp.') partes = strsplit(linea, '\t');
    if length (partes)
      >= 2 metadatos.FR = str2double(partes{2});
    end end end

        nLineasDatos = length(lineas) - (lineaData + 1);
    tiempo = cell(nLineasDatos, 1);
    presion = zeros(nLineasDatos, 1);
    flujo = zeros(nLineasDatos, 1);
    volumen = zeros(nLineasDatos, 1);

    for
      i = 1 : nLineasDatos linea = lineas{lineaData + 1 + i};
    partes = strsplit(linea, '\t');

    if length (partes)
      >= 5 tiempo{i} = partes{1};
    presion(i) = str2double(partes{3});
    flujo(i) = str2double(partes{4});
    volumen(i) = str2double(partes{5});
    end end

        filasValidas = ~cellfun(@isempty, tiempo);
    datos =
        table(tiempo(filasValidas), presion(filasValidas), flujo(filasValidas),
              volumen(filasValidas), ... 'VariableNames',
              {'Tiempo', 'Presion', 'Flujo', 'Volumen'});
    end

        function tiempoSeg = convertirTiempoLocal(tiempoStr) n =
            length(tiempoStr);
    tiempoSeg = zeros(n, 1);

    for
      i = 1 : n partes = strsplit(tiempoStr{i}, ':');
    if length (partes)
      >= 4 horas = str2double(partes{1});
    minutos = str2double(partes{2});
    segundos = str2double(partes{3});
    miliseg = str2double(partes{4});
    tiempoSeg(i) = horas * 3600 + minutos * 60 + segundos + miliseg / 1000;
    end end end
