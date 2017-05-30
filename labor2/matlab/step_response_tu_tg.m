close all, clear all;

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

% The plant's transfer function is normalised on the Y axis to 1. We need
% Ks and dV and the Y offset to calculate the correct step response
dV = 10 - 2; % 2V to 10V
Ks = (max(ydata) - min(ydata)) / dV;
yoffset = min(ydata);

% plot tangent line
m = Ks * dV / Tg;
q = -m*Tu + yoffset;
plot(time, rpm); grid on, grid minor, hold on
plot(time, time*m + q);
der = diff(ydata) / (xdata(2) - xdata(1));
plot(xdata(1:end-1), der, 'b--');

legend('\fontsize{14}Measured Data', '\fontsize{14}Tangent', '\fontsize{14}Derivative', 'Location', 'SouthEast');
title('\fontsize{16}Characterisation of Measured Response');
ylabel('\fontsize{14}Measured Motor Speed (rpm)');
xlabel('\fontsize{14}Time (s)');
xlim([-2, 40]);
axis square
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);
xlim([0, 25]);
ylim([0, 250]);