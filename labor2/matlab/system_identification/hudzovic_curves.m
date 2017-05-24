% This function calculates the Hudzovic curves, which are later used
% for looking up time constants of a specific plant. The curves range from
% order 2 to order 8 (this is hardcoded).
%
% The return value is an array of structures, where the first element is
% for order=2, the second element is for order=3 and so on.
% Each structure containes 3 fields:
%   - r     : The "r" vector, which is an array of datapoints that belong
%             to the x axis. r will range from 0 <= r < 1/(order-1)
%   - tu_tg : The result of Tu/Tg for a specific value of r.
%   - t_tg  : The result of t/Tg for a specific value of r.
%
% Resolution specifies how finely grained the r vector should be.
function curves = hudzovic_curves(resolution)
    if nargin < 1
        resolution = 50;
    end
    
    % Check if we can load the curves
    if exist('hudzovic_curves.mat', 'file') == 2
        s = load('hudzovic_curves.mat');
        curves = s.curves;
        if length(curves(1).r) == resolution
            return;
        end
    end
        
    fprintf('Hudzovic curves need to be generated (only needs to be done once).\n');
    fprintf('This may take a while. Go get a coffee or something.\n');
    curves = hudzovic_gen_curves(resolution);
    save('hudzovic_curves.mat', 'curves');
end

function curves = hudzovic_gen_curves(resolution)
    curves = struct('r', 0, 'tu_tg', 0, 't_tg', 0, 'lambda', 0, 't_t50', 0);

    for order = 2:8
        fprintf('Generating hudzovic curve, order %d/8\n', order);

        % 0 <= r < 1/(order-1)
        r = linspace(0, 1/(order-1), resolution+1);
        r = r(1:end-1);

        % Reserve space in curves object
        curves(order-1).r = r;
        curves(order-1).tu_tg = zeros(1, resolution);
        curves(order-1).t_tg = zeros(1, resolution);

        for r_index = 1:resolution
            % Set T=1 for calculating Tk, construct transfer function H(s)
            H = hudzovic_transfer_function(1, r(r_index), order);

            % Get Tu/Tg from step response of resulting transfer function
            [h, t] = step(H);
            [Tu, Tg] = characterise_curve(t, h);
            [t10, t50, t90] = characterise_curve(t, h, [0, 1]);

            % Now we can calculate Tu/Tg as well as T/Tg with T=1 to yield
            % the two plots seen in the Hudzovic method
            curves(order-1).tu_tg(r_index) = Tu/Tg;
            curves(order-1).t_tg(r_index) = 1/Tg;
            curves(order-1).lambda(r_index) = (t90-t10)/t50;
            curves(order-1).t_t50(r_index) = 1/t50;
        end
    end
    fprintf('Done.\n');
end
