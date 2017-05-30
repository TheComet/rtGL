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


%% Design various P controllers
%Kpcrit = Tg / (Tu * Ks);
Kpcrit = 10^(35/20);  % Starts to overshoot
%Tcrit = 0.265 - 0.148; % Empirically determined
Kp(1) = Kpcrit; * 0.5;
Kp(2) = Kpcrit * 0.2;
Kp(3) = Kpcrit * 4;
Kp(4) = Kpcrit * 2.5; % (Playing around, this seems to be perfect)

%figure; hold on, grid on, grid minor
for n = 1:1
    H = Kp(n);
    T = G*H/(1 + G*H);
    step(T);
end
title('P Controllers')
%legend('Kp=0.5', 'Kp=0.2', 'Kp=4', 'Kp=2.2');

return;

% Design various PI controllers
Kp(1) = Kpcrit * 0.45;
Kp(2) = Kpcrit * 0.2;
Kp(3) = Kpcrit * 4;
Ti(1) = 0.85*Tcrit;
Ti(2) = 0.2*Tcrit;
Ti(3) = 4*Tcrit;

subplot(223); hold on, grid on, grid minor
for n = 1:3
    H = Kp(n) * (1 + 1/(s*Ti(n)));
    T = G*H/(1 + G*H);
    step(T * Ks * dV + yoffset, linspace(0, 15, 1000));
end
title('PI Controllers')
legend('Kp=0.45, Ti=0.85', 'Kp=0.2, Ti=0.2', 'Kp=4, Ti=4');

% Design PID controller
Kp(1) = Kpcrit * 0.6;
Ti(1) = Tu * 0.5;
Td(1) = Tu * 0.12;

Kp(2) = Kpcrit * 0.6 * Tg/Tu / Ks;
Ti(2) = Tg;
Td(2) = 0.5 * Tu;

Kp(3) = Kpcrit * 0.6 * Tg/Tu / Ks;
Ti(3) = Tg;
Td(3) = 0.5 * Tu;

subplot(224); hold on, grid on, grid minor
for n = 1:2
    H = Kp(n) * (1 + 1/(s*Ti(n)) + s*Td(n));
    T = G*H/(1 + G*H);
    step(T * Ks * dV + yoffset, linspace(0, 400, 1000));
end
title('PID Controllers')
legend('Ziegler-Nichols', 'Chien-Hrones-Reswick');

