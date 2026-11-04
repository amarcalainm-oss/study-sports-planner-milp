%% MODELO DE OPTIMIZACION: PLANIFICACION ACADEMICA Y DEPORTIVA
% Resuelve un escenario (por defecto, el calendario real del Experimento II).
% Ejecutar desde la carpeta src/.
%
% Parametros que se leen de la hoja "Parametros" del Excel:
%   1 min_estudio      sesion minima de estudio (h)
%   2 max_estudio      maximo de estudio por asignatura y dia (h)
%   3 min_deporte      sesion minima de deporte (h)
%   4 max_deporte      sesion maxima de deporte (h)
%   5 deporte_semanal  meta semanal de deporte (h)
%   6 sprint_horas     horas minimas de estudio en el sprint previo al examen
%   7 sprint_dias      ventana del sprint (dias)
%   8 beta             alivio por hora de deporte
%   9 gamma            alivio por hora de descanso
%  10 alpha            penalizacion por estudiar cerca del examen

clear; close all; clc;

% Ruta del conector CPLEX para MATLAB (ajustar a la instalacion local)
addpath('C:\Program Files\IBM\ILOG\CPLEX_Studio1210\cplex\matlab\x64_win64');

archivo = fullfile('..', 'data', 'exp2_calendario_real.xlsx');
carpeta_salida = fullfile('..', 'results');
if ~exist(carpeta_salida, 'dir'), mkdir(carpeta_salida); end

res = resolver_escenario(archivo, carpeta_salida);
