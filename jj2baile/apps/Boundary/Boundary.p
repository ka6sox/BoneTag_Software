.origin 0
.entrypoint BEGIN

// Macros
#define PRU                     0
#define PRU0
#define PRU0_ARM_INTERRUPT      19

#define PRUCFG  C4
#define PRU_LOCAL C24

//TMP for now
// GPIO1_12
#define TCK 14 
#define TCK_BIT (1<<TCK)
// GPIO1_13
#define TMS 15 
#define TMS_BIT (1<<TMS)
// GPIO3_21
#define TDI 7 
#define TDI_BIT (1<<TDI) 
// GPIO3_19
#define TDO 5 
#define TDO_BIT (1<<TDO)

#define CTBIR_0          0x22020

.macro pulse_clk
    clr r30, TCK
    set r30, TCK
.endm

// end macros

BEGIN:
  //SETUP
    // Enable OCP master port -- For accessing entire memory space
    // Does this cause any problems or change performance?
    LBCO r0, PRUCFG, 4, 4
    CLR r0, r0, 4         // Clear SYSCFG[STANDBY_INIT] to enable OCP master port
    SBCO r0, PRUCFG, 4, 4

    // Disable Offsets just in case it isn't already?
    LBCO r0, PRUCFG, 0x28, 4
    CLR r0, r0, 0         // Clear PMAO[PMAO_PRU0] to disable offset hijinks
    SBCO r0, PRUCFG, 0x28, 4
    
    //Make C24 point to 0x00000000 and C25 point to 0x00002000
    mov r0, 0x00
    mov r1, CTBIR_0
    sbbo r0, r1, 0, 4
  //ENDSETUP


  // Count Size of JTAG Chain
    // JTAG Reset State
    set r30, TMS
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    // JTAG to SHIFT-IR state
    clr r30, TMS
    pulse_clk
    set r30, TMS
    pulse_clk
    pulse_clk
    clr r30, TMS
    pulse_clk
    pulse_clk
    // Fill IR with 1 (bypass mode)
    clr r30, TMS
    set r30, TDI
    mov r0, 999
set_bypass:
    pulse_clk
    sub r0, r0, 1
    qbne set_bypass, r0, 0
    // Go to SHIFT-DR
    set r30, TMS
    pulse_clk
    pulse_clk
    pulse_clk
    clr r30, TMS
    pulse_clk
    pulse_clk
    // Now in Shift-DR, Flood DR with 0s -- Hopefully large enough number
    clr r30, TDI
    mov r0, 999
flood_data_zero:
    pulse_clk
    sub r0, r0, 1
    qbne flood_data_zero, r0, 0
    // Shift 1 until received back
    set r30, TDI
    mov r0, -1
flood_data_one:
    pulse_clk
    add r0, r0, 1 
    qbbc flood_data_one, r31, TDO 

    // r0 now contains the size of the jtag chain
    // Write it into PRU local memory, C program can find it
    sbco r0, PRU_LOCAL, 0, 4

  
  // Find IDCODE of each device -- 
  // If IDCODE not supported, 0 returned instead

    // Bonus level: Refill bypass DR with 0 
    // Can be avoided if we switch probing parity
    mov r1, 0
    clr r30, TDI
bypass_zero:
    pulse_clk
    add r1, r1, 1
    qbne bypass_zero, r1, r0

    // JTAG Reset State
    set r30, TMS
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    // Shift-DR state
    clr r30, TMS
    pulse_clk
    set r30, TMS
    pulse_clk
    clr r30, TMS
    pulse_clk
    pulse_clk

    // Read 32 bits for each device (that is in IDCODE state)
    // into ram starting at PRU_LOCAL[1]
    mov r1, 4  // Start offset of IDCODEs
    clr r30, TMS //Extraneous
id_loop:
    mov r3, 0
    pulse_clk
    // IDCODE guaranteed to have M[0]=1, and BYPASS register has M[0]=0
    // use 0 as IDCODE for ICs that don't implement this.
    qbbc id_loop_end, r31, TDO    

    mov r2, 1
    set r3, 0
    loop_31:
        pulse_clk 
        qbbc skip_set_bit, r31, TDO
        set r3, r2
    skip_set_bit: 
        add r2, r2, 1
        qbne loop_31, r2, 32
id_loop_end:
    sbco r3, PRU_LOCAL, r1, 4
    add r1, r1, 4
    sub r0, r0, 1
    qbne id_loop, r0, 0

  // Boundary Scan Next
  // Code below highly specific to stellaris launchpad
    mov r4, 121
    // JTAG Reset State
    set r30, TMS
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    pulse_clk
    // Shift-IR state
    clr r30, TMS
    pulse_clk
    set r30, TMS
    pulse_clk
    pulse_clk
    clr r30, TMS
    pulse_clk
    pulse_clk
    // clock in SAMPLE
    set r30, TDI
    pulse_clk // Device 0 bypass
    clr r30, TDI
    pulse_clk
    set r30, TDI
    pulse_clk
    clr r30, TDI
    pulse_clk
    pulse_clk
    // Go to Shift-DR
    set r30, TMS
    pulse_clk
    pulse_clk
    pulse_clk
    clr r30, TMS
    pulse_clk
    pulse_clk
#define BLEN 121
    pulse_clk // Device 0 bypass throw away
    mov r0, BLEN
    lsr r0, r0, 5
    add r0, r0, 1
    mov r4, 32
id2_loop:
    qbne ful, r0, 1
    mov r5, BLEN
    mov r4, 31
    not r4, r4
    and r4, r5, r4
    sub r4, r5, r4
ful:
    mov r2, 0
    mov r3, 0
    loop2_32:
        pulse_clk
        qbbc skip_set_bit2, r31, TDO
        set r3, r2
    skip_set_bit2:
        add r2, r2, 1
        qbne loop2_32, r2, r4
    sbco r3, PRU_LOCAL, r1, 4
    add r1, r1, 4
    sub r0, r0, 1
    qbne id2_loop, r0, 0

    mov r31.b0, PRU0_ARM_INTERRUPT+16
HALT


    // Stuff
//    wbs r31, TDO
//high:
//    mov r30, TCK_BIT
//    qbbc exit, R31, TDO
//    qba high
//exit:
//    mov r30, 0



// Code fragments that I may want later.
    // Set pinmuxing (doesn't work because of linux)
    //MOV r0, CONTROL_MODULE + CONF_GPMC_AD12
    //MOV r1, PINMODE
    //SBBO r1, r0, 0, 4

    // Enable GPIO_OE for GPIO1_12 (Only relevant for GPIO memmap mode)
    //MOV r0, GPIO1 + GPIO_OE
    //LBBO r1, r0, 0, 4
    //SET r1, 12
    //SBBO r1, r0, 0, 4 
