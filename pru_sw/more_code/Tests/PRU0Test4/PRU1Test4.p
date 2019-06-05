.origin 0
.entrypoint TOP

// ***************************************
// *     Global Register Assignments     *
// ***************************************

#define eventStatus_addr_ptr  r18
#define jumpOffset        r8
#define regPointer        r11
#define regOffset         r12
#define regVal            r17
#define eventStatus r31

// ***************************************
// *      Global Macro definitions       *
// ***************************************

// Refer to this mapping in the file - \prussdrv\include\pruss_intc_mapping.h
#define PRU0_PRU1_INTERRUPT     17
#define PRU1_PRU0_INTERRUPT     18
#define PRU0_ARM_INTERRUPT      19
#define PRU1_ARM_INTERRUPT      20
#define ARM_PRU0_INTERRUPT      21
#define ARM_PRU1_INTERRUPT 22

#define CONST_PRUSSINTC C0

#define GER_OFFSET        0x10
#define HIESR_OFFSET      0x34
#define SICR_OFFSET       0x24
#define EISR_OFFSET       0x28

// ***************************************
// *      Progam Macro definitions       *
// ***************************************

#define SYS_EVT_PRU0 PRU0_PRU1_INTERRUPT

#define PRU_ARM_INTERRUPT 19
#define PRU_ARM_INT_NOTIFICATION 16

TOP:
  // Poll for receipt of interrupt on host 0
  WBS eventStatus, 31
  // Clear the status of the interrupt
  LDI	regVal.w2,	0x0000
  LDI	regVal.w0,	SYS_EVT_PRU0
  SBCO regVal,	CONST_PRUSSINTC,	SICR_OFFSET, 4

  // Interrupt the host so it knows we're done
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // Don't forget to halt!
  HALT
