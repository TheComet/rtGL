function [T, r, order] = hudzovic_lookup(a, b, c, xdata, ydata)
    if nargin == 2
        [T, r, order] = hudzovic_lookup_tu_tg(a, b);
    elseif nargin == 3
        [T, r, order] = hudzovic_lookup_t10_t50_t90(a, b, c);
    else
        error('Invalid input arguments');
    end
    
    if r < 0 || r >= 1/(order-1)
        warning('hudzovic lookup failed, parameters are too extreme. Falling back to default values.');
        a, b
        if nargin == 3
            c
        end
        T, r
        r = 1/(order-1)/2;
        T = 1;
    end
end

function [T, r, order] = hudzovic_lookup_tu_tg(Tu, Tg)
    curves = hudzovic_curves();
    
    % First, determine required order. We check Tu/Tg against the tu_tg
    % hudzovic curve for this
    tu_tg = Tu/Tg;
    for order = 2:8
        if tu_tg <= curves(order-1).tu_tg(1)
            break
        end
    end
    fprintf('Hudzovic Tu/Tg, order %d\n', order);
    
    % Next, look up r in tu_tg table. Use cubic interpolation for higher
    % accuracy.
    r = spline(curves(order-1).tu_tg, curves(order-1).r, tu_tg);
    
    % With r, look up T in T/Tg table. Use cubic interpolation for higher
    % accuracy.
    T = spline(curves(order-1).r, curves(order-1).t_tg, r) * Tg;
end

function [T, r, order] = hudzovic_lookup_t10_t50_t90(t10, t50, t90)
    curves = hudzovic_curves();

    % First, determine required order. We check lambda against the
    % hudzovic curve for this
    lambda = (t90-t10)/t50;
    order = hudzovic_determine_order(lambda);

    % Next, look up r in lambda table. Use cubic interpolation for higher
    % accuracy.
    r = spline(curves(order-1).lambda, curves(order-1).r, lambda);

    % With r, look up T in t/t50 table. Use cubic interpolation for higher
    % accuracy.
    T = t50 * spline(curves(order-1).r, curves(order-1).t_t50, r);
end

function order = hudzovic_determine_order(lambda)
    curves = hudzovic_curves();
    for order = 2:8
        if lambda >= curves(order-1).lambda(1)
            break
        end
    end
    fprintf('Hudzovic t10/t50/t90, order %d\n', order);
end
