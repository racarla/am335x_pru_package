# PRU 0 Test 1

Este test sirve para calcular el numero de ciclos medio en la lectura del ADC por 8 muestras,
hasta llenar los 10KB ultimos de shared RAM, siendo disparado el ADC mediante la PRU.

10 KB = 10 * 1024 = 10240 bytes
2 bytes por muestra * 8 muestras por iteracion = 16 bytes

El numero de iteraciones para llenar el bucle es 640 iteraciones.
