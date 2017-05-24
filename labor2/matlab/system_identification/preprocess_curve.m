function [xdata, ydata] = preprocess_curve(xdata_raw, ydata_raw)
    % The xdata vector is not monotonically increasing with evenly spaced time
    % samples. It is very close to it though, so we can approximate it with
    % linspace
    xdata = linspace(xdata_raw(1), xdata_raw(end), length(xdata_raw))';

    % Input data is quite noisy, smooth it with a sliding average filter
    ydata = sliding_average(ydata_raw, 5);
    ydata = smooth(xdata_raw, ydata_raw, 0.2, 'loess');
end
