% Moves a sliding average filter over the input signal. The output vector
% will be the same size as the input signal, however, this comes at the
% cost of the first "num" elements not fully being averaged.
function y = sliding_average(ydata, num)
    y = ydata(:);
    half = floor(num/2);
    for i = 1:length(ydata)
        y(i) = mean(ydata(max(1, i-half):min(end, i+half)));
    end
end
