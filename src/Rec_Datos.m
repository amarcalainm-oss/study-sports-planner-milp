function data = Rec_Datos(Asignaturas, Dias, Params)
data.nA = size(Asignaturas,1);
data.nD = size(Dias,1);

data.horas = Asignaturas(:,1);
data.D_exam = Asignaturas(:,2);

data.capacidad = Dias(:,1);

data.min_estudio = Params.min_estudio;
data.max_estudio = Params.max_estudio;

data.min_deporte = Params.min_deporte;
data.max_deporte = Params.max_deporte;

data.deporte_semanal = Params.deporte_semanal;

data.sprint_horas = Params.sprint_horas;
data.sprint_dias = Params.sprint_dias;

data.beta = Params.beta;
data.gamma = Params.gamma;
data.alpha = Params.alpha;