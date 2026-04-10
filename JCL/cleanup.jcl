//KVCLEAN  JOB (ACCT),'CLEANUP KV STORE',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  CLEANUP.JCL - Remove all KV Store datasets
//*
//*  Deletes VSAM cluster, load library, and work datasets.
//*  Uses IF/THEN/ELSE for conditional processing - each delete
//*  is independent so one failure doesn't prevent others.
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//*
//*-------------------------------------------------------------------
//*  Step 1: Delete VSAM LDS cluster
//*-------------------------------------------------------------------
//DELVSAM  EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.TABLE -
         CLUSTER -
         PURGE
  IF LASTCC = 8 THEN -
    DO
      SET MAXCC = 0
    END
/*
//*
//*-------------------------------------------------------------------
//*  Step 2: Delete load library
//*-------------------------------------------------------------------
//DELLOAD  EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.LOAD NONVSAM PURGE
  IF LASTCC = 8 THEN -
    DO
      SET MAXCC = 0
    END
/*
//*
//*-------------------------------------------------------------------
//*  Step 3: Delete ASM source PDS (if uploaded)
//*-------------------------------------------------------------------
//DELASM   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.ASM NONVSAM PURGE
  IF LASTCC = 8 THEN -
    DO
      SET MAXCC = 0
    END
/*
//*
//*-------------------------------------------------------------------
//*  Step 4: Delete macro library (if uploaded)
//*-------------------------------------------------------------------
//DELMAC   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.MACLIB NONVSAM PURGE
  IF LASTCC = 8 THEN -
    DO
      SET MAXCC = 0
    END
/*
//*
//*-------------------------------------------------------------------
//*  Step 5: Delete REXX library (if uploaded)
//*-------------------------------------------------------------------
//DELREXX  EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.REXX NONVSAM PURGE
  IF LASTCC = 8 THEN -
    DO
      SET MAXCC = 0
    END
/*
//*
//*-------------------------------------------------------------------
//*  Verification: List remaining datasets (should be empty)
//*-------------------------------------------------------------------
//VERIFY   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  LISTCAT LVL(&HLQ..KVSTORE) ALL
  IF LASTCC = 4 THEN -
    DO
      SET MAXCC = 0
    END
/*
//
