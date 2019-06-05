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

  // Enable counter cycles PRU Xs
  MOV PRU_POINTER, PRU0_GLOBAL

  MOV PRU_POINTER, PRU_POINTER
  LBBO tmp0, PRU_POINTER, PRU_CTRL, 4
  OR   tmp0, tmp0, 0x8 // BIT 3 a 1
  SBBO tmp0, PRU_POINTER, PRU_CTRL, 4

  MOV SHARED_RAM, SHARED_RAM_ADDRESS
  MOV tmp4, SHARED_RAM_ADDRESS + SHD_RAM_ADR_BUFF_INI
  MOV shared_ram_pointer, SHARED_RAM_ADDRESS + SHD_RAM_ADR_BUFF_INI
  MOV SHARED_RAM_SIZE, SHARED_RAM_ADDRESS + SHD_RAM_ADR_BUFF_FI

  MOV adc_, ADC_BASE
	MOV fifo0data, ADC_FIFO0DATA

  // Check if clock is enabled
  MOV adc_ctrl, CM_WKUP_ADC_TSC_CLKCTRL
  MOV cm_ctrl, CM_WKUP_CLKSTCTRL

  MOV tmp0, 0x02
  MOV tmp1, 0
ENABLE_ADC:
  SBBO tmp0, adc_ctrl, 0, 4
  SBBO tmp1, cm_ctrl, 0, 4
  LBBO tmp0, adc_ctrl, 0, 4
  QBNE ENABLE_ADC, tmp0, 0x02

  // Disable ADC
	LBBO tmp0, adc_, CONTROL, 4
	MOV  tmp1, 0x1
	NOT  tmp1, tmp1
	AND  tmp0, tmp0, tmp1
	SBBO tmp0, adc_, CONTROL, 4

  // Disable ADC Step protection
  LBBO tmp0, adc_, CONTROL, 4
  MOV  tmp1, 0x4
  OR  tmp0, tmp0, tmp1
  SBBO tmp0, adc_, CONTROL, 4

	// Put ADC capture to its full speed
	//MOV tmp0, 0xf
  MOV tmp0, 0
  SBBO tmp0, adc_, SPEED, 4

  // Configure STEPCONFIG registers for all 8 channels
  MOV tmp0, STEP1
  MOV tmp1, 0
  MOV tmp2, 0

FILL_STEPS:
  LSL tmp3, tmp1, 19
  SBBO tmp3, adc_, tmp0, 4
  ADD tmp0, tmp0, 4
  SBBO tmp2, adc_, tmp0, 4
  ADD tmp1, tmp1, 1
  ADD tmp0, tmp0, 4
  QBNE FILL_STEPS, tmp1, 8

  // Enable ADC with the desired mode (make STEPCONFIG registers writable, use tags, enable)
  LBBO tmp0, adc_, CONTROL, 4
  OR   tmp0, tmp0, 0x7
  SBBO tmp0, adc_, CONTROL, 4

RESET_BUFFER:
  MOV DDR_POINTER, DDR
  ADD DDR_BUFF_POINTER, DDR, DDR_BUFF_SIZE
  MOV N_BUFF, 0

CAPTURE:
  LBBO Time1, PRU_POINTER, PRU_CYCLES_COUNTER, 4     // Load "before" cycle count into R1
  SBBO Time1, SHARED_RAM, 0, 4
  ADD SHARED_RAM, SHARED_RAM, 4
  MOV tmp0, 0x1fe
  SBBO tmp0, adc_, STEPCONFIG, 4 // write STEPCONFIG register (this triggers capture)

WAIT_FOR_FIFO0:
	LBBO tmp0, adc_, FIFO0COUNT, 4
	QBGT WAIT_FOR_FIFO0, tmp0, 8

  MOV tmp0, 0
READ_ALL_FIFO0:  // lets read all fifo content and dispatch depending on pin type
	LBBO value, fifo0data, 0, 4
	MOV tmp1, 0xfff
  AND value, value, tmp1

  SBBO value, shared_ram_pointer, 0, 4
  ADD shared_ram_pointer, shared_ram_pointer, 4
  ADD tmp0, tmp0, 1
  QBGT READ_ALL_FIFO0, tmp0, 8

  LBBO Time1, PRU_POINTER, PRU_CYCLES_COUNTER, 4     // Load "before" cycle count into R1
  SBBO Time1, SHARED_RAM, 0, 4
  ADD SHARED_RAM, SHARED_RAM, 4

 QBLT FI, SHARED_RAM, tmp4
 QBGT CAPTURE, shared_ram_pointer, SHARED_RAM_SIZE

FI:
 // Interrupt the host so it knows we're done
 MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

 // Don't forget to halt!
 HALT
