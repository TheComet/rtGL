function [x, y, image] = import_curve_from_image(filename, decimation_factor, color_key, hue_threshold)
    image = imread(filename);
    
    if nargin < 4
        hue_threshold = 0.1; % good starting value I think
    end
    if nargin < 3
        color_key = auto_detect_color_key(image, 10);
    end
    if nargin < 2
        decimation_factor = 1;
    end
    
    % colors are in rgb, convert to hsv
    color_key = single_rgb2hsv(color_key);
    image_data = rgb2hsv(image);
    
    hue = image_data(:,:,1);
    hue_key = color_key(1);
    [y, x] = find(hue > hue_key - hue_threshold & hue < hue_key + hue_threshold);
    
    % decimate vectors, you don't need that many points for what we're doing
    x = x(1:decimation_factor:end);
    y = y(1:decimation_factor:end);
    
    % Image coordinates start in the top left rather than in the bottom
    % left, so invert y axis
    y = -y;

    % The data should be normalised to [0 .. 1] on both axes so further
    % computations are easier. We assume there is some amount of noise
    % present in the data, and we assume that the the function is more or
    % less flat in the beginning and end.
    x = x - x(1);
    x = x / x(end);
    % average start and end to be closer to the "true" start and end
    % values.
    ymin = mean(y(1:10));
    ymax = mean(y(length(y)-10:end));
    y = y - ymin;
    y = y / (ymax - ymin);
end

function color_key = auto_detect_color_key(image_data, threshold)
    % The assumption is that the grid and background will be some kind of
    % grey (r == g == b). If we find some number of pixels that don't
    % satisfy this requirement and at the same time have a similar color
    % to one another, we can assume that this is the correct color key
    color_key = [0, 0, 0];
    r = image_data(:,:,1);
    g = image_data(:,:,2);
    b = image_data(:,:,3);
    for i = 1:numel(r)
        if r(i) ~= g(i) || r(i) ~= b(i) || g(i) ~= b(i)
            color_key = [r(i), g(i), b(i)];
            return;
        end
    end
    fprintf('Warning: auto-detection of color key failed.\n');
end

function hsv = single_rgb2hsv(rgb)
    c(1, 1, 1) = rgb(1);
    c(1, 1, 2) = rgb(2);
    c(1, 1, 3) = rgb(3);
    c = rgb2hsv(c);
    hsv = [c(:,:,1), c(:,:,2), c(:,:,3)];
end
