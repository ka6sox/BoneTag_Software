#include <stdio.h>
#include <string.h>

#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#include <signal.h>

#define PRU_NUM 0
#define AM33XX


unsigned int* pru0_dataram;

void sig_int_new(int n) {
    printf("\nSIGINT Received: Cleaning up\n");

    printf("MEM[0]: %08X\n", pru0_dataram[0]);
    printf("MEM[1]: %08X\n", pru0_dataram[1]);
    printf("MEM[2]: %08X\n", pru0_dataram[2]);
    printf("MEM[3]: %08X\n", pru0_dataram[3]);
    printf("MEM[4]: %08X\n", pru0_dataram[4]);
    printf("MEM[5]: %08X\n", pru0_dataram[5]);
    printf("MEM[6]: %08X\n", pru0_dataram[6]);
    printf("MEM[20]: %d\n", pru0_dataram[20]);
    prussdrv_pru_disable(PRU_NUM);
    prussdrv_exit();

    raise(SIGTERM);
}
//TODO: Determine IR Length, when IC unknown (how?)
// "Blind interrogation"
// Try making use of the fact that 01 LSB is shifted out for each IR
//
// Boundary Scan
//
int main (void) 
{
    unsigned int ret;
    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

    printf("\nCommencing Boundary Scan Attempt\n");

    prussdrv_init();
    ret = prussdrv_open(PRU_EVTOUT_0);

    if(ret) {
        /* err */ 
        printf("prussdrv_open(PRU_EVTOUT_0) failed to open.\n");
        return (ret);
    }

    // something about interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);

    // Set up some stuff
    prussdrv_map_prumem (PRUSS0_PRU0_DATARAM, (void**)&pru0_dataram);
    pru0_dataram[0] = 42;
    pru0_dataram[1] = 43;
    pru0_dataram[2] = 44;
    pru0_dataram[3] = 45;
    pru0_dataram[4] = 46;
    pru0_dataram[5] = 47;
    pru0_dataram[6] = 48;
    pru0_dataram[20] = 1001;

    signal(SIGINT, sig_int_new);
    // Time to execute the PRU code.
    prussdrv_exec_program(PRU_NUM, "./Boundary.bin");
    printf("PRU0 executing...\n");
    prussdrv_pru_wait_event (PRU_EVTOUT_0);
    prussdrv_pru_clear_event (PRU0_ARM_INTERRUPT);

    printf("Device Count: %d\n", pru0_dataram[0]);
    int i,j;
    for(i=0; i < pru0_dataram[0];i++) {
        printf("Device %d id: %08X\n", i, pru0_dataram[i+1]);
    }

    // Output results of sample command. hardcoded specifically for
    // the stellaris launchpad
    unsigned int* br = pru0_dataram + pru0_dataram[0] + 1;
    printf("Boundary Sample:\n");
    for(i = 0; i < 121/32; i++)
        for(j = 0; j < 32; j++)
            printf("Bit %d: %d\n", i*32 + j, (br[i] >> j)&1);
    for(i = 0; i < 121 - (121/32)*32; i++)
        printf("Bit %d: %d\n", (121/32)*32 + i, (br[121/32] >> i)&1);


    // Clean-up procedures.
    prussdrv_pru_disable(PRU_NUM);
    prussdrv_exit();

    return 0;
}
