//KVCOMP   JOB (ACCT),'COMPILE KV STORE',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  COMPILE.JCL - Assemble and Link-Edit the KV Store modules
//*
//*  This job assembles all four CSECTS (KVHASH, KVTABLE, KVVSAM,
//*  KVMAIN) using the High-Level Assembler, then link-edits them
//*  into a single load module.
//*
//*  Build order respects dependencies:
//*    Step 1: Assemble KVHASH   (no dependencies)
//*    Step 2: Assemble KVTABLE  (depends on KVENTRY macro)
//*    Step 3: Assemble KVVSAM   (depends on KVENTRY macro)
//*    Step 4: Assemble KVMAIN   (depends on KVENTRY macro)
//*    Step 5: Link-Edit all OBJ modules into one load module
//*
//*  COND= on each step ensures we skip link-edit if any
//*  assembly fails (RC > 4 = error; RC=4 = warning, acceptable).
//*
//*  Symbolic parameters:
//*    &HLQ    - High-level qualifier for output datasets
//*    &SRCPDS - PDS containing ASM source members
//*    &MACLIB - PDS containing custom macros (KVENTRY, etc.)
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//  SET SRCPDS=&SYSUID..KVSTORE.ASM
//  SET MACLIB=&SYSUID..KVSTORE.MACLIB
//*
//*-------------------------------------------------------------------
//*  Step 1: Assemble KVHASH - Hash function module
//*-------------------------------------------------------------------
//ASM1     EXEC PGM=ASMA90,
//         PARM='OBJECT,NODECK,XREF(SHORT),RENT'
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
//*-------------------------------------------------------------------
//*  Step 2: Assemble KVTABLE - Table management module
//*  COND: Skip if KVHASH assembly failed (RC > 4)
//*-------------------------------------------------------------------
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
//*-------------------------------------------------------------------
//*  Step 3: Assemble KVVSAM - VSAM persistence module
//*-------------------------------------------------------------------
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
//*-------------------------------------------------------------------
//*  Step 4: Assemble KVMAIN - Main driver module
//*-------------------------------------------------------------------
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
//*-------------------------------------------------------------------
//*  Step 5: Link-Edit all object modules
//*
//*  ENTRY KVMAIN  - Program entry point
//*  AMODE 31      - 31-bit addressing mode
//*  RMODE 24      - Reside below 16M line (for JCL PARM access)
//*  RENT          - Reentrant attribute
//*  LIST,MAP,XREF - Full diagnostics in SYSPRINT
//*
//*  COND: Skip if any assembly step failed
//*-------------------------------------------------------------------
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
//
