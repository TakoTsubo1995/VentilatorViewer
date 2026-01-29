function nombreEstandar = estandarizarColumnas(nombreOriginal)
% ESTANDARIZARCOLUMNAS - Convierte nombres de columnas a formato estándar
%
% Sintaxis:
%   nombreEstandar = estandarizarColumnas(nombreOriginal)
%
% Entrada:
%   nombreOriginal - Nombre de columna original del archivo SERVO-U
%
% Salida:
%   nombreEstandar - Nombre estandarizado para uso interno
%
% Mapeo de nombres comunes:
%   'Pva (cmH2O)'        -> 'presion_cmH2O'
%   'FLUJO (l/m)'        -> 'flujo_Lmin'
%   'V (ml)'             -> 'volumen_mL'
%   'Fase de respiración'-> 'fase'
%   'Tiempo'             -> 'tiempo'
%   'Cdin. (ml/cmH2O)'   -> 'Cdyn_mLcmH2O'
%   'PEEP (cmH2O)'       -> 'PEEP_cmH2O'
%   etc.
%
% Ver también: limpiarValores, parseRecording
%
% Autor: Proyecto Fisiología Respiratoria
% Fecha: 2026-01-28

% Limpiar nombre original
nombre = strtrim(nombreOriginal);

% Eliminar BOM si existe
if ~isempty(nombre) && (nombre(1) == 65279 || nombre(1) == 239)
    nombre = nombre(2:end);
end

% Diccionario de mapeo (original -> estándar)
mapeo = {
    % Recordings
    'Tiempo',                       'tiempo';
    'Fase de respiración',          'fase';
    'Pva (cmH2O)',                  'presion_cmH2O';
    'FLUJO (l/m)',                  'flujo_Lmin';
    'V (ml)',                       'volumen_mL';
    'Triger',                       'trigger';

    % Trends - Variables principales
    'F.espont. (resp/min)',         'FR_espont';
    'F resp. (resp/min)',           'FR';
    'Vci (ml)',                     'Vci_mL';
    'Vce. (ml)',                    'Vce_mL';
    'Ppico (cmH2O)',                'Ppico_cmH2O';
    'Ppausa (cmH2O)',               'Ppausa_cmH2O';
    'Pmedia (cmH2O)',               'Pmedia_cmH2O';
    'PEEP (cmH2O)',                 'PEEP_cmH2O';
    'VMe esp. (l/m)',               'VMe_esp_Lmin';
    'V.m.i. (l/m)',                 'VMi_Lmin';
    'VMe (l/m)',                    'VMe_Lmin';
    'Vc/PBW (ml/kg)',               'Vt_PBW_mLkg';
    'Vc/BW (ml/kg)',                'Vt_BW_mLkg';
    'Cdin. (ml/cmH2O)',             'Cdyn_mLcmH2O';
    'Cestática (ml/cmH2O)',         'Cst_mLcmH2O';
    'Conc. de O2 (%)',              'FiO2_pct';
    'Fuga (%)',                     'fuga_pct';
    'I:E',                          'IE';
    'IE',                           'IE_ratio';
    'Elastancia (cmH2O/l)',         'elastancia';
    'Ri (cmH2O/l/s)',               'Ri';
    'Re (cmH2O/l/s)',               'Re';
    'Trab r vent (J/l)',            'WOB_vent';
    'Trab. r. pac (J/l)',           'WOB_pac';
    'P 0,1 (cmH2O)',                'P01';
    'SBI',                          'SBI';
    'Flujoef (l/m)',                'flujo_ef';
    'Flujo (l/m)',                  'flujo_Lmin';
    'VENT_MODE',                    'modo_vent';
    'AUTOMODE_ON_OFF',              'automode';
    'NIV_ON_OFF',                   'NIV';
    'SYSTEM_MODE',                  'modo_sistema';
    'Pactividad (cmH2O)',           'Pactividad_cmH2O';
    'Edipico (uV)',                 'EDI_pico';
    'Edimín. (uV)',                 'EDI_min';
    'etCO2 (mmHg)',                 'etCO2_mmHg';
    'VcCO2',                        'VtCO2';
    'VCO2',                         'VCO2';

    % Recruitment específicos
    'Pei (cmH2O)',                  'Pei_cmH2O';
    'I:E ()',                       'IE';
    'PL ei (cmH2O)',                'PL_ei_cmH2O';
    'PL ee (cmH2O)',                'PL_ee_cmH2O';
    'PL activ. (cmH2O)',            'PL_activ_cmH2O';
};

% Buscar en el mapeo
nombreEstandar = '';
for i = 1:size(mapeo, 1)
    if strcmpi(nombre, mapeo{i, 1})
        nombreEstandar = mapeo{i, 2};
        return;
    end
end

% Si no está en el mapeo, generar nombre válido automáticamente
if isempty(nombreEstandar)
    nombreEstandar = generarNombreValido(nombre);
end

end


function nombre = generarNombreValido(original)
% GENERARNOMBREVALIDO - Genera un nombre de variable válido en MATLAB
%
% Convierte caracteres especiales y asegura que sea un identificador válido

nombre = original;

% Reemplazar caracteres especiales comunes
nombre = strrep(nombre, ' ', '_');
nombre = strrep(nombre, '.', '');
nombre = strrep(nombre, ',', '');
nombre = strrep(nombre, '/', '_');
nombre = strrep(nombre, '(', '_');
nombre = strrep(nombre, ')', '');
nombre = strrep(nombre, '%', 'pct');
nombre = strrep(nombre, ':', '_');
nombre = strrep(nombre, '-', '_');
nombre = strrep(nombre, '<', '');
nombre = strrep(nombre, '>', '');

% Eliminar caracteres no alfanuméricos restantes
nombre = regexprep(nombre, '[^a-zA-Z0-9_]', '');

% Eliminar underscores múltiples
nombre = regexprep(nombre, '_+', '_');

% Eliminar underscore al final
if ~isempty(nombre) && nombre(end) == '_'
    nombre = nombre(1:end-1);
end

% Asegurar que empiece con letra
if ~isempty(nombre) && ~isletter(nombre(1))
    nombre = ['var_' nombre];
end

% Si quedó vacío, usar nombre genérico
if isempty(nombre)
    nombre = 'variable';
end

% Limitar longitud
if length(nombre) > 63
    nombre = nombre(1:63);
end

end
