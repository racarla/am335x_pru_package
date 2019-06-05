// Loads a .bin file into a BeagleBone PRU and then interacts with it
 // in shared PRU memory and (system-wide) DDR memory.
 //
 // Pass in the filename of the .bin file on the command line, eg:
 // $ ./pru_loader foo.bin
 //
 // Compile with:
 // gcc -std=gnu99 -o pru_loader pru_loader.c -lprussdrv

 #include <unistd.h>
 #include <stdio.h>
 #include <inttypes.h>
 #include <prussdrv.h>
 #include <pruss_intc_mapping.h>

 int main(int argc, char **argv) {
  if (argc != 2) {
   printf("Usage: %s pru_code.bin\n", argv[0]);
   return 1;
  }

  // If this segfaults, make sure you're executing as root.
  prussdrv_init();
  if (prussdrv_open(PRU_EVTOUT_0) == -1) {
   printf("prussdrv_open() failed\n");
   return 1;
  }

  tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
  prussdrv_pruintc_init(&pruss_intc_initdata);

  // Pointer into the 8KB of shared PRU DRAM
  volatile void *shared_memory_void = NULL;
  // Useful if we're storing data there in 4-byte chunks
  volatile uint32_t *shared_memory = NULL;
  prussdrv_map_prumem(PRUSS0_SHARED_DATARAM, (void **) &shared_memory_void);
  shared_memory = (uint32_t *) shared_memory_void;

  // Wait for the PRU to let us know it's done
  printf("PRU0 Test 1 STARTED!\n");

  FILE * fp;
  fp = fopen ("PRU0Test1.csv", "w+");

  // Change to 0 to use PRU0
  int which_pru = 0;
  prussdrv_exec_program(which_pru, argv[1]);
  prussdrv_pru_wait_event(PRU_EVTOUT_0);
  printf("READ!\n");
  for (int i = 0; i <= 640; i++) {
    fprintf(fp, "%u," , ((uint32_t *) shared_memory)[i]);
  }
  fclose(fp);

  prussdrv_pru_disable(which_pru);
  prussdrv_exit();

  return 0;
 }
