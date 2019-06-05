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
#define _N_CYCLES r10
#define _N_BUFFERS r11

// ADC
#define _ADC_BASE  r12
#define _ADC_FIFO0DATA r13
#define _ADC_VALUE_MASK r14
#define _ADC_CTRL r15
#define _CM_CTRL r16

// TEMPORALLY REGISTERS
#define tmp0  r17
#define tmp1  r18
#define tmp2  r19
#define tmp3  r20

// CLOCK
#define _RESET_NUMBER r21

// Time
#define _TIME_CYCLE r22

// PRU
#define _PRU_POINTER r23

// ADC
#define _ADC_VALUE r24

// PUNTEROS
#define _POINTER_CYCLES r25
#define _POINTER_BUFFERS r26

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
#define RESET_NUMBER 0xFFFFFFF7

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
#define ADC_CONTROL 0x0040
#define ADC_SPEED   0x004c
#define ADC_STEP1   0x0064
#define ADC_DELAY1  0x0068
#define ADC_STATUS  0x0044
#define ADC_STEPCONFIG  0x0054
#define ADC_FIFO0COUNT  0x00e4

// ADC MASKS
#define ADC_MASK_VALUE 0xFFF

/////////////////////////////////////

// DDR
#define TIME_CYCLE 2000
#define N_CYCLES 2500
#define N_BUFFERS 40

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
  MOV _DDR_POINTER, _DDR_BASE

  // LOOPS
  MOV _N_CYCLES, N_CYCLES
  MOV _N_BUFFERS, N_BUFFERS

  // CLEAN SHARED MEMORY
  MOV _POINTER_BUFFERS, 0
  MOV tmp3, 0
CLEAN_MEM:
  SBBO tmp3, _SHDR_POINTER, 0, 4
  ADD _POINTER_BUFFERS, _POINTER_BUFFERS, 1
  ADD _SHDR_POINTER, _SHDR_POINTER, 4
  QBLT CLEAN_MEM, _N_BUFFERS, _POINTER_BUFFERS

  // TIME
  MOV _MAX_TIME, MAX_TIME
  MOV _RESET_NUMBER, RESET_NUMBER
  MOV _TIME_CYCLE, TIME_CYCLE

// CONFIGURE ADC
  // ADC_BASE
  MOV _ADC_BASE, ADC_BASE_ADDR
	MOV _ADC_FIFO0DATA, ADC_FIFO0DATA

  // Load ADC ValueMask
  MOV _ADC_VALUE_MASK, ADC_MASK_VALUE

  // Check if clock is enabled
  MOV _ADC_CTRL, CM_WKUP_ADC_TSC_CLKCTRL
  MOV _CM_CTRL, CM_WKUP_CLKSTCTRL

  MOV tmp0, 0x02
  MOV tmp1, 0
ENABLE_ADC:
  SBBO tmp0, _ADC_CTRL, 0, 4
  SBBO tmp1, _CM_CTRL, 0, 4
  LBBO tmp0, _ADC_CTRL, 0, 4
  QBNE ENABLE_ADC, tmp0, 0x02

  // Disable ADC
	LBBO tmp0, _ADC_BASE, ADC_CONTROL, 4
	MOV  tmp1, 0x1
	NOT  tmp1, tmp1
	AND  tmp0, tmp0, tmp1
	SBBO tmp0, _ADC_BASE, ADC_CONTROL, 4

  // Disable ADC Step protection
  LBBO tmp0, _ADC_BASE, ADC_CONTROL, 4
  MOV  tmp1, 0x4
  OR  tmp0, tmp0, tmp1
  SBBO tmp0, _ADC_BASE, ADC_CONTROL, 4

	// Put ADC capture to its full speed
	//MOV tmp0, 0xF
  MOV tmp0, 0
  SBBO tmp0, _ADC_BASE, ADC_SPEED, 4

  // Configure STEPCONFIG registers for all 8 channels
  MOV tmp0, ADC_STEP1
  MOV tmp1, 0
  MOV tmp2, 0

FILL_STEPS:
  LSL tmp3, tmp1, 19
  SBBO tmp3, _ADC_BASE, tmp0, 4
  ADD tmp0, tmp0, 4
  SBBO tmp2, _ADC_BASE, tmp0, 4
  ADD tmp1, tmp1, 1
  ADD tmp0, tmp0, 4
  QBNE FILL_STEPS, tmp1, 8

  // Enable ADC with the desired mode (make STEPCONFIG registers writable, use tags, enable)
  LBBO tmp0, _ADC_BASE, ADC_CONTROL, 4
  OR   tmp0, tmp0, 0x7
  SBBO tmp0, _ADC_BASE, ADC_CONTROL, 4

// END CONFIGURE ADC

//ENABLE_CLOCK:
  // Enable counter cycles PRUX
  //MOV _PRU_POINTER, PRU0_GLOBAL

  //LBBO tmp0, _PRU_POINTER, PRU_CTRL, 4
  //OR   tmp0, tmp0, 0x8 // BIT 3 a 1
  //SBBO tmp0, _PRU_POINTER, PRU_CTRL, 4

  // Interrupt the host to start ADC Reading
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // GET TIME
  //LBBO _Time1, _PRU_POINTER, PRU_CYCLES_COUNTER, 4

RESET_BUFFERS:
  MOV _POINTER_BUFFERS, 0
  MOV _SHDR_POINTER, _SHDR_BASE
  MOV _DDR_POINTER, _DDR_BASE

RESET_CYCLES:
  MOV _POINTER_CYCLES, 0

CAPTURE: // ADC LAUNCH CAPTURE

  // GET TIME
  // Load time value
 // LBBO _Time1, _PRU_POINTER, PRU_CYCLES_COUNTER, 4
  // Check if time is near from overflow
  //QBLT CONTINUE, _MAX_TIME, _Time1
  // RESET CLOCK
  //LBBO tmp0, _PRU_POINTER, PRU_CTRL, 4
 // AND  tmp0, tmp0, _RESET_NUMBER // BIT 3 a 1
 // SBBO tmp0, _PRU_POINTER, PRU_CTRL, 4
  //OR  tmp0, tmp0, 0x8 // BIT 3 a 1
  //SBBO tmp0, _PRU_POINTER, PRU_CTRL, 4
  //LBBO _Time1, _PRU_POINTER, PRU_CYCLES_COUNTER, 4

//CONTINUE:

  // ENABLE CAPTURE
  // write STEPCONFIG register (this triggers capture)
  MOV tmp0, 0x1fe
  SBBO tmp0, _ADC_BASE, ADC_STEPCONFIG, 4

WAIT_FOR_FIFO0:
	LBBO tmp0, _ADC_BASE, ADC_FIFO0COUNT, 4
	QBGT WAIT_FOR_FIFO0, tmp0, 8

  MOV tmp0, 0
READ_ALL_FIFO0:  // lets read all fifo content and dispatch depending on pin type
	LBBO _ADC_VALUE, _ADC_FIFO0DATA, 0, 4
  AND _ADC_VALUE, _ADC_VALUE, _ADC_VALUE_MASK

  SBBO _ADC_VALUE, _DDR_POINTER, 0, 2
  ADD _DDR_POINTER, _DDR_POINTER, 2

  ADD tmp0, tmp0, 1
  QBGT READ_ALL_FIFO0, tmp0, 8

//WAIT:
  //LBBO _Time2, _PRU_POINTER, PRU_CYCLES_COUNTER, 4     // Load "before" cycle count into R1
  //SUB tmp0, _Time2, _Time1
  //QBGT WAIT, tmp0, _TIME_CYCLE

  ADD _POINTER_CYCLES, _POINTER_CYCLES, 1
  QBLT CAPTURE, _N_CYCLES, _POINTER_CYCLES

  // UPDATE CONTENT BUFFERS SELECTION
  ADD _POINTER_BUFFERS, _POINTER_BUFFERS, 1

  LBBO tmp3, _SHDR_POINTER, 0, 4
  ADD tmp3, tmp3, 1
  SBBO tmp3, _SHDR_POINTER, 0, 4

  ADD _SHDR_POINTER, _SHDR_POINTER, 4

  QBLT RESET_CYCLES, _N_BUFFERS, _POINTER_BUFFERS

  // Interrupcion cuando termine el ciclo entero...?

  QBA RESET_BUFFERS

  // Interrupt the host so it knows we're done
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // Don't forget to halt!
  HALT
