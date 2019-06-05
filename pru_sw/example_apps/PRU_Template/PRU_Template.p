.origin 0
.entrypoint TOP

/////////////////////////////////////

#define COUNTERS 100000

// INTERRUPTS OR EVENTS VALUES
#define PRU_ARM_INTERRUPT 19
#define PRU_ARM_INT_NOTIFICATION 16

/////////////////////////////////////

TOP:
  // Enable OCP master ports in SYSCFG register
  LBCO r0, C4, 4, 4
  CLR r0, r0, 4
  SBCO r0, C4, 4, 4

  MOV r2, COUNTERS

  MOV r1, 0
WAIT:
  ADD r1, r1, 1
  QBLT WAIT, r2, r1

  // Interrupt the host so it knows we're done
  MOV r31.b0, PRU_ARM_INTERRUPT + PRU_ARM_INT_NOTIFICATION

  // Don't forget to halt!
  HALT
