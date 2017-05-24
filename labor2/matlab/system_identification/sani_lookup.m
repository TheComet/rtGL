function [T, r, order] = sani_lookup(a, b, c)
    if nargin == 2
        [T, r, order] = sani_lookup_tu_tg(a, b);
    elseif nargin == 3
        [T, r, order] = sani_lookup_t10_t50_t90(a, b, c);
    else
        error('Invalid input arguments');
    end
    
    % sanity check
    if r < 0 || r > 1
        warning('sani lookup failed, parameters are too extreme. Falling back to default values.');
        a, b
        if nargin == 3
            c
        end
        T, r
        r = 0.5;
        T = 1;
    end
end

function [T, r, order] = sani_lookup_tu_tg(Tu, Tg)
    curves = sani_curves();
    
    % First, determine required order. We check Tu/Tg against the tu_tg
    % sani curve for this
    tu_tg = Tu/Tg;
    for order = 2:8
        if tu_tg <= curves(order-1).tu_tg(end)
            break
        end
    end
    fprintf('Sani Tu/Tg, order %d\n', order);
    
    % Next, look up r in tu_tg table. Use cubic interpolation for higher
    % accuracy.
    r = spline(curves(order-1).tu_tg, curves(order-1).r, tu_tg);
    
    % With r, look up T in T/Tg table. Use cubic interpolation for higher
    % accuracy.
    T = spline(curves(order-1).r, curves(order-1).t_tg, r) * Tg;
end

function [T, r, order] = sani_lookup_t10_t50_t90(t10, t50, t90)
    % Calculate lambda and determine the required filter order by doing a
    % quick lookup on all orders.
    lambda = (t90 - t10) / t50;
    order = sani_determine_order(lambda);

    % Next, do a binary search on the lambda function for the chosen order
    % to find r.
    fun = @(r)sani_lambda(r, order);
    r = binary_search(fun, lambda, 0, 1);

    % With r, calculate T using the t50 formula.
    T = t50 / (log(2) - 1 + (1-r^order)/(1-r));
end

function order = sani_determine_order(lambda)
    for order = 2:8
        if lambda >= sani_lambda(1-1e-6, order);
            break;
        end
    end
    fprintf('Sani t10/t50/t90, order %d\n', order);
end

function lambda = sani_lambda(r, order)
    lambda = (1.315*sqrt(3.8 * (1-r^(2*order))/(1-r^2) - 1)) / (log(2) - 1 + (1-r^order)/(1-r));
end

function result = binary_search(fun, target, lower, upper)
    mid = (upper - lower) / 2;
    x = mid / 2;
    max_iter = 20;
    while max_iter > 0
        max_iter = max_iter - 1;
        y = fun(x);
        mid = mid / 2;
        if y > target
            x = x + mid;
        else
            x = x - mid;
        end
    end
    
    result = x;
end
