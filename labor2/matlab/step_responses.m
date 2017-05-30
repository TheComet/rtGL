clear all, close all;

load('measurements.mat');

% Show measured step responses and compare them to the characteristic curve
figure;
subplot(121); grid on, grid minor, hold on
plot(time, rpm);
xlabel('\fontsize{14}Time (s)');
ylabel('\fontsize{14}Measured Motor Speed (rpm)');
ylim([-20, 250]);
yyaxis right
plot(time, voltage, '--');
ylabel('\fontsize{14}Input Voltage (V)');
ylim([-1, 12]);
axis square

subplot(122); grid on, grid minor, hold on
plot(rpm_static, voltage_static, 'b');
scatter(rpm_static, voltage_static, 'p');
plot([-50, 0], [0, 0], 'k--');     % dotted line to 0
plot([-50, 43], [2, 2], 'k--');    % dotted line to 2
plot([-50, 239], [10, 10], 'k--'); % dotted line to 10
ylabel('\fontsize{14}Input Voltage (V)');
xlabel('\fontsize{14}Measured Motor Settling Speed (rpm)');
ylim([-1, 12]);
axis square

suptitle('\fontsize{16}Step Responses and Comparison to Static Characteristics');
set(gcf, 'Units', 'Inches', 'Position', [0, 0, 12, 6], 'PaperUnits', 'Inches', 'PaperSize', [12, 6]);
