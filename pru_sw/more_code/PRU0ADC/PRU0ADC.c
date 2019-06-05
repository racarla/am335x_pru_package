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

// A normal C function that is executed as a thread
// when its name is specified in pthread_create()
void *myThreadTCP(void *vargp)
{
    int i;
    while(!done)
    {
        usleep(200 * 1000); // 1s
        // find buffer ready
        pthread_mutex_lock(&lock);
        /*
        if(consumer_idx != 3)
        {
            int ant_consumer = consumer_idx;
            consumer_idx++;
            if(consumer_idx > 2) consumer_idx = 0;
            while(ant_consumer != consumer_idx)
            {
                if(triple_buffer_state[consumer_idx] != READY) break;
                consumer_idx++;
                if(consumer_idx > 2) consumer_idx = 0;
            }
            if(ant_consumer == consumer_idx) consumer_idx = 3;
            else triple_buffer_state[producer_idx] = LOCKED;
        } else {
        */
        for(i = 0; i < 3; i++) // Find ready buffer
        {
            if(triple_buffer_state[i] == READY) break;
        }
        consumer_idx = i;
        if(i < 3)
        {
            triple_buffer_state[consumer_idx] = LOCKED;
        }
        //}
        pthread_mutex_unlock(&lock);

        if(consumer_idx != 3)
        {
            printf("CIDX: %d\n", consumer_idx);
            printf("%u\n", triple_buffer[consumer_idx][0]);
            /*
            for(int i = 0; i < BUFFER_SIZE; i++){
              printf("%u ", triple_buffer[consumer_idx][i]);
            }*/
            //printf("Data READY\n");

            pthread_mutex_lock(&lock);
            triple_buffer_state[consumer_idx] = NIL;
            consumer_idx = 3;
            pthread_mutex_unlock(&lock);

        }
        else
        {
            //printf("No data READY\n");
        }

    }
    return NULL;
}

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
    fp = fopen ("PRU0ADCData.csv", "w+");

    // Wait for the PRU to let us know it's done
    printf("PRU0 Test ADC STARTED!\n");

    producer_idx = 0;
    consumer_idx = 0;
    triple_buffer_state[producer_idx] = FILLED;

    //pthread_create(&thread_id, NULL, myThreadTCP, NULL);

    int sockfd, connfd, len;
    struct sockaddr_in servaddr, cli;

    // socket create and verification
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1)
    {
        printf("socket creation failed...\n");
        exit(0);
    }
    else
        printf("Socket successfully created..\n");
    bzero(&servaddr, sizeof(servaddr));

    printf("Socket successfully created..\n");


    // assign IP, PORT
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port = htons(PORT);

    // Binding newly created socket to given IP and verification
    if ((bind(sockfd, (SA *)&servaddr, sizeof(servaddr))) != 0)
    {
        printf("socket bind failed...\n");
        exit(0);
    }
    else
        printf("Socket successfully binded..\n");

    // Now server is ready to listen and verification
    if ((listen(sockfd, 5)) != 0)
    {
        printf("Listen failed...\n");
        exit(0);
    }
    else
        printf("Server listening..\n");
    len = sizeof(cli);

    // Accept the data packet from client and verification
    connfd = accept(sockfd, (SA *)&cli, &len);
    if (connfd < 0)
    {
        printf("server acccept failed...\n");
        exit(0);
    }
    else
        printf("server acccept the client...\n");

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

        uint32_t data = ((uint32_t *) shared_ddr)[k];
        uint32_t data1 = data & 0xFFF;
        triple_buffer[producer_idx][i] = data1;
        // printf("%u\n", data1);
        //fprintf(fp, "%u,", data1);

        i++;
        if(i >= 40)
        {
            i = 0;
            k = 0;
            func(connfd);
            /*
            pthread_mutex_lock(&lock);
            triple_buffer_state[producer_idx] = READY;
            int ant_producer = producer_idx;
            producer_idx++;
            if(producer_idx > 2) producer_idx = 0;
            while(ant_producer != producer_idx)
            {
                if(triple_buffer_state[producer_idx] != NIL) break;
                producer_idx++;
                if(producer_idx > 2) producer_idx = 0;
            }
            triple_buffer_state[producer_idx] = FILLED; // Sobreescribimos el ultimo buffer....
            pthread_mutex_unlock(&lock);
            */
            
            long time2 = getCurrentMicroseconds();
            printf("Time: %ld\n", time2 - time1);
            time1 = time2;
            

            // break;
        }

        k = k + 2500 * (8 / 2);
    }

    prussdrv_pru_disable(which_pru);
    prussdrv_exit();

    //pthread_join(thread_id, NULL);

    fclose(fp);

    // After chatting close the socket 
    close(sockfd); 
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
