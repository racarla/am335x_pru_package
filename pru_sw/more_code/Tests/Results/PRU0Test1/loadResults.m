close all;
clear all;

Times = csvread('PRU0Test1.csv');
T = zeros(1,length(Times)-2);
for i=1:length(Times)-2
   T(i) = Times(1,i+1) - Times(1,i);
end

figure;
plot(T);
title('Numero de ciclos medio de lectura')

figure;
plot((T*5)/1000);
title('Tiempo medio de lectura en uS')