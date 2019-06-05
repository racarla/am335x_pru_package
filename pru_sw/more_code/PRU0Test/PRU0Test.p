.origin 0
.entrypoint TOP

// Registers

#define tmp0  r1
#define tmp1  r2
#define tmp2  r3
#define tmp3  r4
#define tmp4  r5

#define adc_  r6
#define fifo0data r7

#define shared_ram_pointer  r8
#define SHARED_RAM_SIZE r9

#define value r10
#define channel   r11
#define adc_ctrl   r12
#define cm_ctrl  r13
#define PRU_POINTER r14

#define DDR r15
#define DDR_POINTER r16
#define DDR_SIZE r17
#define DDR_BUFF_POINTER r18
#define DDR_BUFF_SIZE r19
#define N_BUFF r20

#define SHARED_RAM r21

#define Time1 r22
#define Time2 r23

// ADDRESS AND CONSTANTS VALUES

#define CM_WKUP_CLKSTCTRL 0x44E00400
#define CM_WKUP_ADC_TSC_CLKCTRL 0x44E004BC
#define ADC_BASE 0x44e0d000

#define CONTROL 0x0040
#define SPEED   0x004c
#define STEP1   0x0064
#define DELAY1  0x0068
#define STATUS  0x0044
#define STEPCONFIG  0x0054
#define FIFO0COUNT  0x00e4

#define ADC_FIFO0DATA   (ADC_BASE + 0x0100)

#define PRU0_GLOBAL 0x00022000 // GLOBAL MAP VIEW PRU
#define PRU1_GLOBAL 0x00024000 // GLOBAL MAP VIEW PRU
#define PRU_CTRL 0x0
#define PRU_CYCLES_COUNTER 0x10

#define SHARED_RAM_ADDRESS 0x10000
#define SHD_RAM_ADR_BUFF_INI 0x800
#define SHD_RAM_ADR_BUFF_MID 0x1C00
#define SHD_RAM_ADR_BUFF_FI 0x3000

#define PRU_ARM_INTERRUPT 19
#define PRU_ARM_INT_NOTIFICATION 16

TOP:
  // Enable OCP master ports in SYSCFG register
  LBCO r0, C4, 4, 4
  CLR r0, r0, 4
  SBCO r0, C4, 4, 4

  MOV Time1, 0xFFFFFFFF
  MOV Time2, 10000

  MOV SHARED_RAM, SHARED_RAM_ADDRESS

  MOV tmp2, 0
  SBBO tmp2, SHARED_RAM, 0, 4
  SBBO tmp2, SHARED_RAM, 4, 4

  MOV tmp2, 10000

  SUB tmp0, Time1, Time2
  SUC tmp1, Time1, Time2

  QBGT FI, tmp2, tmp0

  SBBO tmp0, SHARED_RAM, 0, 4
  SBBO tmp1, SHARED_RAM, 4, 4

FI:
 // Interrupt the host so it knows we're done
 MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

 // Don't forget to halt!
 HALT
