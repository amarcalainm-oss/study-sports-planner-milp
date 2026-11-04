function res = resolver_escenario(archivo, carpeta_salida)
% RESOLVER_ESCENARIO  Lee un escenario desde Excel, construye el MILP,
% lo resuelve con CPLEX y exporta la planificacion (figura, CSV y resumen).
%
%   res = resolver_escenario('../data/exp2_calendario_real.xlsx', '../results')
%
% El Excel tiene tres hojas:
%   Asignaturas : Asignatura | Horas_totales | Dia_examen
%   Dias        : Capacidad  | TipoDia (1 = laborable, 2 = fin de semana)
%   Parametros  : Descripcion | Valor (10 parametros, ver main.m)

if nargin < 2, carpeta_salida = fullfile('..', 'results'); end
[~, nombre_escenario] = fileparts(archivo);

%% 1. CARGA DE DATOS
T_asig = readtable(archivo, 'Sheet', 'Asignaturas', 'VariableNamingRule', 'preserve');
nombres_asignaturas = cellstr(string(T_asig{:, 1}))';
Asignaturas = T_asig{:, 2:3};                        % [Horas_totales, Dia_examen]
Dias = readmatrix(archivo, 'Sheet', 'Dias');          % [Capacidad, TipoDia]
VectParams = readmatrix(archivo, 'Sheet', 'Parametros', 'Range', 'B2:B11');

Params.min_estudio     = VectParams(1);  % Sesion minima de estudio
Params.max_estudio     = VectParams(2);  % Maximo de estudio por asignatura y dia
Params.min_deporte     = VectParams(3);  % Sesion minima de deporte
Params.max_deporte     = VectParams(4);  % Sesion maxima de deporte
Params.deporte_semanal = VectParams(5);  % Meta semanal de deporte
Params.sprint_horas    = VectParams(6);  % Horas minimas en el sprint previo al examen
Params.sprint_dias     = VectParams(7);  % Ventana de dias del sprint
Params.beta            = VectParams(8);  % Factor alivio deporte
Params.gamma           = VectParams(9);  % Factor alivio descanso
Params.alpha           = VectParams(10); % Factor de penalizacion por cercania al examen

data  = Rec_Datos(Asignaturas, Dias, Params);
model = buildModel(data);

%% 2. RESOLUCION CON CPLEX
cplex = Cplex(nombre_escenario);
cplex.DisplayFunc = [];                 % sin log del solver por pantalla
cplex.Model = model;
cplex.Model.sense = 'minimize';
t0 = tic;
cplex.solve();
t_sol = toc(t0);

res.escenario = nombre_escenario;
res.status    = cplex.Solution.statusstring;
res.tiempo_s  = t_sol;

if ~isfield(cplex.Solution, 'x') || isempty(cplex.Solution.x)
    fprintf('[%s] Sin solucion: %s\n', nombre_escenario, res.status);
    cplex.writeIIS(fullfile(carpeta_salida, [nombre_escenario '_conflicto.ilp']));
    return
end

x_sol = cplex.Solution.x;
res.objetivo = cplex.Solution.objval;

%% 3. EXTRACCION DE LA SOLUCION
nA = data.nA; nD = data.nD;
nx = nA*nD; ny = nA*nD; ne = nD; nz = nD;
idx_x = @(a,d) (a-1)*nD + d;
idx_e = @(d) nx + ny + d;
idx_r = @(d) nx + ny + ne + nz + d;

estudio = zeros(nA, nD);
for a = 1:nA
    for d = 1:nD
        estudio(a, d) = x_sol(idx_x(a,d));
    end
end
deporte  = arrayfun(idx_e, 1:nD); deporte  = x_sol(deporte)';
descanso = arrayfun(idx_r, 1:nD); descanso = x_sol(descanso)';
estudio(abs(estudio) < 1e-6) = 0; deporte(abs(deporte) < 1e-6) = 0; descanso(abs(descanso) < 1e-6) = 0;

res.horas_estudio  = sum(estudio(:));
res.horas_deporte  = sum(deporte);
res.horas_descanso = sum(descanso);
res.dias_max_carga = sum(sum(estudio,1) + deporte >= data.capacidad' - 1e-6);

%% 4. EXPORTAR PLAN (CSV)
T_plan = array2table([(1:nD)', estudio', deporte', descanso', data.capacidad], ...
    'VariableNames', [{'Dia'}, nombres_asignaturas, {'Deporte', 'Descanso', 'Capacidad'}]);
writetable(T_plan, fullfile(carpeta_salida, [nombre_escenario '_plan.csv']), 'Encoding', 'UTF-8');

%% 5. RESUMEN (comprobacion de restricciones)
fid = fopen(fullfile(carpeta_salida, [nombre_escenario '_resumen.txt']), 'w', 'n', 'UTF-8');
fprintf(fid, 'Escenario: %s\nEstado CPLEX: %s\nValor objetivo: %.4f\nTiempo de resolucion: %.2f s\n', ...
    nombre_escenario, res.status, res.objetivo, t_sol);
fprintf(fid, 'Variables: %d (binarias: %d) | Restricciones: %d\n\n', ...
    numel(model.obj), sum(model.ctype == 'B'), size(model.A, 1));
fprintf(fid, '%-30s %9s %9s %9s %12s\n', 'Asignatura', 'Requeridas', 'Asignadas', 'Examen', 'Sprint (h)');
for a = 1:nA
    ini = max(1, data.D_exam(a) - data.sprint_dias);
    sprint = sum(estudio(a, ini:data.D_exam(a)-1));
    fprintf(fid, '%-30s %9.1f %9.1f %9d %12.1f\n', nombres_asignaturas{a}, data.horas(a), ...
        sum(estudio(a, :)), data.D_exam(a), sprint);
end
fprintf(fid, '\nTotal estudio: %.1f h | Deporte: %.1f h | Descanso: %.1f h\n', ...
    res.horas_estudio, res.horas_deporte, res.horas_descanso);
fprintf(fid, 'Dias con la capacidad completa: %d de %d\n', res.dias_max_carga, nD);
fclose(fid);

%% 6. VISUALIZACION
Visualizacion_Matriz = [estudio; deporte; descanso];

fig = figure('Name', 'Calendario Optimo', 'Position', [100, 100, 1600, 700], 'Visible', 'off');
if exist('theme', 'file'), theme(fig, 'light'); end   % R2025a+ puede usar tema oscuro por defecto
hold on;
b = bar(1:nD, Visualizacion_Matriz', 'stacked');

% Estilo Deporte
b(nA + 1).FaceColor = [1 0.7 0];
b(nA + 1).FaceAlpha = 0.6;
b(nA + 1).EdgeColor = [0 0 0];
b(nA + 1).LineWidth = 1.5;
b(nA + 1).LineStyle = '--';

% Estilo Descanso
b(nA + 2).FaceColor = [0.3 0.75 0.93];
b(nA + 2).FaceAlpha = 0.4;
b(nA + 2).EdgeColor = 'k';
b(nA + 2).LineWidth = 1.2;
b(nA + 2).LineStyle = ':';

colores = lines(nA);
for a = 1:nA
    b(a).FaceColor = colores(a, :);
end

xlabel('Día del Calendario', 'FontWeight', 'bold');
ylabel('Horas (Estudio + Deporte + Descanso)', 'FontWeight', 'bold');
title(sprintf('Planificación Óptima de Exámenes: %s', strrep(nombre_escenario, '_', '\_')), 'FontSize', 15);
ylim([0 12]);
grid on;

for c = unique(data.capacidad)'
    yline(c, '-k', sprintf('Capacidad %gh', c), 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
end

legend(b, [nombres_asignaturas, {'DEPORTE', 'DESCANSO'}], 'Location', 'northeastoutside', 'FontWeight', 'bold');

str_params = {
    '  PARÁMETROS DEL MODELO', ...
    '-------------------------', ...
    sprintf('Asignaturas (nA):  %d', nA), ...
    sprintf('Días totales (nD): %d', nD), ...
    sprintf('Dep. Semanal:      %.1f h', Params.deporte_semanal), ...
    sprintf('Mín. Estudio:      %.1f h', Params.min_estudio), ...
    sprintf('Sprint Horas:      %.1f h', Params.sprint_horas), ...
    sprintf('Sprint Días:       %d', Params.sprint_dias), ...
    '-------------------------', ...
    sprintf('Peso Alpha:        %.2f', Params.alpha), ...
    sprintf('Peso Beta:         %.2f', Params.beta), ...
    sprintf('Peso Gamma:        %.2f', Params.gamma)
};
annotation('textbox', [0.835, 0.12, 0.16, 0.35], 'String', str_params, ...
    'FitBoxToText', 'on', 'BackgroundColor', [0.96 0.96 0.96], ...
    'EdgeColor', 'k', 'LineWidth', 1.2, 'FontName', 'FixedWidth', ...
    'FontSize', 11, 'FontWeight', 'bold');

for a = 1:nA
    xline(data.D_exam(a), '-r', ['Ex ', num2str(a)], 'LineWidth', 2, 'HandleVisibility', 'off');
end
hold off;

exportgraphics(fig, fullfile(carpeta_salida, [nombre_escenario '.png']), 'Resolution', 110);
close(fig);

fprintf('[%s] %s | objetivo = %.3f | estudio %.1f h, deporte %.1f h, descanso %.1f h | %.2f s\n', ...
    nombre_escenario, res.status, res.objetivo, res.horas_estudio, res.horas_deporte, res.horas_descanso, t_sol);
end
