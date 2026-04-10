//KVRUNALL JOB (ACCT),'FULL KV PIPELINE',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  RUN-ALL.JCL - Master pipeline: allocate, compile, test, cleanup
//*
//*  Chains all build/test steps into a single job with proper
//*  condition code checking. Each phase depends on the prior
//*  phase succeeding.
//*
//*  Pipeline:
//*    Phase 1: Allocate VSAM LDS           (ALLOC)
//*    Phase 2: Assemble + Link-Edit        (ASMx + LKED)
//*    Phase 3: Functional tests            (TEST1-TEST3)
//*    Phase 4: Statistics report            (STATS)
//*
//*  This job demonstrates multi-step JCL orchestration with
//*  conditional execution, symbolic parameters, and proper
//*  error propagation.
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//  SET SRCPDS=&SYSUID..KVSTORE.ASM
//  SET MACLIB=&SYSUID..KVSTORE.MACLIB
//*
//*=================================================================
//*  PHASE 1: ALLOCATE VSAM LDS
//*=================================================================
//*
//ALLOC1   EXEC PGM=IDCAMS
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
//*=================================================================
//*  PHASE 2: ASSEMBLE ALL MODULES
//*=================================================================
//*
//*--- Assemble KVHASH ---
//ASM1     EXEC PGM=ASMA90,
//         PARM='OBJECT,NODECK,XREF(SHORT),RENT',
//         COND=(4,LT,ALLOC1)
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.MODGEN,DISP=SHR
//         DD DSN=&MACLIB,DISP=SHR
//SYSIN    DD DSN=&SRCPDS(KVHASH),DISP=SHR
//SYSLIN   DD DSN=&&OBJ1,DISP=(NEW,PASS),
//         UNIT=SYSDA,SPACE=(CYL,(1,1)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPRINT DD SYSOUT=*
//*
//*--- Assemble KVTABLE ---
//ASM2     EXEC PGM=ASMA90,
//         PARM='OBJECT,NODECK,XREF(SHORT),RENT',
//         COND=(5,LT,ASM1)
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.MODGEN,DISP=SHR
//         DD DSN=&MACLIB,DISP=SHR
//SYSIN    DD DSN=&SRCPDS(KVTABLE),DISP=SHR
//SYSLIN   DD DSN=&&OBJ2,DISP=(NEW,PASS),
//         UNIT=SYSDA,SPACE=(CYL,(1,1)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPRINT DD SYSOUT=*
//*
//*--- Assemble KVVSAM ---
//ASM3     EXEC PGM=ASMA90,
//         PARM='OBJECT,NODECK,XREF(SHORT),RENT',
//         COND=(5,LT,ASM2)
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.MODGEN,DISP=SHR
//         DD DSN=&MACLIB,DISP=SHR
//SYSIN    DD DSN=&SRCPDS(KVVSAM),DISP=SHR
//SYSLIN   DD DSN=&&OBJ3,DISP=(NEW,PASS),
//         UNIT=SYSDA,SPACE=(CYL,(1,1)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPRINT DD SYSOUT=*
//*
//*--- Assemble KVMAIN ---
//ASM4     EXEC PGM=ASMA90,
//         PARM='OBJECT,NODECK,XREF(SHORT),RENT',
//         COND=(5,LT,ASM3)
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.MODGEN,DISP=SHR
//         DD DSN=&MACLIB,DISP=SHR
//SYSIN    DD DSN=&SRCPDS(KVMAIN),DISP=SHR
//SYSLIN   DD DSN=&&OBJ4,DISP=(NEW,PASS),
//         UNIT=SYSDA,SPACE=(CYL,(1,1)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPRINT DD SYSOUT=*
//*
//*=================================================================
//*  PHASE 2b: LINK-EDIT
//*=================================================================
//*
//LKED     EXEC PGM=IEWL,
//         PARM='LIST,MAP,XREF,RENT,AMODE=31,RMODE=24',
//         COND=(5,LT)
//SYSLIB   DD DSN=SYS1.CSSLIB,DISP=SHR
//         DD DSN=CEE.SCEELKED,DISP=SHR
//OBJ1     DD DSN=&&OBJ1,DISP=(OLD,DELETE)
//OBJ2     DD DSN=&&OBJ2,DISP=(OLD,DELETE)
//OBJ3     DD DSN=&&OBJ3,DISP=(OLD,DELETE)
//OBJ4     DD DSN=&&OBJ4,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&HLQ..KVSTORE.LOAD(KVMAIN),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPRINT DD SYSOUT=*
//SYSLIN   DD *
  INCLUDE OBJ1
  INCLUDE OBJ2
  INCLUDE OBJ3
  INCLUDE OBJ4
  ENTRY KVMAIN
  NAME KVMAIN(R)
/*
//*
//*=================================================================
//*  PHASE 3: FUNCTIONAL TESTS
//*=================================================================
//*
//*--- Test INSERT ---
//TEST1    EXEC PGM=KVMAIN,
//         PARM='INSERT,TESTKEY1,TESTVALUE001',
//         COND=(4,LT,LKED)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*--- Test LOOKUP ---
//TEST2    EXEC PGM=KVMAIN,
//         PARM='LOOKUP,TESTKEY1',
//         COND=(4,LT,TEST1)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*--- Test DELETE ---
//TEST3    EXEC PGM=KVMAIN,
//         PARM='DELETE,TESTKEY1',
//         COND=(4,LT,TEST2)
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//*
//*=================================================================
//*  PHASE 4: FINAL STATISTICS
//*=================================================================
//*
//STATS    EXEC PGM=KVMAIN,
//         PARM='STATS'
//STEPLIB  DD DSN=&HLQ..KVSTORE.LOAD,DISP=SHR
//KVLDS    DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//
