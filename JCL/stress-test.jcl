//KVSTRES  JOB (ACCT),'STRESS TEST KV',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  STRESS-TEST.JCL - Performance and capacity test
//*
//*  This job uses a REXX driver to:
//*    1. Allocate a fresh VSAM LDS
//*    2. Insert 500 records with generated keys
//*    3. Lookup all 500 records
//*    4. Report timing and collision statistics
//*    5. Test at ~50% load factor (500/1024 buckets)
//*
//*  This demonstrates the hash table's behavior under realistic
//*  load, including collision rates and probe chain lengths.
//*
//*  Prerequisite: Compile job must have been run successfully.
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//*
//*-------------------------------------------------------------------
//*  Step 1: Reset the VSAM LDS to empty state
//*-------------------------------------------------------------------
//RESET    EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.TABLE CLUSTER PURGE
  SET MAXCC = 0
  DEFINE CLUSTER -
         (NAME(&HLQ..KVSTORE.TABLE) -
          LINEAR -
          RECORDS(16) -
          CONTROLINTERVALSIZE(4096) -
          SHAREOPTIONS(2 3)) -
         DATA -
         (NAME(&HLQ..KVSTORE.TABLE.DATA))
/*
//*
//*-------------------------------------------------------------------
//*  Step 2: Run REXX stress test driver
//*  The REXX exec calls KVMAIN in a loop, generating keys like
//*  REC00001 through REC00500 with synthetic values.
//*-------------------------------------------------------------------
//STRESS   EXEC PGM=IKJEFT01,
//         PARM='KVDRIVER STRESS 500',
//         COND=(4,LT,RESET)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//SYSEXEC  DD DSN=&HLQ..KVSTORE.REXX,DISP=SHR
//*
//*-------------------------------------------------------------------
//*  Step 3: Final statistics
//*-------------------------------------------------------------------
//STATS    EXEC PGM=KVMAIN,
//         PARM='STATS',
//         COND=(4,LT,STRESS)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//
