KVMAIN   TITLE 'KVMAIN - Main Driver for z/OS HLASM Key-Value Store'
***********************************************************************
*                                                                     *
*  Module:   KVMAIN                                                   *
*  Purpose:  Main entry point for the KV Store utility. Parses        *
*            PARM data from JCL, dispatches operations to KVTABLE,    *
*            manages VSAM persistence via KVVSAM, and reports         *
*            results via WTO (Write To Operator).                     *
*                                                                     *
*  JCL PARM format:                                                   *
*    PARM='op,key[,value]'                                            *
*    Where:                                                           *
*      op    = INSERT | LOOKUP | UPDATE | DELETE | STATS              *
*      key   = Key string (1-20 chars, required except STATS)        *
*      value = Value string (1-32 chars, INSERT/UPDATE only)          *
*                                                                     *
*  Examples:                                                          *
*    PARM='INSERT,ACCT001,BALANCE=15000'                              *
*    PARM='LOOKUP,ACCT001'                                            *
*    PARM='UPDATE,ACCT001,BALANCE=22500'                              *
*    PARM='DELETE,ACCT001'                                            *
*    PARM='STATS'                                                     *
*                                                                     *
*  Return codes (propagated to JCL via MAXCC):                        *
*    0  = Success                                                     *
*    4  = Key not found                                               *
*    8  = Table full                                                  *
*    12 = Duplicate key on INSERT                                     *
*    16 = Invalid operation or parameter error                        *
*    20 = VSAM I/O error                                              *
*                                                                     *
*  Program flow:                                                      *
*    1. Parse PARM string                                             *
*    2. Open VSAM LDS (KVVSAM OPEN)                                  *
*    3. Execute operation (KVTABLE)                                   *
*    4. Save changes (KVVSAM SAVE) if modification occurred           *
*    5. Close VSAM LDS (KVVSAM CLOSE)                                *
*    6. Report result via WTO                                         *
*    7. Return condition code to JCL                                  *
*                                                                     *
*  Attributes: Reentrant, AMODE 31, RMODE 24                         *
*  (RMODE 24 because PARM address from JCL is below the line)        *
*                                                                     *
***********************************************************************
KVMAIN   CSECT
KVMAIN   AMODE 31
KVMAIN   RMODE 24
*
         COPY  KVENTRY            Include entry DSECT
*
***********************************************************************
*  Entry linkage                                                      *
***********************************************************************
         STM   R14,R12,12(R13)    Save registers
         LR    R12,R15            Base register
         USING KVMAIN,R12
*
*--- Obtain reentrant workarea ---
         GETMAIN R,LV=MWRKLEN
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         USING MWORK,R13
*
*--- Save original R1 (-> PARM address) ---
         L     R2,0(,R1)          R2 -> PARM string (halfword len)
*
***********************************************************************
*  Parse PARM string                                                  *
***********************************************************************
         LH    R3,0(,R2)          R3 = PARM length
         LTR   R3,R3              Any PARM?
         BZ    PARMERR            No - error
         C     R3,=F'80'          Sanity check max length
         BH    PARMERR
*
         LA    R4,2(,R2)          R4 -> PARM text (past halfword)
         ST    R4,MWPRMAD          Save PARM text address
         ST    R3,MWPRMLN          Save PARM length
*
*--- Copy PARM to workarea for safe parsing ---
         BCTR  R3,0               Length - 1 for EX
         EX    R3,PRMMVC          Copy PARM to MWPRMBF
         LA    R3,1(,R3)          Restore length
*
*--- Parse operation name (first field before comma) ---
         LA    R4,MWPRMBF         R4 -> start of PARM buffer
         LR    R5,R3              R5 = remaining length
         LA    R6,MWOPNAM          R6 -> op name buffer
         SR    R7,R7              R7 = op name length
*
PARSOP   DS    0H
         CLI   0(R4),C','         Comma delimiter?
         BE    PARSOPD            Yes - op name complete
         MVC   0(1,R6),0(R4)     Copy byte to op name
         LA    R4,1(,R4)          Advance source
         LA    R6,1(,R6)          Advance target
         LA    R7,1(,R7)          Increment length
         BCT   R5,PARSOP          Continue
         B     PARSOPD            End of PARM = op only (e.g. STATS)
*
PARSOPD  DS    0H
         ST    R7,MWOPLEN          Save op name length
*
*--- Translate op name to opcode ---
         CLC   MWOPNAM(6),=C'INSERT'
         BE    OPINS
         CLC   MWOPNAM(6),=C'LOOKUP'
         BE    OPLKP
         CLC   MWOPNAM(6),=C'UPDATE'
         BE    OPUPD
         CLC   MWOPNAM(6),=C'DELETE'
         BE    OPDLT
         CLC   MWOPNAM(5),=C'STATS'
         BE    OPSTT
         B     PARMERR            Unknown operation
*
OPINS    MVC   MWOPCD,=F'1'
         B     PARSKY
OPLKP    MVC   MWOPCD,=F'2'
         B     PARSKY
OPUPD    MVC   MWOPCD,=F'3'
         B     PARSKY
OPDLT    MVC   MWOPCD,=F'4'
         B     PARSKY
OPSTT    MVC   MWOPCD,=F'5'
         B     DOOPEN              STATS doesn't need key/value
*
***********************************************************************
*  Parse key (second field)                                           *
***********************************************************************
PARSKY   DS    0H
         LTR   R5,R5              Any bytes remaining?
         BZ    PARMERR            No - key required but missing
         LA    R4,1(,R4)          Skip the comma
         BCTR  R5,0               Adjust remaining length
         LTR   R5,R5
         BZ    PARMERR            Nothing after comma
*
         LA    R6,MWKEY            R6 -> key buffer
         XC    MWKEY,MWKEY         Clear key buffer
         SR    R7,R7              Key length counter
*
PARSK2   DS    0H
         CLI   0(R4),C','         Another comma?
         BE    PARSKD             Yes - key done, value follows
         MVC   0(1,R6),0(R4)
         LA    R4,1(,R4)
         LA    R6,1(,R6)
         LA    R7,1(,R7)
         C     R7,=F'20'          Max key length?
         BNL   PARSKD
         BCT   R5,PARSK2
*
PARSKD   DS    0H
         ST    R7,MWKEYLN          Save key length
         LTR   R7,R7
         BZ    PARMERR            Empty key
*
***********************************************************************
*  Parse value (third field, optional)                                *
***********************************************************************
         XC    MWVALUE,MWVALUE     Clear value buffer
         MVC   MWVALLN,=F'0'      Default value length = 0
*
         LTR   R5,R5              Any bytes remaining?
         BZ    DOOPEN             No - that's fine for LOOKUP/DELETE
         LA    R4,1(,R4)          Skip comma
         BCTR  R5,0
         LTR   R5,R5
         BZ    DOOPEN             Nothing after comma
*
         LA    R6,MWVALUE          R6 -> value buffer
         SR    R7,R7
*
PARSV2   DS    0H
         MVC   0(1,R6),0(R4)
         LA    R4,1(,R4)
         LA    R6,1(,R6)
         LA    R7,1(,R7)
         C     R7,=F'32'          Max value length?
         BNL   PARSVD
         BCT   R5,PARSV2
*
PARSVD   DS    0H
         ST    R7,MWVALLN
*
***********************************************************************
*  Step 1: Open VSAM LDS                                              *
***********************************************************************
DOOPEN   DS    0H
         WTO   'KVMAIN: Opening VSAM LDS...',ROUTCDE=11
*
         LA    R1,MWVPARM          Build parm list for KVVSAM
         MVC   MWVPARM(4),=F'1'   Opcode = OPEN
         LA    R2,MWTBLAD          Address of table address word
         ST    R2,MWVPARM+4        Second parm = &mapaddr
         L     R15,=V(KVVSAM)
         BALR  R14,R15
         LTR   R15,R15
         BNZ   VSAMERR
*
***********************************************************************
*  Step 2: Execute the requested operation via KVTABLE                *
***********************************************************************
         WTO   'KVMAIN: Executing operation...',ROUTCDE=11
*
*--- Build parameter list for KVTABLE ---
         LA    R1,MWTPARM
         MVC   MWTPARM(4),MWOPCD       Opcode
         MVC   MWTPARM+4(4),MWTBLAD    Table address
         LA    R2,MWKEY
         ST    R2,MWTPARM+8            Key address
         MVC   MWTPARM+12(4),MWKEYLN   Key length
         LA    R2,MWVALUE
         ST    R2,MWTPARM+16           Value address
         MVC   MWTPARM+20(4),MWVALLN   Value length
         LA    R2,MWOUTBF
         ST    R2,MWTPARM+24           Output buffer address
*
         L     R15,=V(KVTABLE)
         BALR  R14,R15
         ST    R15,MWOPRC               Save operation RC
*
***********************************************************************
*  Step 3: Save if modification op succeeded                          *
***********************************************************************
         L     R2,MWOPRC
         LTR   R2,R2              Operation succeeded?
         BNZ   SKIPSAV            No - don't save
*
*--- Only save for modification operations (INSERT/UPDATE/DELETE) ---
         L     R3,MWOPCD
         C     R3,=F'1'           INSERT?
         BE    DOSAVE
         C     R3,=F'3'           UPDATE?
         BE    DOSAVE
         C     R3,=F'4'           DELETE?
         BE    DOSAVE
         B     SKIPSAV            LOOKUP/STATS = no save needed
*
DOSAVE   DS    0H
         WTO   'KVMAIN: Saving changes to VSAM LDS...',ROUTCDE=11
         LA    R1,MWVPARM
         MVC   MWVPARM(4),=F'2'  Opcode = SAVE
         LA    R2,MWTBLAD
         ST    R2,MWVPARM+4
         L     R15,=V(KVVSAM)
         BALR  R14,R15
         LTR   R15,R15
         BNZ   VSAMERR
*
SKIPSAV  DS    0H
*
***********************************************************************
*  Step 4: Report results                                             *
***********************************************************************
*--- Report based on operation type ---
         L     R3,MWOPCD
         L     R2,MWOPRC
*
         C     R3,=F'2'           LOOKUP?
         BNE   RPTGEN
*
*--- LOOKUP: display found value ---
         LTR   R2,R2              Found?
         BNZ   RPTGEN             No - generic message
         WTO   'KVMAIN: LOOKUP result:',ROUTCDE=11
*--- Build WTO with value content ---
         MVC   MWWTOBF(32),MWOUTBF  Copy value to WTO buffer
         LA    R1,MWWTOMSG
         WTO   MF=(E,(1))         Issue WTO
         B     RPTDONE
*
RPTGEN   DS    0H
*--- Generic result reporting ---
         LTR   R2,R2
         BNZ   RPTFAIL
         WTO   'KVMAIN: Operation completed successfully (RC=0)',     X
               ROUTCDE=11
         B     RPTDONE
*
RPTFAIL  DS    0H
         C     R2,=F'4'
         BNE   RPTFL2
         WTO   'KVMAIN: Key not found (RC=4)',ROUTCDE=11
         B     RPTDONE
RPTFL2   DS    0H
         C     R2,=F'8'
         BNE   RPTFL3
         WTO   'KVMAIN: Table full (RC=8)',ROUTCDE=11
         B     RPTDONE
RPTFL3   DS    0H
         C     R2,=F'12'
         BNE   RPTFL4
         WTO   'KVMAIN: Duplicate key (RC=12)',ROUTCDE=11
         B     RPTDONE
RPTFL4   DS    0H
         WTO   'KVMAIN: Operation failed with unexpected RC',        X
               ROUTCDE=11
*
RPTDONE  DS    0H
*
***********************************************************************
*  Step 5: Close VSAM LDS                                             *
***********************************************************************
         WTO   'KVMAIN: Closing VSAM LDS...',ROUTCDE=11
         LA    R1,MWVPARM
         MVC   MWVPARM(4),=F'3'  Opcode = CLOSE
         LA    R2,MWTBLAD
         ST    R2,MWVPARM+4
         L     R15,=V(KVVSAM)
         BALR  R14,R15
*
*--- Set final return code from operation ---
         L     R15,MWOPRC
         B     MAINXIT
*
***********************************************************************
*  Error paths                                                        *
***********************************************************************
PARMERR  DS    0H
         WTO   'KVMAIN: Invalid PARM - expected op,key[,value]',     X
               ROUTCDE=11
         WTO   'KVMAIN: Valid ops: INSERT LOOKUP UPDATE DELETE STATS',X
               ROUTCDE=11
         LA    R15,16
         B     MAINXIT
*
VSAMERR  DS    0H
         WTO   'KVMAIN: VSAM I/O error - see SYSLOG for details',   X
               ROUTCDE=11
         LA    R15,20
         B     MAINXIT
*
***********************************************************************
*  Common exit                                                        *
***********************************************************************
MAINXIT  DS    0H
         LR    R2,R15             Save final RC
         LR    R1,R13
         L     R13,4(,R13)
         FREEMAIN R,LV=MWRKLEN,A=(1)
         LR    R15,R2             Set return code
         L     R14,12(,R13)
         LM    R2,R12,28(R13)
         BR    R14
*
***********************************************************************
*  Executed instructions                                              *
***********************************************************************
PRMMVC   MVC   MWPRMBF(0),0(R4)  Executed: copy PARM string
*
***********************************************************************
*  WTO message template for LOOKUP output                             *
***********************************************************************
MWWTOMSG WTO   'KVMAIN: Value=................................',      X
               ROUTCDE=11,MF=L
*
***********************************************************************
*  Constants                                                          *
***********************************************************************
         LTORG
*
***********************************************************************
*  Dynamic workarea                                                   *
***********************************************************************
MWORK    DSECT
MWSAVE   DS    18F                Save area
*--- PARM parsing fields ---
MWPRMAD  DS    A                  PARM text address
MWPRMLN  DS    F                  PARM text length
MWPRMBF  DS    CL80              PARM text copy buffer
MWOPNAM  DS    CL8               Operation name (e.g., 'INSERT')
MWOPLEN  DS    F                  Operation name length
MWOPCD   DS    F                  Operation code (1-5)
MWKEY    DS    CL20              Key buffer
MWKEYLN  DS    F                  Key length
MWVALUE  DS    CL32              Value buffer
MWVALLN  DS    F                  Value length
*--- Runtime state ---
MWTBLAD  DS    A                  Address of mapped table
MWOPRC   DS    F                  Operation return code
MWOUTBF  DS    CL64              Output buffer (LOOKUP/STATS)
*--- Parameter build areas for KVVSAM and KVTABLE calls ---
MWVPARM  DS    2F                KVVSAM parameter list
MWTPARM  DS    7F                KVTABLE parameter list
*--- WTO buffer ---
MWWTOBF  DS    CL32              WTO value display buffer
         DS    0D                 Align to doubleword
MWRKLEN  EQU   *-MWORK
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
         END   KVMAIN
