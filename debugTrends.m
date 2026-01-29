% debugTrends.m - Script de diagnóstico para archivos BreathTrends
% Ejecutar desde Command Window: debugTrends

addpath('src/loaders');

archivo = 'ventilatorData/trends/SERVO-U_42376_260128-172511_BreathTrends.txt';

fprintf('Cargando: %s\n\n', archivo);
[meta, datos] = cargarTrends(archivo);

fprintf('Tipo de archivo: %s\n', meta.Tipo);
fprintf('Número de registros: %d\n\n', height(datos));

fprintf('=== COLUMNAS ENCONTRADAS ===\n');
varNames = datos.Properties.VariableNames;
for i = 1:length(varNames)
    fprintf('[%d] %s\n', i, varNames{i});
end

fprintf('\n=== BÚSQUEDA DE COLUMNAS ===\n');
varNamesLower = lower(varNames);

cdynCol = find(contains(varNamesLower, 'cdyn') | contains(varNamesLower, 'cdin'), 1);
fprintf('Columna Cdyn/Cdin: %s (índice %d)\n', varNames{cdynCol}, cdynCol);

peepCol = find(contains(varNamesLower, 'peep'), 1);
fprintf('Columna PEEP: %s (índice %d)\n', varNames{peepCol}, peepCol);

vciCol = find(contains(varNamesLower, 'vci'), 1);
fprintf('Columna Vci: %s (índice %d)\n', varNames{vciCol}, vciCol);

fprintf('\n=== MUESTRA DE DATOS (primeras 10 filas de Cdyn) ===\n');
raw = datos{1:10, cdynCol};
disp(raw);

fprintf('\n=== TIPO DE DATO ===\n');
fprintf('Clase de la columna Cdyn: %s\n', class(datos{1, cdynCol}));
