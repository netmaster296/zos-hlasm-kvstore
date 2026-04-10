//KVTESTI  JOB (ACCT),'TEST INSERT OPS',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  TEST-INSERT.JCL - Functional test: INSERT operations
//*
//*  Tests:
//*    1. Insert a single key-value pair
//*    2. Insert multiple distinct keys
//*    3. Attempt duplicate insert (expect RC=12)
//*    4. Verify via LOOKUP after insert
//*
//*  Expected results:
//*    Steps 1-3: RC=0 (successful inserts)
//*    Step 4:    RC=12 (duplicate key rejected)
//*    Step 5-7:  RC=0 (lookups confirm inserts)
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//*
//*-------------------------------------------------------------------
//*  Step 1: Insert first record - basic account
//*-------------------------------------------------------------------
//INS1     EXEC PGM=KVMAIN,
//         PARM='INSERT,ACCT001,BALANCE=15000'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 2: Insert second record - different key
//*-------------------------------------------------------------------
//INS2     EXEC PGM=KVMAIN,
//         PARM='INSERT,ACCT002,BALANCE=27500',
//         COND=(4,LT,INS1)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 3: Insert third record - string value
//*-------------------------------------------------------------------
//INS3     EXEC PGM=KVMAIN,
//         PARM='INSERT,CONFIG01,LOG_LEVEL=DEBUG',
//         COND=(4,LT,INS2)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 4: Attempt duplicate insert (should fail RC=12)
//*  Note: COND=(0,NE) means run regardless of prior steps
//*-------------------------------------------------------------------
//INSDUP   EXEC PGM=KVMAIN,
//         PARM='INSERT,ACCT001,BALANCE=99999'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 5: Verify ACCT001 exists via LOOKUP
//*-------------------------------------------------------------------
//LKP1     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,ACCT001'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 6: Verify ACCT002 exists via LOOKUP
//*-------------------------------------------------------------------
//LKP2     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,ACCT002'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*-------------------------------------------------------------------
//*  Step 7: Verify CONFIG01 exists
//*-------------------------------------------------------------------
//LKP3     EXEC PGM=KVMAIN,
//         PARM='LOOKUP,CONFIG01'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//
