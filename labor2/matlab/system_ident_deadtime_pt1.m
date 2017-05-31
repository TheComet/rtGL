close all, clear all; clc
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

% Starts to overshoot, determined by looking at plots and bode diagram
Kpcrit = 10^(35/20);
Tcrit = 4.55 - 3.89;

% Design various P controllers
Kp(1) = 0.5 * Kpcrit;   % Ziegler-Nichols
Kp(2) = 0.3 * Tg/Tu/Ks; % Chien, Hrones und Reswick (stör)
Kp(3) = 0.3 * Tg/Tu/Ks; % Chien, Hrones und Reswick (führ)

%figure; hold on, grid on, grid minor
figure; hold on, grid on, grid minor
for n = 1:3
    H = Kp(n);
    T = H/(1 + G*H);
    step(T * dV, linspace(0, 7, 1000));
end
title('\fontsize{16}P Controllers - Control Voltages')
legend('\fontsize{12}Ziegler-Nichols', '\fontsize{12}Chien-Hrones-Reswick (disturbance rejection)', '\fontsize{12}Chien-Hrones-Reswick (good tracking)');
ylabel('\fontsize{14}Voltage at input of motor');
xlabel('\fontsize{14}Time (s)');
axis square
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);
return;

% Design various PI controllers
Kp(1) = 0.45 * Kpcrit;  % Ziegler-Nichols
Ti(1) = 0.85 * Tcrit;

Kp(2) = 0.6 * Tg / Tu / Ks;  % Chien, Hrones und Reswick (stör)
Ti(2) = 4 * Tu;

Kp(3) = 0.35 * Tg / Tu / Ks;  % Chien, Hrones und Reswick (führ)
Ti(3) = 1.2 * Tg;

figure; hold on, grid on, grid minor
for n = 1:3
    H = Kp(n) * (1 + 1/(s*Ti(n)));
    T = G*H/(1 + G*H);
    step(T * Ks * dV + yoffset, linspace(0, 15, 1000));
end
title('\fontsize{16}PI Controllers')
legend('\fontsize{12}Ziegler-Nichols', '\fontsize{12}Chien-Hrones-Reswick (disturbance rejection)', '\fontsize{12}Chien-Hrones-Reswick (good tracking)');
ylabel('\fontsize{14}Measured Motor Speed (rpm)');
xlabel('\fontsize{14}Time (s)');
axis square
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);

% Design PID controller
Kp(1) = 0.6 * Kpcrit;  % Ziegler-Nichols
Ti(1) = 0.5 * Tcrit;
Td(1) = 0.12 * Tcrit;

Kp(2) = 0.95 * Tg / Tu / Ks;  % Chien, Hrones und Reswick (stör)
Ti(2) = 2.4 * Tu;
Td(2) = 0.42 * Tu;

Kp(3) = 0.12 * Tg / Tu / Ks; % Chien, Hrones und Reswick (führ)
Ti(3) = Tg;
Td(3) = 0.5 * Tu;

figure; hold on, grid on, grid minor
for n = 1:3
    H = Kp(n) * (1 + 1/(s*Ti(n)) + s*Td(n));
    T = G*H/(1 + G*H);
    step(T * Ks * dV + yoffset, linspace(0, 15, 1000));
end
title('\fontsize{16}PID Controllers')
legend('\fontsize{12}Ziegler-Nichols', '\fontsize{12}Chien-Hrones-Reswick (disturbance rejection)', '\fontsize{12}Chien-Hrones-Reswick (good tracking)');
ylabel('\fontsize{14}Measured Motor Speed (rpm)');
xlabel('\fontsize{14}Time (s)');
axis square
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);
