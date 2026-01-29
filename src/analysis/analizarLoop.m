function resultados = analizarLoop(datoX, datoY, nombreX, nombreY, opciones)
% ANALIZARLOOP - Analiza loops configurables de cualquier par de variables
%
% Sintaxis:
%   resultados = analizarLoop(datoX, datoY, nombreX, nombreY)
%   resultados = analizarLoop(datoX, datoY, nombreX, nombreY, opciones)
%
% Entradas:
%   datoX    - Vector de datos para eje X
%   datoY    - Vector de datos para eje Y
%   nombreX  - Nombre de la variable X (ej: 'Presion', 'Volumen', 'Flujo')
%   nombreY  - Nombre de la variable Y
%   opciones - (opcional) Estructura con opciones:
%              * colorearPorTiempo: true/false (default: true)
%              * calcularArea: true/false (default: true)
%              * mostrarEstadisticas: true/false (default: true)
%
% Salida:
%   resultados - Estructura con:
%                * area: Área del loop (si es cerrado)
%                * histeresis: Medida de histéresis
%                * pendienteInsp: Pendiente rama inspiratoria
%                * pendienteEsp: Pendiente rama espiratoria
%                * stats: Estadísticas descriptivas
%                * figHandle: Handle de la figura (si se grafica)
%
% Combinaciones típicas:
%   P-V: Presión vs Volumen → Compliance, WOB
%   F-V: Flujo vs Volumen → Obstrucción vía aérea
%   P-F: Presión vs Flujo → Resistencia
%   V-t: Volumen vs Tiempo → Patrón ventilatorio
%
% Ejemplo:
%   % Loop Presión-Volumen clásico
%   res = analizarLoop(presion, volumen, 'Presion', 'Volumen');
%
%   % Loop Flujo-Volumen
%   res = analizarLoop(volumen, flujo, 'Volumen', 'Flujo');
%
% Ver también: calcularMecanicaRespiratoria, VentilatorRecordingViewer
%
% Autor: Generado para proyecto de Fisiología Respiratoria
% Fecha: 2026-01-28
% Respaldo: No aplica (archivo nuevo)

% Opciones por defecto
if nargin < 5
    opciones = struct();
end
if ~isfield(opciones, 'colorearPorTiempo')
    opciones.colorearPorTiempo = true;
end
if ~isfield(opciones, 'calcularArea')
    opciones.calcularArea = true;
end
if ~isfield(opciones, 'mostrarEstadisticas')
    opciones.mostrarEstadisticas = true;
end
if ~isfield(opciones, 'graficar')
    opciones.graficar = false;
end

% Validar entradas
if length(datoX) ~= length(datoY)
    error('analizarLoop:dimension', 'Los vectores X e Y deben tener la misma longitud');
end

n = length(datoX);
resultados = struct();

% =====================================================
% ESTADÍSTICAS DESCRIPTIVAS
% =====================================================
resultados.stats = struct();
resultados.stats.X = struct('min', min(datoX), 'max', max(datoX), ...
    'media', mean(datoX), 'std', std(datoX));
resultados.stats.Y = struct('min', min(datoY), 'max', max(datoY), ...
    'media', mean(datoY), 'std', std(datoY));
resultados.stats.n = n;
resultados.nombreX = nombreX;
resultados.nombreY = nombreY;

% =====================================================
% ÁREA DEL LOOP (Shoelace formula)
% =====================================================
if opciones.calcularArea && n > 2
    % Fórmula del cordón (Shoelace) para área de polígono
    % A = 0.5 * |Σ(x_i * y_{i+1} - x_{i+1} * y_i)|
    area = 0.5 * abs(sum(datoX(1:end-1) .* datoY(2:end) - ...
        datoX(2:end) .* datoY(1:end-1)));
    resultados.area = area;

    % Interpretación según tipo de loop
    resultados.interpretacionArea = interpretarArea(nombreX, nombreY, area, datoY);
end

% =====================================================
% HISTÉRESIS
% Diferencia entre rama de ida y vuelta
% =====================================================
if n > 10
    mitad = round(n/2);
    ramaIda = 1:mitad;
    ramaVuelta = mitad:n;

    % Interpolar para comparar a los mismos valores de X
    xComun = linspace(min(datoX), max(datoX), 50);

    try
        yIda = interp1(datoX(ramaIda), datoY(ramaIda), xComun, 'linear', 'extrap');
        yVuelta = interp1(datoX(ramaVuelta), datoY(ramaVuelta), xComun, 'linear', 'extrap');

        % Histéresis = diferencia media entre ramas
        resultados.histeresis = mean(abs(yIda - yVuelta));
        resultados.histeresisMax = max(abs(yIda - yVuelta));
    catch
        resultados.histeresis = NaN;
        resultados.histeresisMax = NaN;
    end
else
    resultados.histeresis = NaN;
end

% =====================================================
% PENDIENTES
% =====================================================
if n > 5
    % Pendiente global (regresión lineal)
    coef = polyfit(datoX, datoY, 1);
    resultados.pendienteGlobal = coef(1);
    resultados.intercepto = coef(2);

    % R² del ajuste lineal
    yPred = polyval(coef, datoX);
    ssRes = sum((datoY - yPred).^2);
    ssTot = sum((datoY - mean(datoY)).^2);
    resultados.R2 = 1 - (ssRes / (ssTot + eps));

    % Pendientes por segmento (primero y segundo tercio)
    tercio1 = 1:round(n/3);
    tercio2 = round(n/3):round(2*n/3);

    if length(tercio1) > 2
        coef1 = polyfit(datoX(tercio1), datoY(tercio1), 1);
        resultados.pendienteInicio = coef1(1);
    end
    if length(tercio2) > 2
        coef2 = polyfit(datoX(tercio2), datoY(tercio2), 1);
        resultados.pendienteMedio = coef2(1);
    end
end

% =====================================================
% GRAFICAR (opcional)
% =====================================================
if opciones.graficar
    resultados.figHandle = graficarLoop(datoX, datoY, nombreX, nombreY, ...
        opciones, resultados);
end
end

% =========================================================================
% FUNCIONES AUXILIARES
% =========================================================================

function interpretacion = interpretarArea(nombreX, nombreY, area, datoY)
% Interpreta el área según el tipo de loop
interpretacion = struct();
interpretacion.valor = area;

% Loop Presión-Volumen
if (contains(lower(nombreX), 'pres') && contains(lower(nombreY), 'vol')) || ...
        (contains(lower(nombreY), 'pres') && contains(lower(nombreX), 'vol'))
    % Área = Trabajo respiratorio
    % Conversión: cmH2O × mL = 0.098 mJ
    Vt = max(datoY) - min(datoY);
    if Vt > 0
        WOB_JL = area * 0.098 / (Vt / 1000);
        interpretacion.tipo = 'Trabajo respiratorio';
        interpretacion.WOB = WOB_JL;
        interpretacion.unidad = 'J/L';
        interpretacion.descripcion = sprintf('WOB = %.2f J/L', WOB_JL);
    end

    % Loop Flujo-Volumen
elseif (contains(lower(nombreX), 'vol') && contains(lower(nombreY), 'flujo')) || ...
        (contains(lower(nombreY), 'vol') && contains(lower(nombreX), 'flujo'))
    interpretacion.tipo = 'Patrón flujo-volumen';
    interpretacion.descripcion = 'Área proporcional a trabajo viscoso';

    % Loop Presión-Flujo
elseif (contains(lower(nombreX), 'pres') && contains(lower(nombreY), 'flujo')) || ...
        (contains(lower(nombreY), 'pres') && contains(lower(nombreX), 'flujo'))
    interpretacion.tipo = 'Relación presión-flujo';
    interpretacion.descripcion = 'Pendiente relacionada con resistencia';

else
    interpretacion.tipo = 'Genérico';
    interpretacion.descripcion = 'Área calculada sin interpretación específica';
end
end

function fig = graficarLoop(datoX, datoY, nombreX, nombreY, opciones, resultados)
fig = figure('Name', sprintf('Loop %s vs %s', nombreX, nombreY), ...
    'NumberTitle', 'off', ...
    'Position', [100, 100, 800, 600]);

if opciones.colorearPorTiempo
    % Colorear por progresión temporal
    n = length(datoX);
    colors = parula(n);

    hold on;
    for i = 1:n-1
        plot([datoX(i), datoX(i+1)], [datoY(i), datoY(i+1)], ...
            'Color', colors(i,:), 'LineWidth', 1.5);
    end
    hold off;

    % Colorbar
    colormap(parula);
    cb = colorbar;
    cb.Label.String = 'Progresión temporal';
else
    % Color único
    plot(datoX, datoY, 'b-', 'LineWidth', 1.5);
end

xlabel(sprintf('%s', nombreX), 'FontWeight', 'bold');
ylabel(sprintf('%s', nombreY), 'FontWeight', 'bold');
title(sprintf('Loop %s - %s', nombreX, nombreY), 'FontWeight', 'bold');
grid on;

% Añadir estadísticas como texto
if opciones.mostrarEstadisticas && isfield(resultados, 'area')
    textStr = sprintf('Área: %.2f\nHistéresis: %.2f', ...
        resultados.area, resultados.histeresis);
    text(0.02, 0.98, textStr, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'BackgroundColor', 'white', ...
        'EdgeColor', 'black', 'FontSize', 9);
end
end
