.origin 0
.entrypoint TOP

// Registers

#define tmp0  r1

#define Time1 r22
#define Time2 r23
#define Time3 r24
#define Time4 r25

// ADDRESS AND CONSTANTS VALUES

#define ADC_FIFO0DATA   (ADC_BASE + 0x0100)

#define PRU0_GLOBAL 0x00022000 // GLOBAL MAP VIEW PRU
#define PRU1_GLOBAL 0x00024000 // GLOBAL MAP VIEW PRU
#define PRU_CTRL 0x0
#define PRU_CYCLES_COUNTER 0x10

#define MAX_TIME 0xFFFFFFFF

#define PRU_ARM_INTERRUPT 19
#define PRU_ARM_INT_NOTIFICATION 16

TOP:
  // Enable OCP master ports in SYSCFG register
  LBCO r0, C4, 4, 4
  CLR r0, r0, 4
  SBCO r0, C4, 4, 4

  // Numero de ciclos por 8 muestras
  MOV Time4, MAX_TIME

  // Enable counter cycles PRU Xs
  MOV PRU_POINTER, PRU0_GLOBAL

  MOV PRU_POINTER, PRU_POINTER
  LBBO tmp0, PRU_POINTER, PRU_CTRL, 4
  OR   tmp0, tmp0, 0x8 // BIT 3 a 1
  SBBO tmp0, PRU_POINTER, PRU_CTRL, 4

WAIT:
  LBBO Time1, PRU_POINTER, PRU_CYCLES_COUNTER, 4     // Load "before" cycle count into R1
  QBNE WAIT, Time1, Time4

  LBBO tmp0, PRU_POINTER, PRU_CTRL, 4
  AND tmp0, tmp0, 0x8 // BIT 3 a 1
  LSR tmp0, tmp0, 3

NO_HALT:
  QBNE NO_HALT, tmp0, 0 // Si se pone a cero, es que se cumple el overflow

  // Interrupt the host so it knows we're done
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // Don't forget to halt!
  HALT
