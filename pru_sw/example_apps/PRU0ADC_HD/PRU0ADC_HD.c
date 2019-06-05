// Loads a .bin file into a BeagleBone PRU and then interacts with it
// in shared PRU memory and (system-wide) DDR memory.
//
// Pass in the filename of the .bin file on the command line, eg:
// $ ./pru_loader foo.bin
//
// Compile with:
// gcc -std=gnu99 -o pru_loader pru_loader.c -lprussdrv

#include <time.h>
#include <unistd.h>
#include <stdio.h>
#include <inttypes.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#include <stdlib.h>
#include <signal.h>
#include <signal.h>
#include <pthread.h>

#include <string.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#define BUFFER_SIZE 40
// Triple buffer states
#define NIL    0
#define LOCKED 1
#define READY  2
#define FILLED 3

#define MAXBUFSIZE 1500
#define PORT 10000
#define SA struct sockaddr

pthread_mutex_t lock;
uint32_t triple_buffer[3][BUFFER_SIZE];
int triple_buffer_state[3];
int consumer_idx;
int producer_idx;

// Sing int flag
int done = 0;

//time management
long toMicroseconds(struct timespec *ts);
void sleep_until(struct timespec *ts, int delay);
void sleep_lapse(int delay);
long getCurrentMicroseconds();
/////

char newLine = '\n';

// Function designed for chat between client and server.
void func(int sockfd)
{
    int size1;
    int size2;
    uint32_t value;
    char buffer[MAXBUFSIZE];
    char buffer2[MAXBUFSIZE];
    bzero(buffer, MAXBUFSIZE);
    bzero(buffer2, MAXBUFSIZE);
    for(int i = 0; i < BUFFER_SIZE; i++)
    {
        bzero(buffer2, MAXBUFSIZE);
        value = triple_buffer[producer_idx][i];
        sprintf(buffer2, "%u,", value);
        size1 = strlen(buffer);
        size2 = strlen(buffer2);
        if(size1 + size2 > MAXBUFSIZE) break;
        sprintf(buffer + size1, "%s", buffer2);
    }
    bzero(buffer2, MAXBUFSIZE);
    sprintf(buffer2, "%c", newLine);
    size1 = strlen(buffer);
    sprintf(buffer + size1, "%s", buffer2);
    size1 = strlen(buffer);
    int ret = write(sockfd, buffer, size1);
    //printf("ret: %d size1: %d\n", ret, size1);
    //printf("%s", buffer);
}

void sighandler(int);

int main(int argc, char **argv)
{
    if (argc != 2)
    {
        printf("Usage: %s pru_code.bin\n", argv[0]);
        return 1;
    }

    int r, x;
    for(r = 0; r < 3; r++) triple_buffer_state[r] = NIL;
    for(r = 0; r < 3; r++)
        for(x = 0; x < BUFFER_SIZE; x++)
            triple_buffer[r][x] = 4096U;
    /*
    pthread_t thread_id;
    if (pthread_mutex_init(&lock, NULL) != 0)
    {
        printf("\nmutex init failed\n");
        return 1;
    }
    */
    signal(SIGINT, sighandler);

    // If this segfaults, make sure you're executing as root.
    prussdrv_init();
    if (prussdrv_open(PRU_EVTOUT_0) == -1)
    {
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
    shared_memory[0] = physical_address;

    printf("DDR SIZE in bytes %u\n", shared_ddr_len);

    FILE *fp;
    fp = fopen ("PRU0ADCHDData.csv", "w+");

    // Wait for the PRU to let us know it's done
    printf("PRU0 Test ADC STARTED!\n");

    producer_idx = 0;
    consumer_idx = 0;
    triple_buffer_state[producer_idx] = FILLED;

    //pthread_create(&thread_id, NULL, myThreadTCP, NULL);

    long time1 = getCurrentMicroseconds();
    // Change to 0 to use PRU0
    int which_pru = 0;
    prussdrv_pru_clear_event ( PRU_EVTOUT0, PRU0_ARM_INTERRUPT );
    prussdrv_exec_program(which_pru, argv[1]);
    prussdrv_pru_wait_event(PRU_EVTOUT_0);

    struct timespec ts;
    int k = 0;
    int i = 0;
    uint32_t j = 0;
    while(!done)
    {
        j = ((uint32_t *) shared_memory)[i];
        while(j == 0)
        {
            sleep_lapse(13 * 1000);
            j = ((uint32_t *) shared_memory)[i];
            //printf("%u\n", j);
        }
        shared_memory[i] = 0U;

        for(int l = 0; l<2500 * (8 / 2); l++){
            uint32_t data = ((uint32_t *) shared_ddr)[k+l];
            uint32_t data1 = data & 0xFFF;
            uint32_t data2 = (data >> 16) & 0xFFF;
            fprintf(fp, "%u,", data1);
            fprintf(fp, "%u,", data2);
        }
        //triple_buffer[producer_idx][i] = data1;
        // printf("%u\n", data1);
        //fprintf(fp, "%u,", data1);

        i++;
        if(i >= 40)
        {
            i = 0;
            k = 0;
                        
            long time2 = getCurrentMicroseconds();
            printf("Time: %ld\n", time2 - time1);
            time1 = time2;

        }

        k = k + 2500 * (8 / 2);
    }

    prussdrv_pru_disable(which_pru);
    prussdrv_exit();

    fclose(fp);

    printf("Close All\n");

    return 0;
}

void sighandler(int signum)
{
    //printf("Caught signal %d, coming out...\n", signum);
    if(signum == 2) done = 1;
}

////// Time management useful routines /////////////
/**
*
*/
long toMicroseconds(struct timespec *ts)
{
    return ((ts->tv_sec) * 1000000 + (ts->tv_nsec) / 1000);
}

/**
* Adds "delay" microseconds to timespecs and sleeps until that new time
* This function is intended to implement periodic processes with absolute
* activation times.
*/
void sleep_until(struct timespec *ts, int delay)
{
    long oneSecond = 1000 * 1000 * 1000;
    ts->tv_nsec += delay * 1000;
    if(ts->tv_nsec >= oneSecond)
    {
        ts->tv_nsec -= oneSecond;
        ts->tv_sec++;
    }
    clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, ts,  NULL);
}

/**
* Sleeps "delay" microseconds.
* This function is intended to implement periodic processes with relative
* activation times.
*/
void sleep_lapse(int delay)
{
    long oneSecond = 1000 * 1000; //in microseconds
    struct timespec ts;
    ts.tv_sec = delay / oneSecond;
    ts.tv_nsec = (delay % oneSecond) * 1000;
    clock_nanosleep(CLOCK_MONOTONIC, 0, &ts,  NULL);
}


long getCurrentMicroseconds()
{
    struct timespec currentTime;
    clock_gettime(CLOCK_MONOTONIC, &currentTime);
    return (currentTime.tv_sec) * 1000000 + (currentTime.tv_nsec) / 1000;
}
//////////////////////////////////////////////////
