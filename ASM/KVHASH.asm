KVHASH   TITLE 'KVHASH - DJB2 Hash Function for Key-Value Store'
***********************************************************************
*                                                                     *
*  Module:   KVHASH                                                   *
*  Purpose:  Implements the DJB2 hash algorithm for string keys.      *
*            Returns a 32-bit unsigned hash value suitable for        *
*            indexing into the hash table.                             *
*                                                                     *
*  Entry:    R1 -> Parameter list                                     *
*              +0  A(key)       - Address of key string               *
*              +4  F(keylen)    - Length of key (1-20)                 *
*                                                                     *
*  Exit:     R0 = 32-bit hash value                                   *
*            R15 = 0 (success) or 8 (invalid input)                   *
*                                                                     *
*  Registers: R2-R5 used as work registers (saved/restored)           *
*                                                                     *
*  Algorithm: DJB2 by Daniel J. Bernstein                             *
*             hash = 5381                                             *
*             for each byte c in key:                                 *
*               hash = hash * 33 + c                                  *
*             which is equivalent to:                                 *
*               hash = (hash << 5) + hash + c                        *
*                                                                     *
*  Attributes: Reentrant, AMODE 31, RMODE ANY                        *
*                                                                     *
***********************************************************************
KVHASH   CSECT
KVHASH   AMODE 31
KVHASH   RMODE ANY
*
***********************************************************************
*  Standard entry linkage - save caller's registers                   *
***********************************************************************
         STM   R14,R12,12(R13)    Save caller's registers
         LR    R12,R15            Establish base register
         USING KVHASH,R12
*
***********************************************************************
*  Obtain reentrant workarea via GETMAIN                              *
***********************************************************************
         GETMAIN R,LV=WORKLEN     Get dynamic workarea
         ST    R13,4(R1)          Chain save areas (backward)
         ST    R1,8(R13)          Chain save areas (forward)
         LR    R13,R1             Point R13 to new save area
         USING WORKAREA,R13
*
***********************************************************************
*  Parse input parameters                                             *
***********************************************************************
         L     R2,0(,R1)          R2 -> key string
         L     R3,4(,R1)          R3 = key length
*
*--- Validate key length (1 - 20) ---
         LTR   R3,R3              Length <= 0?
         BNP   HASHERR            Yes - error
         C     R3,=F'20'          Length > 20?
         BH    HASHERR            Yes - error
*
***********************************************************************
*  DJB2 Hash Computation                                              *
*  R4 = running hash value                                            *
*  R5 = current byte (zero-extended)                                  *
*  R3 = remaining length (loop counter)                               *
*  R2 = current position in key                                       *
***********************************************************************
         L     R4,=F'5381'        Initialize hash = 5381
*
HASHLOOP DS    0H
         SR    R5,R5              Clear R5
         IC    R5,0(,R2)          Load one byte of key into R5
*
*--- hash = (hash << 5) + hash + c ---
*--- This is equivalent to hash * 33 + c ---
         LR    R6,R4              R6 = copy of hash
         SLL   R4,5               hash << 5
         AR    R4,R6              + original hash  (= hash * 33)
         AR    R4,R5              + current byte
*
*--- Advance to next byte ---
         LA    R2,1(,R2)          Next byte of key
         BCT   R3,HASHLOOP        Decrement R3, loop if > 0
*
***********************************************************************
*  Return hash value in R0, RC=0 in R15                               *
***********************************************************************
         LR    R0,R4              Return hash in R0
         SR    R15,R15            RC = 0
         B     HASHXIT            Go to exit
*
***********************************************************************
*  Error path - invalid input                                         *
***********************************************************************
HASHERR  DS    0H
         SR    R0,R0              Hash = 0
         LA    R15,8              RC = 8
*
***********************************************************************
*  Exit - free workarea and return                                    *
***********************************************************************
HASHXIT  DS    0H
         LR    R1,R13             Save workarea address
         L     R13,4(,R13)        Restore caller's save area
         FREEMAIN R,LV=WORKLEN,A=(1)  Free workarea
         L     R14,12(,R13)       Restore return address
         LM    R2,R12,28(R13)     Restore R2-R12
         BR    R14                Return to caller
*
***********************************************************************
*  Constants                                                          *
***********************************************************************
         LTORG
*
***********************************************************************
*  Dynamic workarea (reentrant)                                       *
***********************************************************************
WORKAREA DSECT
SAVEAREA DS    18F                Standard 72-byte save area
WORKLEN  EQU   *-WORKAREA
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
         END   KVHASH
