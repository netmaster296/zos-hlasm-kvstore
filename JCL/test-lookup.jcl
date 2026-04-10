//KVTESTL  JOB (ACCT),'TEST LOOKUP OPS',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  TEST-LOOKUP.JCL - Functional test: LOOKUP, UPDATE, DELETE
//*
//*  Prerequisite: Run TEST-INSERT.JCL first to populate data.
//*
//*  Tests:
//*    1. Lookup existing key -> RC=0, value displayed
//*    2. Lookup non-existent key -> RC=4
//*    3. Update existing key -> RC=0
//*    4. Lookup updated key -> RC=0, new value displayed
//*    5. Delete existing key -> RC=0
//*    6. Lookup deleted key -> RC=4 (confirms deletion)
//*    7. Run STATS -> displays table occupancy report
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//*
//*-------------------------------------------------------------------
//*  Step 1: Lookup existing key (expect RC=0)
//*-------------------------------------------------------------------
//LKP1     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,ACCT001'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 2: Lookup key that doesn't exist (expect RC=4)
//*-------------------------------------------------------------------
//LKP2     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,NOEXIST9'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 3: Update ACCT001 with new balance (expect RC=0)
//*-------------------------------------------------------------------
//UPD1     EXEC PGM=KVMAIN,
//         PARM='UPDATE,ACCT001,BALANCE=22500'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 4: Verify update - lookup should show new value
//*-------------------------------------------------------------------
//LKP3     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,ACCT001'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 5: Delete ACCT002 (expect RC=0)
//*-------------------------------------------------------------------
//DEL1     EXEC PGM=KVMAIN,
//         PARM='DELETE,ACCT002'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 6: Lookup deleted key (expect RC=4)
//*-------------------------------------------------------------------
//LKP4     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,ACCT002'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 7: Table statistics (expect RC=0)
//*-------------------------------------------------------------------
//STATS    EXEC PGM=KVMAIN,
//         PARM='STATS'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//
