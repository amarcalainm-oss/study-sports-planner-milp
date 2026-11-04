function model = buildModel(data)

%Interruptores para activar o desactivar restricciones
debug_sprint = true;
debug_deporte_semanal = true;
debug_min_estudio = true;
%% ----- PARÁMETROS

nA = data.nA; %Numero de Asignaturas
nD = data.nD; %Numero de Dias

horas = data.horas; %Horas totales de estudio
D_exam = data.D_exam; %Dias de los examenes
capacidad = data.capacidad; %Capacidad por dia(estudio,deporte,descanso)

min_est = data.min_estudio; %Si se estudia, lo minimo que hay que estudiar
max_est = data.max_estudio; %Maximo de horas de estudio al dia

min_dep = data.min_deporte; %Si se hace deporte, lo minimo que hay que hacer
max_dep = data.max_deporte; %Maximo de deporte al dia

min_dep_sem = data.deporte_semanal; %Minimo de deporte a la semana

sprint_dias = data.sprint_dias; % Dias previos de sprint antes del examen
sprint_horas = data.sprint_horas; % Horas de estudio en el sprint
alpha = data.alpha; % penalizacion procrastinacion
beta = data.beta; %animo por deporte
gamma = data.gamma; %animo por descanso

%% ----- TAMAÑOS

nx = nA*nD; % Cada dia a cada asignatura cuantas horas le dedicamos(continua)
ny = nA*nD; % Cada dia si estudiamos una asignatura o no(binaria)
ne = nD; % Numero total de hora para el deporte cada dia (continua)
nz = nD; % Numero total de dias que se hace deporte(binaria)
nr = nD;  %Horas de descanso cada día (continua)

N = nx + ny + ne + nz + nr; % Numero total de variables de decision

%% ----- ÍNIDICES

idx_x = @(a,d) (a-1)*nD + d; 
idx_y = @(a,d) nx + (a-1)*nD + d;
idx_e = @(d) nx + ny + d;
idx_z = @(d) nx + ny + ne + d;
idx_r = @(d) nx + ny + ne + nz + d;

%% ----- FUNCIÓN OBJETIVO

f = zeros(N,1);

% --- Estudio
for a = 1:nA
    for d = 1:nD
        dist = D_exam(a) - d;
        if dist >= 0
            sem = 1 + alpha/(dist+1); % Peso que aumenta según cercanía 
            f(idx_x(a,d)) = sem; 
        end
    end
end

% --- Deporte / descanso
for d = 1:nD
    f(idx_e(d)) = -beta; % Alivio por deporte 
    f(idx_r(d)) = -gamma; % Alivio por descansar
end

%% ----- COTAS Y TIPOS
lb = zeros(N,1);
ub = inf(N,1);
ctype = repmat('C', 1, N);

for a = 1:nA
    for d = 1:nD
        ub(idx_y(a,d)) = 1;
        ctype(idx_y(a,d)) = 'B';
    end
end
for d = 1:nD
    ub(idx_z(d)) = 1;
    ctype(idx_z(d)) = 'B';
end
%% ------ RESTRICCIONES

A = []; b = [];

% Asegura que se completen las horas (30h o 50h) para cada asignatura
for a = 1:nA
    row = zeros(1,N);
    
    % Sumamos las horas de la asignatura hasta el día anterior al examen
    for d = 1:D_exam(a)-1
        row(idx_x(a,d)) = 1;
    end
    
    % Para convertir suma >= horas en: -suma <= -horas
    A = [A; -row]; 
    b = [b; -horas(a)]; 
end

%--- Restricción de capacidad diaria.

for d = 1:nD
    row = zeros(1,N);
    
    for a = 1:nA
        row(idx_x(a,d)) = 1; % Sumamos horas de estudio
    end
    
    row(idx_e(d)) = 1; % Sumamos horas de deporte
    row(idx_r(d)) = 1; % Sumamos horas de descanso
    
    A = [A; row];
    b = [b; capacidad(d)];
end

%--- Estudio minimo / máximo

if debug_min_estudio
    for a = 1:nA
        for d = 1:nD

            % x >= min_est*y
            row = zeros(1,N);

            % -x(a,d) + min_est * y <=0
            row(idx_x(a,d)) = -1; 
            row(idx_y(a,d)) = min_est;
            A = [A; row];
            b = [b; 0];

            % x <= max_est*y
            row = zeros(1,N);

            % x(a,d) - min_est * y <=0
            row(idx_x(a,d)) = 1;
            row(idx_y(a,d)) = -max_est;
            A = [A; row];
            b = [b; 0];
        end
    end
end

%--- Deporte (diario)

for d = 1:nD
    
    row = zeros(1,N);

    % -e(d) + min_dep * z <=0
    row(idx_e(d)) = -1; 
    row(idx_z(d)) = min_dep;
    A = [A; row];
    b = [b; 0];
    
    % e(d) - max_dep * z <=0
    row = zeros(1,N);
    row(idx_e(d)) = 1;
    row(idx_z(d)) = -max_dep;
    A = [A; row];
    b = [b; 0];
end

%---Minimo semanal de deporte

if debug_deporte_semanal 
    num_semanas = ceil(nD / 7);

    for sem = 0:num_semanas-1
        row = zeros(1,N);
        dia_inicio = sem*7 + 1;
        dia_fin = min((sem+1)*7, nD);
        for d = dia_inicio:dia_fin
            row(idx_e(d)) = 1;
        end
        dias_en_esta_semana = dia_fin - dia_inicio + 1;
        minimo_proporcional = min_dep_sem * (dias_en_esta_semana / 7);

        A = [A; -row]; % Invertimos para que sea >= a las horas
        b = [b; -minimo_proporcional];
    end
end

%---Sprint final antes del examen
if debug_sprint
    for a = 1:nA
        row = zeros(1,N);

        % Calculamos desde 'X' días antes, hasta el día ANTES del examen
        dia_inicio_sprint = max(1, D_exam(a) - sprint_dias);
        dia_fin_sprint = D_exam(a) - 1; 

        % Solo hacemos el sprint si el examen no es el día 1
        if dia_fin_sprint >= 1 
            dias_sprint = dia_inicio_sprint : dia_fin_sprint; 

            for d = dias_sprint
                row(idx_x(a,d)) = 1;
            end

            A = [A; -row]; % Invertimos para que sea >= sprint_horas
            b = [b; -sprint_horas];
        end
    end
end

%--- Prohibición post-examen (y día del examen)

for a = 1:nA
    % Empezamos desde el D_exam(a) para prohibir estudiar el mismo día
    for d = D_exam(a):nD 
        ub(idx_x(a,d)) = 0; % Horas de estudio obligadas a 0
        ub(idx_y(a,d)) = 0; % Interruptor binario obligado a 0
        
    end
end



%% ------ SALIDA
model.obj = f;
model.lb = lb;
model.ub = ub;
model.ctype = ctype;
model.A = A;
model.rhs = b; 
model.lhs = -inf(size(b, 1), 1);
