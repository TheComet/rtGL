close all, clear all;
s = tf('s');

% subroutines are located in this folder
addpath([pwd,'/system_identification']);
load('measurements.mat');

% Cut away shit at beginning and end of the second step response (we're
% only interested in the second step response)
% These were determined by looking at the plot
begin_index = 336;
end_index = length(time) - 500;
rpm = rpm(begin_index:end_index);
time = time(begin_index:end_index);
time = time - time(1);

% ?? https://de.wikipedia.org/wiki/Faustformelverfahren_%28Automatisierungstechnik%29

% Use P. Hudzovic's system identification technique to find Tu and Tg
iN = 10;
xdata = linspace(time(1), time(end), length(time));
ydata = filtfilt(ones(1, iN)/iN, 1, rpm);
[Tu, Tg] = characterise_curve(xdata, ydata);

% We know that the motor has a deadtime built in and then rises
% exponentially. We can approximate its transfer function with a deadtime
% and PT1 element.
G_deadtime = exp(-s*Tu);  % Deadtime should be about Tu
G_PT1 = 1/(s*Tg+1);       % PT1 element rises with Tg
G = G_deadtime * G_PT1;

% The plant's transfer function is normalised on the Y axis to 1. We need
% Ks and dV and the Y offset to calculate the correct step response
dV = 10 - 2; % 2V to 10V
Ks = (max(ydata) - min(ydata)) / dV;
yoffset = min(ydata);

% Plot measured data and compare it with the calculated step response
g_plant = step(G * Ks * dV + yoffset, xdata);
figure; hold on, grid on, grid minor
plot(time, rpm, 'r.-');
plot(xdata, g_plant, 'b');
legend('\fontsize{14}Measured Data', '\fontsize{14}T_t * PT1 Transfer Function', 'Location', 'South');
title('\fontsize{16}2V to 10V Step response');
ylabel('\fontsize{14}Measured Motor Speed (rpm)');
xlabel('\fontsize{14}Time (s)');
xlim([-2, 40]);
axis square
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);

% Bode plot
figure, bode(G);
hold on
x = [10 10];
y = [-1080 0];
plot(x, y, 'r--');
title('\fontsize{16}T_t * PT1 Bode Diagram');
grid on;
