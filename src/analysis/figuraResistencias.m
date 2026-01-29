function figuraResistencias(mecanica, ciclos)
% FIGURARESISTENCIAS - Figura interactiva de análisis de resistencias
%
% Muestra resistencia, conductancia y elastancia vs volumen
% con selector de ciclo individual o promedio
%
% Sintaxis:
%   figuraResistencias(mecanica, ciclos)
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-29

nCiclos = length(ciclos);
if nCiclos == 0
    errordlg('No hay ciclos para analizar', 'Error');
    return;
end

% Verificar datos instantáneos
hayCurvasInst = isfield(mecanica, 'curvasInstantaneas') && ...
    ~isempty(mecanica.curvasInstantaneas);

% Crear figura
fig = figure('Name', 'Análisis de Resistencias vs Volumen', ...
    'NumberTitle', 'off', 'Position', [50, 50, 1200, 800], 'Color', 'w');

% --- Panel de control ---
uicontrol(fig, 'Style', 'text', 'String', 'Seleccionar ciclo:', ...
    'Position', [20, 760, 100, 20], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold');

% Opciones del dropdown
opciones = cell(1, nCiclos + 1);
opciones{1} = 'PROMEDIO (todos)';
for i = 1:nCiclos
    opciones{i+1} = sprintf('Ciclo %d', i);
end

cicloDropdown = uicontrol(fig, 'Style', 'popupmenu', ...
    'String', opciones, 'Position', [120, 760, 150, 25], ...
    'Value', 1, 'Callback', @actualizarGraficos);

% Panel de info
infoText = uicontrol(fig, 'Style', 'text', 'String', '', ...
    'Position', [300, 755, 400, 30], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'FontSize', 10);

% Almacenar datos en figura
setappdata(fig, 'mecanica', mecanica);
setappdata(fig, 'ciclos', ciclos);
setappdata(fig, 'nCiclos', nCiclos);
setappdata(fig, 'hayCurvasInst', hayCurvasInst);
setappdata(fig, 'infoText', infoText);

% Dibujar inicial (promedio)
actualizarGraficos(cicloDropdown, []);

% --- Función callback ---
    function actualizarGraficos(src, ~)
        seleccion = get(src, 'Value');
        mecanica = getappdata(fig, 'mecanica');
        ciclos = getappdata(fig, 'ciclos');
        nCiclos = getappdata(fig, 'nCiclos');
        hayCurvasInst = getappdata(fig, 'hayCurvasInst');
        infoText = getappdata(fig, 'infoText');

        % Limpiar ejes existentes
        delete(findall(fig, 'Type', 'axes'));

        % Colores
        colores = parula(max(nCiclos, 1));

        if seleccion == 1
            % PROMEDIO - mostrar todos los ciclos superpuestos
            mostrarPromedio = true;
            ciclosAMostrar = 1:nCiclos;
            tituloBase = 'PROMEDIO';

            % Info del promedio
            set(infoText, 'String', sprintf(...
                'Raw media: %.2f cmH2O·s/L | Cst media: %.1f mL/cmH2O | Driving P: %.1f cmH2O', ...
                mecanica.media.Raw, mecanica.media.Cst, mecanica.media.DrivingP));
        else
            % Ciclo individual
            mostrarPromedio = false;
            cicloIdx = seleccion - 1;
            ciclosAMostrar = cicloIdx;
            tituloBase = sprintf('Ciclo %d', cicloIdx);

            % Info del ciclo
            set(infoText, 'String', sprintf(...
                'Raw: %.2f cmH2O·s/L | Cst: %.1f mL/cmH2O | Driving P: %.1f cmH2O | Vti: %.0f mL', ...
                mecanica.Raw(cicloIdx), mecanica.Cst(cicloIdx), ...
                mecanica.DrivingP(cicloIdx), mecanica.Vti(cicloIdx)));
        end

        % --- Subplot 1: Resistencia vs Volumen ---
        ax1 = subplot(2, 3, 1, 'Parent', fig);
        hold(ax1, 'on');
        if hayCurvasInst
            for idx = ciclosAMostrar
                if idx <= length(mecanica.curvasInstantaneas)
                    curva = mecanica.curvasInstantaneas{idx};
                    if ~isempty(curva) && isfield(curva, 'rawInstantanea')
                        if mostrarPromedio
                            plot(ax1, curva.volumen, curva.rawInstantanea, ...
                                'Color', [colores(idx, :), 0.5], 'LineWidth', 1);
                        else
                            plot(ax1, curva.volumen, curva.rawInstantanea, ...
                                'Color', 'b', 'LineWidth', 2);
                        end
                    end
                end
            end
        end
        hold(ax1, 'off');
        xlabel(ax1, 'Volumen (mL)');
        ylabel(ax1, 'Raw (cmH2O·s/L)');
        title(ax1, sprintf('Resistencia vs Volumen - %s', tituloBase), 'FontWeight', 'bold');
        grid(ax1, 'on');
        ylim(ax1, [0, 15]);

        % --- Subplot 2: Conductancia vs Volumen ---
        ax2 = subplot(2, 3, 2, 'Parent', fig);
        hold(ax2, 'on');
        if hayCurvasInst
            for idx = ciclosAMostrar
                if idx <= length(mecanica.curvasInstantaneas)
                    curva = mecanica.curvasInstantaneas{idx};
                    if ~isempty(curva) && isfield(curva, 'conductanciaInstantanea')
                        if mostrarPromedio
                            plot(ax2, curva.volumen, curva.conductanciaInstantanea, ...
                                'Color', [colores(idx, :), 0.5], 'LineWidth', 1);
                        else
                            plot(ax2, curva.volumen, curva.conductanciaInstantanea, ...
                                'Color', [0 0.6 0], 'LineWidth', 2);
                        end
                    end
                end
            end
        end
        hold(ax2, 'off');
        xlabel(ax2, 'Volumen (mL)');
        ylabel(ax2, 'Conductancia G = 1/R (L/(s·cmH2O))');
        title(ax2, sprintf('Conductancia vs Volumen - %s', tituloBase), 'FontWeight', 'bold');
        grid(ax2, 'on');

        % --- Subplot 3: Elastancia vs Volumen ---
        ax3 = subplot(2, 3, 3, 'Parent', fig);
        hold(ax3, 'on');
        if hayCurvasInst
            for idx = ciclosAMostrar
                if idx <= length(mecanica.curvasInstantaneas)
                    curva = mecanica.curvasInstantaneas{idx};
                    if ~isempty(curva) && isfield(curva, 'elastancia')
                        if mostrarPromedio
                            plot(ax3, curva.volumen, curva.elastancia, ...
                                'Color', [colores(idx, :), 0.5], 'LineWidth', 1);
                        else
                            plot(ax3, curva.volumen, curva.elastancia, ...
                                'Color', [0.8 0.3 0], 'LineWidth', 2);
                        end
                    end
                end
            end
        end
        hold(ax3, 'off');
        xlabel(ax3, 'Volumen (mL)');
        ylabel(ax3, 'Elastancia dP/dV (cmH2O/L)');
        title(ax3, sprintf('Elastancia vs Volumen - %s', tituloBase), 'FontWeight', 'bold');
        grid(ax3, 'on');

        % --- Subplot 4: Loop P-V del ciclo ---
        ax4 = subplot(2, 3, 4, 'Parent', fig);
        hold(ax4, 'on');
        for idx = ciclosAMostrar
            ciclo = ciclos(idx);
            if ~isempty(ciclo.presion) && ~isempty(ciclo.volumen)
                if mostrarPromedio
                    plot(ax4, ciclo.presion, ciclo.volumen, ...
                        'Color', [colores(idx, :), 0.5], 'LineWidth', 1);
                else
                    plot(ax4, ciclo.presion, ciclo.volumen, 'b-', 'LineWidth', 2);
                    % Marcar puntos clave
                    [~, iPpico] = max(ciclo.presion);
                    plot(ax4, ciclo.presion(iPpico), ciclo.volumen(iPpico), 'ro', ...
                        'MarkerSize', 10, 'MarkerFaceColor', 'r');
                    plot(ax4, ciclo.presion(1), ciclo.volumen(1), 'go', ...
                        'MarkerSize', 10, 'MarkerFaceColor', 'g');
                end
            end
        end
        hold(ax4, 'off');
        xlabel(ax4, 'Presión (cmH2O)');
        ylabel(ax4, 'Volumen (mL)');
        title(ax4, sprintf('Loop P-V - %s', tituloBase), 'FontWeight', 'bold');
        grid(ax4, 'on');
        if ~mostrarPromedio
            legend(ax4, {'Loop', 'Ppico', 'Inicio'}, 'Location', 'best');
        end

        % --- Subplot 5: Resumen por ciclo ---
        ax5 = subplot(2, 3, 5, 'Parent', fig);
        Raw = mecanica.Raw;
        Cst = mecanica.Cst;

        yyaxis(ax5, 'left');
        bh = bar(ax5, Raw, 'FaceColor', [0.3 0.6 0.9], 'FaceAlpha', 0.7);
        ylabel(ax5, 'Raw (cmH2O·s/L)');
        if any(~isnan(Raw))
            ylim(ax5, [0, max(Raw(~isnan(Raw)))*1.3 + 0.1]);
        end

        % Resaltar ciclo seleccionado
        if ~mostrarPromedio
            hold(ax5, 'on');
            bar(ax5, cicloIdx, Raw(cicloIdx), 'FaceColor', 'r', 'FaceAlpha', 0.9);
            hold(ax5, 'off');
        end

        yyaxis(ax5, 'right');
        plot(ax5, Cst, 'g-o', 'LineWidth', 2, 'MarkerFaceColor', 'g');
        ylabel(ax5, 'Cst (mL/cmH2O)');

        xlabel(ax5, 'Ciclo #');
        title(ax5, 'Resumen: Raw y Compliance por Ciclo', 'FontWeight', 'bold');
        legend(ax5, {'Raw', 'Cst'}, 'Location', 'best');
        grid(ax5, 'on');

        % Añadir colorbar con etiqueta para el promedio
        if mostrarPromedio
            ax6 = subplot(2, 3, 6, 'Parent', fig);
            colormap(ax6, parula(nCiclos));
            cb = colorbar(ax6);
            cb.Label.String = 'Número de Ciclo';
            cb.Ticks = linspace(0, 1, min(nCiclos, 10));
            cb.TickLabels = round(linspace(1, nCiclos, min(nCiclos, 10)));
            caxis(ax6, [1, nCiclos]);
            axis(ax6, 'off');
            title(ax6, 'Leyenda de Colores', 'FontWeight', 'bold');

            % Añadir texto explicativo
            text(ax6, 0.5, 0.3, {...
                'Colores = N° de ciclo', ...
                'Amarillo = ciclos tardíos', ...
                'Azul oscuro = ciclos tempranos'}, ...
                'HorizontalAlignment', 'center', 'FontSize', 10);
        else
            % Para ciclo individual, mostrar tabla de valores
            ax6 = subplot(2, 3, 6, 'Parent', fig);
            axis(ax6, 'off');

            datos = {
                'Parámetro', 'Valor', 'Unidad';
                'Raw', sprintf('%.2f', mecanica.Raw(cicloIdx)), 'cmH2O·s/L';
                'Cst', sprintf('%.1f', mecanica.Cst(cicloIdx)), 'mL/cmH2O';
                'Cdyn', sprintf('%.1f', mecanica.Cdyn(cicloIdx)), 'mL/cmH2O';
                'Driving P', sprintf('%.1f', mecanica.DrivingP(cicloIdx)), 'cmH2O';
                'Vti', sprintf('%.0f', mecanica.Vti(cicloIdx)), 'mL';
                'Ppico', sprintf('%.1f', mecanica.Ppico(cicloIdx)), 'cmH2O';
                'PEEP', sprintf('%.1f', mecanica.PEEP(cicloIdx)), 'cmH2O';
                };

            % Crear tabla visual
            for row = 1:size(datos, 1)
                ypos = 0.9 - (row-1)*0.1;
                fontW = 'normal';
                if row == 1, fontW = 'bold'; end
                text(ax6, 0.1, ypos, datos{row, 1}, 'FontWeight', fontW, 'FontSize', 10);
                text(ax6, 0.5, ypos, datos{row, 2}, 'FontWeight', fontW, 'FontSize', 10);
                text(ax6, 0.75, ypos, datos{row, 3}, 'FontWeight', fontW, 'FontSize', 10);
            end
            title(ax6, sprintf('Valores Ciclo %d', cicloIdx), 'FontWeight', 'bold');
        end

        % Título general
        sgtitle(fig, {...
            'Análisis de Resistencias Respiratorias', ...
            'Fisiología: ↑Volumen → Bronquios dilatados → ↓Resistencia → ↑Conductancia'}, ...
            'FontSize', 12, 'FontWeight', 'bold');
    end
end
