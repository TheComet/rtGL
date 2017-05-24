function [Tfit, rfit] = sani_fit(T, r, order, xdata, ydata)
    x(1) = T;
    x(2) = r;
    function ydata = fun(x, xdata)
        H = sani_transfer_function(x(1), x(2), order);
        ydata = step(H, xdata);
    end
    x = lsqcurvefit(@fun, x, linspace(xdata(1), xdata(end), length(xdata)), ydata);
    Tfit = x(1);
    rfit = x(2);
end
