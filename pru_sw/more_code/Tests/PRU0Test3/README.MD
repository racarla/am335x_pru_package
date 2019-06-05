# PRU 0 Test 2

Este test es muy parecido al anterior, en este probaremos a realizar la interrupcion
al programa principal de forma indirecta, es decir, será la PRU 1 la quien envie la interrupcion
al programa principal, mientras que la PRU 0 enviará una interrupción a la PRU 1.

Este test es el muy parecido al anterior, en este hemos introducido una espera para que
el tiempo medio sea de 10 uS. Ha sido elegido segun el tiempo dado como resultado anterior,
y tener una base de tiempo que tenga facilmente multiplos de tiempo.

Este test sirve para calcular el numero de ciclos medio en la lectura del ADC por 8 muestras,
hasta llenar los 10KB ultimos de shared RAM, siendo disparado el ADC mediante la PRU.

10 KB = 10 * 1024 = 10240 bytes
2 bytes por muestra * 8 muestras por iteracion = 16 bytes

El numero de iteraciones para llenar el bucle es 640 iteraciones.

