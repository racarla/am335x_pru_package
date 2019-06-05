.origin 0
.entrypoint TOP

///////////////////
// PRU REGISTERS //
///////////////////

// Time
#define _Time1 r1
#define _Time2 r2
#define _MAX_TIME r3

// SHARED RAM - SHDR
#define _SHDR_BASE r4
#define _SHDR_POINTER r5
#define _SHDR_END r6

// PRU
#define _PRU_BASE_ADDR r7

// DDR
#define _DDR_BASE r8
#define _DDR_POINTER r9
#define _DDR_SIZE r10

// ADC

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



#define DDR_BUFF_POINTER r18
#define DDR_BUFF_SIZE r19
#define N_BUFF r20

#define ValueMask r24

/////////////////////////////////////
// ADDRESS AND CONSTANTS VALUES    //
// IN GLOBAL MEMORY MAP PRU (OCP)  //
/////////////////////////////////////

// PRU ADDRESS
#define PRU0_GLOBAL 0x00022000
#define PRU1_GLOBAL 0x00024000

// PRU OFFSETS ADDRESS
#define PRU_CTRL 0x0
#define PRU_CYCLES_COUNTER 0x10

/////////////////////////////////////

// TIME
#define MAX_TIME 0xFFFFF000

/////////////////////////////////////

// SHARED RAM ADDRESS
#define SHDR_ADDR 0x10000

// SHARED RAM OFFSETS ADDRESS
#define SHDR_END_ADDR 0x3000

/////////////////////////////////////

// ADC ADDRESS
#define CM_WKUP_CLKSTCTRL 0x44E00400
#define CM_WKUP_ADC_TSC_CLKCTRL 0x44E004BC
#define ADC_BASE_ADDR 0x44e0d000
#define ADC_FIFO0DATA   (ADC_BASE_ADDR + 0x0100)

// ADC OFFSETS ADDRESS
#define CONTROL 0x0040
#define SPEED   0x004c
#define STEP1   0x0064
#define DELAY1  0x0068
#define STATUS  0x0044
#define STEPCONFIG  0x0054
#define FIFO0COUNT  0x00e4

// ADC MASKS

#define ADC_MASK_VALUE 0xFFF

/////////////////////////////////////

// INTERRUPTS OR EVENTS VALUES
#define PRU_ARM_INTERRUPT 19
#define PRU_ARM_INT_NOTIFICATION 16

/////////////////////////////////////

TOP:
  // Enable OCP master ports in SYSCFG register
  LBCO r0, C4, 4, 4
  CLR r0, r0, 4
  SBCO r0, C4, 4, 4

  // SHARED RAM
  MOV _SHDR_BASE, SHDR_ADDR
  MOV _SHDR_POINTER, SHDR_ADDR
  MOV _SHDR_END, SHDR_ADDR + SHDR_END_ADDR

  // LOAD DDR ADDRESS FROM SHARED RAM
  LBBO _DDR_BASE, _SHDR_BASE, 0, 4
  LBBO _DDR_SIZE, _SHDR_BASE, 4, 4

  MOV _DDR_POINTER, _DDR_BASE
  ADD _DDR_SIZE, _DDR_BASE, _DDR_SIZE

  // TIME
  MOV _MAX_TIME, MAX_TIME



  // ADC_BASE
  MOV adc_, ADC_BASE
	MOV fifo0data, ADC_FIFO0DATA

  // Load ADC ValueMask
  MOV ValueMask, 0xfff

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

ENABLE_CLOCK:
  // Enable counter cycles PRUX
  MOV PRU_POINTER, PRU0_GLOBAL

  LBBO tmp0, PRU_POINTER, PRU_CTRL, 4
  OR   tmp0, tmp0, 0x8 // BIT 3 a 1
  SBBO tmp0, PRU_POINTER, PRU_CTRL, 4


  // Interrupt the host so it knows we're done
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // Don't forget to halt!
  HALT
