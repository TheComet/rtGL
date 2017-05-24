function G = sani_transfer_function(T, r, order)
    s = tf('s');
    G = 1;
    for k = 0:order-1
        G = G / (1+s*T*r^k);
    end
end
