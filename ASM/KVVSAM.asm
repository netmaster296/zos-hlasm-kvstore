KVVSAM   TITLE 'KVVSAM - VSAM LDS Persistence Layer for KV Store'
***********************************************************************
*                                                                     *
*  Module:   KVVSAM                                                   *
*  Purpose:  Manages persistence of the hash table to a VSAM         *
*            Linear Data Set (LDS) using Data-In-Virtual (DIV)       *
*            services. DIV maps the LDS directly into virtual        *
*            storage, providing memory-mapped file semantics.         *
*                                                                     *
*  Entry:    R1 -> Parameter list                                     *
*              +0  F(opcode)   - Operation code                       *
*                   1 = OPEN   (Identify + Map)                       *
*                   2 = SAVE   (Persist to LDS)                       *
*                   3 = CLOSE  (Unmap + Unidentify)                   *
*              +4  A(mapaddr)  - Address of fullword to receive/      *
*                                provide mapped storage address       *
*                                                                     *
*  Exit:     R15 = Return code                                        *
*              0  = Success                                           *
*              8  = DIV operation failed                               *
*              12 = Invalid operation                                  *
*            For OPEN: fullword at mapaddr is set to the address      *
*              of the mapped table in virtual storage                 *
*                                                                     *
*  Notes:    - The VSAM LDS must be pre-allocated via IDCAMS          *
*            - DD name KVLDS must be allocated in JCL                  *
*            - Table size is KVTBLBYT (64K = 1024 entries * 64)       *
*                                                                     *
*  Attributes: Reentrant, AMODE 31, RMODE ANY                        *
*                                                                     *
***********************************************************************
KVVSAM   CSECT
KVVSAM   AMODE 31
KVVSAM   RMODE ANY
*
         COPY  KVENTRY            For KVTBLBYT equate
*
***********************************************************************
*  Entry linkage                                                      *
***********************************************************************
         STM   R14,R12,12(R13)
         LR    R12,R15
         USING KVVSAM,R12
*
         GETMAIN R,LV=VWRKLEN
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         USING VWORK,R13
*
***********************************************************************
*  Parse parameters                                                   *
***********************************************************************
         L     R2,0(,R1)          R2 = opcode
         L     R3,4(,R1)          R3 -> mapaddr fullword
         ST    R3,VWMAPAD          Save mapaddr pointer
*
***********************************************************************
*  Dispatch                                                           *
***********************************************************************
         C     R2,=F'1'
         BE    VOPEN
         C     R2,=F'2'
         BE    VSAVE
         C     R2,=F'3'
         BE    VCLOSE
         LA    R15,12             Invalid opcode
         B     VSAMXIT
*
***********************************************************************
*  OPEN - DIV IDENTIFY + MAP                                          *
*  Maps the VSAM LDS into virtual storage for direct access          *
***********************************************************************
VOPEN    DS    0H
*
*--- Allocate a DIV ID token (8 bytes) ---
         XC    VWDIVID,VWDIVID    Clear DIV ID area
*
*--- DIV IDENTIFY: associate DD 'KVLDS' with a DIV object ---
         DIV   IDENTIFY,                                              X
               ID=VWDIVID,                                            X
               DDNAME=KVLDSDD,                                        X
               TYPE=DA
         LTR   R15,R15
         BNZ   VFAIL
*
*--- Obtain virtual storage for the map window ---
         GETMAIN R,LV=KVTBLBYT    Get 64K for table
         ST    R1,VWMAPST          Save mapped storage address
*
*--- DIV MAP: map the LDS content into our storage ---
         DIV   MAP,                                                   X
               ID=VWDIVID,                                            X
               AREA=(R1),                                             X
               SIZE==A(KVTBLBYT),                                     X
               OFFSET=0,                                              X
               SPAN=ALL,                                              X
               MODE=UPDATE
         LTR   R15,R15
         BNZ   VFAIL
*
*--- Return mapped address to caller ---
         L     R3,VWMAPAD          R3 -> caller's address word
         L     R4,VWMAPST          R4 = mapped storage address
         ST    R4,0(,R3)           Return it to caller
*
*--- Log success ---
         WTO   'KVVSAM: VSAM LDS opened and mapped successfully',    X
               ROUTCDE=11
*
         SR    R15,R15             RC = 0
         B     VSAMXIT
*
***********************************************************************
*  SAVE - DIV SAVE                                                    *
*  Persist modified table data back to the VSAM LDS                  *
***********************************************************************
VSAVE    DS    0H
         L     R1,VWMAPST         Mapped storage address
         DIV   SAVE,                                                  X
               ID=VWDIVID,                                            X
               AREA=(R1),                                             X
               SIZE==A(KVTBLBYT),                                     X
               OFFSET=0,                                              X
               SPAN=ALL
         LTR   R15,R15
         BNZ   VFAIL
*
         WTO   'KVVSAM: Table data saved to VSAM LDS',               X
               ROUTCDE=11
*
         SR    R15,R15
         B     VSAMXIT
*
***********************************************************************
*  CLOSE - DIV UNMAP + UNIDENTIFY                                    *
***********************************************************************
VCLOSE   DS    0H
         L     R1,VWMAPST
*
*--- Unmap the storage ---
         DIV   UNMAP,                                                 X
               ID=VWDIVID,                                            X
               AREA=(R1),                                             X
               SIZE==A(KVTBLBYT)
*
*--- Free the mapped storage ---
         L     R1,VWMAPST
         FREEMAIN R,LV=KVTBLBYT,A=(R1)
*
*--- Unidentify the DIV object ---
         DIV   UNIDENTIFY,                                            X
               ID=VWDIVID
*
         WTO   'KVVSAM: VSAM LDS closed and unmapped',               X
               ROUTCDE=11
*
         SR    R15,R15
         B     VSAMXIT
*
***********************************************************************
*  Error handling                                                     *
***********************************************************************
VFAIL    DS    0H
*--- R15 already has the DIV return code ---
         ST    R15,VWDIVRC         Save DIV RC for diagnostics
         WTO   'KVVSAM: DIV operation failed - check SYSLOG',        X
               ROUTCDE=11
         LA    R15,8              RC = 8
         B     VSAMXIT
*
***********************************************************************
*  Exit                                                               *
***********************************************************************
VSAMXIT  DS    0H
         LR    R2,R15             Save RC
         LR    R1,R13
         L     R13,4(,R13)
         FREEMAIN R,LV=VWRKLEN,A=(1)
         LR    R15,R2
         L     R14,12(,R13)
         LM    R2,R12,28(R13)
         BR    R14
*
***********************************************************************
*  Constants                                                          *
***********************************************************************
KVLDSDD  DC    CL8'KVLDS'         DD name for VSAM LDS
         LTORG
*
***********************************************************************
*  Dynamic workarea                                                   *
***********************************************************************
VWORK    DSECT
VWSAVE   DS    18F                Save area
VWDIVID  DS    XL8                DIV identifier token
VWMAPST  DS    A                  Address of mapped storage
VWMAPAD  DS    A                  Caller's mapaddr pointer
VWDIVRC  DS    F                  Last DIV return code
VWRKLEN  EQU   *-VWORK
*
***********************************************************************
*  Register equates                                                   *
***********************************************************************
R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R7       EQU   7
R8       EQU   8
R9       EQU   9
R10      EQU   10
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15
*
         END   KVVSAM
