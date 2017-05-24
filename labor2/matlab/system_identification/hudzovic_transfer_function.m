function [G, Tk] = hudzovic_transfer_function(T, r, order)
    s = tf('s');
    G = 1;
    for k = 1:order
        Tk(k) = T / (1-(k-1)*r);
        G = G / (1 + s*Tk(k));
    end
end
