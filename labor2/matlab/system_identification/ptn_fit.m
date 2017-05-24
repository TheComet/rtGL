function Tn = ptn_fit(xdata, ydata, ptn_order, initials)
    if nargin < 4
        % Set the initial time constants to 1
        initials = ones(1, ptn_order);
    end
    
    % ydata needs to be normalised
    ydata = ydata - ydata(1);
    ydata = ydata / ydata(end);
    
    Tn = lsqcurvefit(@ptn, initials, xdata, ydata);
end

function ydata = ptn(Tn, xdata)
    s = tf('s');
    H = 1;
    for k = 1:length(Tn)
        H = H / (1 + s*Tn(k));
    end
    ydata = step(H, xdata);
end
