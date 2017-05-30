clear all, close all;

load('measurements.mat');

% Static Kennlinienaufnahme
figure;
plot(voltage_static, rpm_static, 'b'); hold on, grid on, grid minor
scatter(voltage_static, rpm_static, 'p');
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 6, 6], 'PaperUnits', 'Inches', 'PaperSize', [6, 6]);
axis square
xlabel('\fontsize{14}Input Voltage (V)');
ylabel('\fontsize{14}Measured Motor Settling Speed (rpm)');
title('\fontsize{16}Static Characteristic Curve of Motor');
