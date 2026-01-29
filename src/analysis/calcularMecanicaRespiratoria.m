function mecanica = calcularMecanicaRespiratoria(ciclos, metadatos)
% CALCULARMECANICORESPIRATORIA - Calcula parámetros de mecánica respiratoria
%
% Sintaxis:
%   mecanica = calcularMecanicaRespiratoria(ciclos, metadatos)
%
% Entradas:
%   ciclos    - Estructura con ciclos detectados (de detectarCiclosRespiratorios)
%   metadatos - Estructura con metadatos del ventilador
%
% Salida:
%   mecanica  - Estructura con parámetros calculados por ciclo
%
% Parámetros calculados:
%   - Cst:        Compliance estática (mL/cmH2O)
%   - Cdyn:       Compliance dinámica (mL/cmH2O)
%   - Raw:        Resistencia vía aérea (cmH2O·s/L)
%   - DrivingP:   Driving Pressure / Presión de distensión (cmH2O)
%   - WOB:        Trabajo respiratorio - área del loop P-V (J/L)
%   - Tau:        Constante de tiempo (s)
%   - StressIdx:  Índice de estrés (forma de curva P-t)
%
% Ejemplo:
%   ciclos = detectarCiclosRespiratorios(datosResp, tiempoSeg);
%   mecanica = calcularMecanicaRespiratoria(ciclos, metadatos);
%
% Ver también: detectarCiclosRespiratorios, VentilatorRecordingViewer
%
% Autor: Generado para proyecto de Fisiología Respiratoria
% Fecha: 2026-01-28
% Respaldo: No aplica (archivo nuevo)

% Validar entrada
if isempty(ciclos) || ~isstruct(ciclos)
    error('calcularMecanicaRespiratoria:entrada', ...
        'Se requiere estructura de ciclos válida');
end

nCiclos = length(ciclos);

% Preasignar estructuras de salida
mecanica = struct();
mecanica.Cst = nan(nCiclos, 1);
mecanica.Cdyn = nan(nCiclos, 1);
mecanica.Raw = nan(nCiclos, 1);
mecanica.DrivingP = nan(nCiclos, 1);
mecanica.WOB = nan(nCiclos, 1);
mecanica.Tau = nan(nCiclos, 1);
mecanica.StressIdx = nan(nCiclos, 1);
mecanica.Ppico = nan(nCiclos, 1);
mecanica.Pplateau = nan(nCiclos, 1);
mecanica.PEEP = nan(nCiclos, 1);
mecanica.Vti = nan(nCiclos, 1);
mecanica.Vte = nan(nCiclos, 1);
mecanica.FlujoPico = nan(nCiclos, 1);
mecanica.Ti = nan(nCiclos, 1);
mecanica.Te = nan(nCiclos, 1);
mecanica.tiempoCiclo = nan(nCiclos, 1);

% Calcular para cada ciclo
for i = 1:nCiclos
    ciclo = ciclos(i);

    % Extraer datos del ciclo
    presion = ciclo.presion;
    volumen = ciclo.volumen;
    flujo = ciclo.flujo;
    fases = ciclo.fases;
    tiempo = ciclo.tiempo;

    % --- Identificar fases ---
    esInsp = contains(fases, 'insp');
    esPausa = contains(fases, 'pausa');
    esEsp = contains(fases, 'esp');

    % --- Presión pico (máxima durante inspiración) ---
    if any(esInsp)
        mecanica.Ppico(i) = max(presion(esInsp));
    end

    % --- Presión meseta (promedio durante pausa inspiratoria) ---
    if any(esPausa)
        % Tomar la parte estable de la pausa (últimos 50%)
        idxPausa = find(esPausa);
        nPausa = length(idxPausa);
        if nPausa > 4
            idxEstable = idxPausa(round(nPausa/2):end);
            mecanica.Pplateau(i) = mean(presion(idxEstable));
        else
            mecanica.Pplateau(i) = mean(presion(esPausa));
        end
    else
        % Sin pausa, usar el pico como aproximación
        mecanica.Pplateau(i) = mecanica.Ppico(i);
    end

    % --- PEEP (presión al final de espiración) ---
    if any(esEsp)
        % Tomar los últimos puntos de la espiración
        idxEsp = find(esEsp);
        nEsp = length(idxEsp);
        if nEsp > 10
            idxFin = idxEsp(max(1, nEsp-10):nEsp);
            mecanica.PEEP(i) = mean(presion(idxFin));
        else
            mecanica.PEEP(i) = min(presion(esEsp));
        end
    elseif isfield(metadatos, 'PEEP')
        mecanica.PEEP(i) = metadatos.PEEP;
    end

    % --- Volúmenes ---
    mecanica.Vti(i) = max(volumen) - min(volumen(esInsp | esPausa));
    if any(esEsp)
        mecanica.Vte(i) = max(volumen(esEsp)) - min(volumen);
    end

    % --- Flujo pico inspiratorio ---
    if any(esInsp)
        mecanica.FlujoPico(i) = max(flujo(esInsp));
    end

    % --- Tiempos ---
    if any(esInsp)
        tInsp = tiempo(esInsp);
        mecanica.Ti(i) = max(tInsp) - min(tInsp);
        if any(esPausa)
            tPausa = tiempo(esPausa);
            mecanica.Ti(i) = max(tPausa) - min(tInsp);
        end
    end
    if any(esEsp)
        tEsp = tiempo(esEsp);
        mecanica.Te(i) = max(tEsp) - min(tEsp);
    end
    mecanica.tiempoCiclo(i) = max(tiempo) - min(tiempo);

    % =====================================================
    % CÁLCULOS DE MECÁNICA RESPIRATORIA
    % =====================================================

    Pplateau = mecanica.Pplateau(i);
    PEEP = mecanica.PEEP(i);
    Ppico = mecanica.Ppico(i);
    Vt = mecanica.Vti(i);
    FlujoPico = mecanica.FlujoPico(i);

    % --- Driving Pressure (ΔP) ---
    % ΔP = Pplateau - PEEP
    % Predictor de mortalidad en ARDS (objetivo < 15 cmH2O)
    if ~isnan(Pplateau) && ~isnan(PEEP)
        mecanica.DrivingP(i) = Pplateau - PEEP;
    end

    % --- Compliance Estática (Cst) ---
    % Cst = Vt / (Pplateau - PEEP)
    % Mide elasticidad pulmonar sin influencia de flujo
    % Normal: 60-100 mL/cmH2O
    denomCst = Pplateau - PEEP;
    if ~isnan(Vt) && denomCst > 0.1
        mecanica.Cst(i) = Vt / denomCst;
    end

    % --- Compliance Dinámica (Cdyn) ---
    % Cdyn = Vt / (Ppico - PEEP)
    % Incluye resistencia de vía aérea
    denomCdyn = Ppico - PEEP;
    if ~isnan(Vt) && denomCdyn > 0.1
        mecanica.Cdyn(i) = Vt / denomCdyn;
    end

    % --- Resistencia Vía Aérea (Raw) ---
    % Raw = (Ppico - Pplateau) / Flujo
    % Flujo en L/s, Presión en cmH2O → Raw en cmH2O·s/L
    % Normal: 2-4 cmH2O·s/L
    if ~isnan(Ppico) && ~isnan(Pplateau) && FlujoPico > 0
        % Convertir flujo de L/min a L/s
        flujoLs = FlujoPico / 60;
        mecanica.Raw(i) = (Ppico - Pplateau) / flujoLs;
    end

    % --- Constante de Tiempo (τ) ---
    % τ = Cst × Raw
    % Tiempo para 63% del vaciado pasivo
    % Normal: 0.3-0.5 s (adulto sano)
    if ~isnan(mecanica.Cst(i)) && ~isnan(mecanica.Raw(i))
        % Cst en mL/cmH2O, Raw en cmH2O·s/L
        % τ = (mL/cmH2O) × (cmH2O·s/L) × (1L/1000mL) = s
        mecanica.Tau(i) = (mecanica.Cst(i) / 1000) * mecanica.Raw(i);
    end

    % --- Trabajo Respiratorio (WOB) ---
    % WOB = ∫ P dV (área del loop P-V)
    % Calculado numéricamente con trapz
    % Unidades: cmH2O × mL = 0.1 mJ, convertimos a J/L
    if length(presion) > 10 && length(volumen) > 10
        % Área total del loop (inspiración + espiración)
        areaLoop = abs(trapz(volumen, presion));
        % Convertir: (cmH2O × mL) / (Vt mL) × factor
        % 1 cmH2O = 98.0665 Pa, 1 mL = 1e-6 m³
        % WOB = área × 98.0665 × 1e-6 / (Vt × 1e-6) = área × 98.0665 / Vt
        % Simplificando a J/L:
        if Vt > 0
            mecanica.WOB(i) = areaLoop * 0.098 / (Vt / 1000);
        end
    end

    % --- Índice de Estrés ---
    % Análisis de la forma de la curva Presión-Tiempo
    % < 1: Colapso/reclutamiento (curva cóncava)
    % = 1: Lineal (ventilación óptima)
    % > 1: Sobredistensión (curva convexa)
    if any(esInsp) && sum(esInsp) > 10
        pInsp = presion(esInsp);
        tInsp = tiempo(esInsp);
        tNorm = (tInsp - min(tInsp)) / (max(tInsp) - min(tInsp));
        pNorm = (pInsp - min(pInsp)) / (max(pInsp) - min(pInsp) + eps);

        % Ajuste polinómico de grado 2
        % P = a·t² + b·t + c
        if length(tNorm) > 5
            try
                coef = polyfit(tNorm, pNorm, 2);
                % El coeficiente 'a' indica la curvatura
                % a > 0: convexa (sobredistensión)
                % a < 0: cóncava (reclutamiento)
                % a ≈ 0: lineal (óptimo)
                % Convertimos a índice centrado en 1
                mecanica.StressIdx(i) = 1 + coef(1);
            catch
                % Si falla el ajuste, dejar NaN
            end
        end
    end

    % --- Análisis de Resistencia Instantánea vs Volumen ---
    % Permite ver cómo varía la resistencia durante el ciclo
    % Raw instantánea = (P - Palv_estimada) / Flujo
    % Elastancia = dP/dV (derivada presión-volumen)
    if length(presion) > 20 && length(volumen) > 20 && length(flujo) > 20
        try
            % Estimar presión alveolar (Palv ≈ PEEP + V/C)
            Cest = mecanica.Cst(i);
            if isnan(Cest) || Cest <= 0
                Cest = 50; % Valor típico si no hay cálculo
            end
            Palv_est = PEEP + (volumen - min(volumen)) / Cest;

            % Resistencia instantánea (solo donde hay flujo significativo)
            flujoLs = flujo / 60;  % L/min -> L/s
            flujoValido = abs(flujoLs) > 0.05;  % Umbral mínimo

            RawInst = nan(size(flujo));
            RawInst(flujoValido) = (presion(flujoValido) - Palv_est(flujoValido)) ./ flujoLs(flujoValido);

            % Suavizar y limitar valores extremos
            RawInst = movmean(RawInst, 5, 'omitnan');
            RawInst(RawInst < 0 | RawInst > 50) = NaN;

            % Elastancia instantánea (dP/dV)
            dP = diff(presion);
            dV = diff(volumen);
            dV(abs(dV) < 0.1) = NaN;  % Evitar división por cero
            ElastInst = dP ./ dV * 1000;  % cmH2O/L
            ElastInst = [ElastInst; ElastInst(end)];  % Mantener tamaño
            ElastInst = movmean(ElastInst, 5, 'omitnan');
            ElastInst(ElastInst < 0 | ElastInst > 100) = NaN;

            % Volumen normalizado (0-1)
            VolNorm = (volumen - min(volumen)) / (max(volumen) - min(volumen) + eps);

            % Guardar curvas en estructura mecanica
            mecanica.curvasInstantaneas{i} = struct(...
                'volumen', volumen, ...
                'volumenNorm', VolNorm, ...
                'rawInstantanea', RawInst, ...
                'conductanciaInstantanea', 1 ./ RawInst, ...  % G = 1/R
                'elastancia', ElastInst, ...
                'presion', presion, ...
                'flujo', flujo);

        catch
            mecanica.curvasInstantaneas{i} = [];
        end
    else
        mecanica.curvasInstantaneas{i} = [];
    end
end

% Agregar estadísticas globales
mecanica.media = struct();
mecanica.media.Cst = nanmean(mecanica.Cst);
mecanica.media.Cdyn = nanmean(mecanica.Cdyn);
mecanica.media.Raw = nanmean(mecanica.Raw);
mecanica.media.DrivingP = nanmean(mecanica.DrivingP);
mecanica.media.WOB = nanmean(mecanica.WOB);
mecanica.media.Tau = nanmean(mecanica.Tau);
mecanica.media.StressIdx = nanmean(mecanica.StressIdx);

mecanica.std = struct();
mecanica.std.Cst = nanstd(mecanica.Cst);
mecanica.std.Cdyn = nanstd(mecanica.Cdyn);
mecanica.std.Raw = nanstd(mecanica.Raw);
mecanica.std.DrivingP = nanstd(mecanica.DrivingP);

mecanica.nCiclos = nCiclos;
mecanica.unidades = struct(...
    'Cst', 'mL/cmH2O', ...
    'Cdyn', 'mL/cmH2O', ...
    'Raw', 'cmH2O·s/L', ...
    'DrivingP', 'cmH2O', ...
    'WOB', 'J/L', ...
    'Tau', 's', ...
    'StressIdx', 'adimensional', ...
    'Presiones', 'cmH2O', ...
    'Volumenes', 'mL', ...
    'Flujos', 'L/min', ...
    'Tiempos', 's');
end
