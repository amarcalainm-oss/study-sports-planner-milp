%% Reproduce todos los experimentos de la memoria y guarda los resultados en results/
% Ejecutar desde la carpeta src/.

clear; close all; clc;
addpath('C:\Program Files\IBM\ILOG\CPLEX_Studio1210\cplex\matlab\x64_win64');

escenarios = {
    'exp1a_base'                 % Exp. I  - calendario balanceado
    'exp1b_sprint_intenso'       % Exp. I  - sprint final de 15 h en 5 dias
    'exp1c_prioridad_descanso'   % Exp. I  - gamma > beta
    'exp1d_saturacion_descanso'  % Exp. I  - gamma muy alto
    'exp2_calendario_real'       % Exp. II - calendario real (27 abril - 29 mayo)
};

carpeta_salida = fullfile('..', 'results');
if ~exist(carpeta_salida, 'dir'), mkdir(carpeta_salida); end

resultados = cell(numel(escenarios), 1);
for i = 1:numel(escenarios)
    resultados{i} = resolver_escenario(fullfile('..', 'data', [escenarios{i} '.xlsx']), carpeta_salida);
end

% Tabla comparativa
T = struct2table(cellfun(@(r) rmfield_safe(r), resultados));
writetable(T, fullfile(carpeta_salida, 'resumen_experimentos.csv'), 'Encoding', 'UTF-8');
disp(T);

function s = rmfield_safe(r)
    campos = {'escenario', 'status', 'objetivo', 'horas_estudio', 'horas_deporte', 'horas_descanso', 'dias_max_carga', 'tiempo_s'};
    for k = 1:numel(campos)
        if isfield(r, campos{k}), s.(campos{k}) = r.(campos{k}); else, s.(campos{k}) = NaN; end
    end
end
