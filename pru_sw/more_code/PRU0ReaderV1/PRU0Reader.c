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

 #include <sys/time.h>

 /**
 * Returns the current time in microseconds.
 */
long getMicrotime(){
	struct timeval currentTime;
	gettimeofday(&currentTime, NULL);
	return currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
}

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

  // Pointer into the DDR RAM mapped by the uio_pruss kernel module.
  volatile void *shared_ddr = NULL;
  prussdrv_map_extmem((void **) &shared_ddr);
  unsigned int shared_ddr_len = prussdrv_extmem_size();
  unsigned int physical_address = prussdrv_get_phys_addr((void *) shared_ddr);

  // We'll use the first 8 bytes of PRU memory to tell it where the
  // shared segment of system memory is.

  // Wait for the PRU to let us know it's done
  printf("All done\n");

  printf("%u bytes of shared DDR available.\n Physical (PRU-side) address:%x\n",
      shared_ddr_len, physical_address);
  printf("Virtual (linux-side) address: %p\n\n", shared_ddr);

  long t1 = 0;
  long t2 = 0;
  FILE * fp;

  fp = fopen ("data.csv", "w+");

  // Change to 0 to use PRU0
  int which_pru = 0;
  t1 = getMicrotime();
  prussdrv_exec_program(which_pru, argv[1]);
  //prussdrv_pru_wait_event(PRU_EVTOUT_0);
  //prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

  //printf("READY!\n");
  prussdrv_pru_wait_event(PRU_EVTOUT_0);
  t2 = getMicrotime();
  printf("READ!\n");
  //printf("Time %lld\n", t2-t1);
  //printf("Time t1 : %u t2 : %u\n", shared_memory[3], shared_memory[4]);
  //printf("Runtime t : %u \n", shared_memory[4] - shared_memory[3] );

/*
  //for (int j = 0; j < 4; j++) {
    prussdrv_pru_wait_event(PRU_EVTOUT_0);
    //prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);
    //for (int i = 0; i < (shared_ddr_len/4)/4; i+=8) {
    //for (int i = 0; i < 8; i++){
    for (int i = 0; i < shared_ddr_len/4; i+=8) {
     // See if it's successfully writing the physical address of each word at
     // the (virtual, from our viewpoint) address
     //printf("DDR[%d] is: %p / 0x%x\n", i, ((unsigned int *)shared_ddr) + i, ((unsigned int *) shared_ddr)[i]);
     printf("DDR[%d] is: %p / %u\n", i, ((unsigned int *)shared_ddr) + i, ((unsigned int *) shared_ddr)[i]);
    }
  //}
*/
/*
for (int i = 0; i < shared_ddr_len/4; i+=8) {
  for(int j = 0; j<8; j++) fprintf(fp, "%u,", ((unsigned int *) shared_ddr)[i+j]);
  fprintf(fp, "\n");
}*/
for (int i = 0; i < 3072; i++) {
  fprintf(fp, "%u,", ((unsigned int *) shared_memory)[i]);
}

 fclose(fp);

/*
  // Wait for the PRU to let us know it's done
  printf("All done\n");

  printf("%u bytes of shared DDR available.\n Physical (PRU-side) address:%x\n",
      shared_ddr_len, physical_address);
  printf("Virtual (linux-side) address: %p\n\n", shared_ddr);

  printf("Last value.\n Physical (PRU-side) address:%x\n",
      shared_ddr_len + physical_address);
  printf("Virtual (linux-side) address: %p\n\n", shared_ddr + shared_ddr_len);
*/
  prussdrv_pru_disable(which_pru);
  prussdrv_exit();

  return 0;
 }
