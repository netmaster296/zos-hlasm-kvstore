//KVALLOC  JOB (ACCT),'ALLOC KV STORE',
//         CLASS=A,MSGCLASS=H,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID
//*
//*********************************************************************
//*  ALLOCATE.JCL - Define VSAM Linear Data Set for KV Store
//*
//*  This job uses IDCAMS to define a VSAM Linear Data Set (LDS)
//*  that serves as the persistent backing store for the hash table.
//*
//*  VSAM LDS was chosen over KSDS/ESDS because:
//*  - LDS provides raw byte-addressable storage (no VSAM CI/CA
//*    overhead for key management - we handle our own hashing)
//*  - Maps directly to virtual storage via Data-In-Virtual (DIV)
//*  - Gives us full control over the on-disk layout
//*  - Ideal for memory-mapped data structures
//*
//*  Table geometry:
//*    1024 buckets * 64 bytes/entry = 65,536 bytes = 64 KB
//*    CONTROLINTERVALSIZE aligned to 4096 (1 page per CI)
//*    RECORDS = 16 CIs (65536 / 4096)
//*
//*  Symbolic parameters (override via PROC or SET):
//*    &HLQ   - High-level qualifier (default: user's ID)
//*    &TBLSZ - Table size in CIs (default: 16 = 64K)
//*
//*********************************************************************
//*
//  SET HLQ=&SYSUID
//  SET TBLSZ=16
//*
//*-------------------------------------------------------------------
//*  Step 1: Delete existing cluster (if any)
//*  Condition: RC=8 is acceptable (cluster doesn't exist yet)
//*-------------------------------------------------------------------
//DELETE   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE &HLQ..KVSTORE.TABLE -
         CLUSTER -
         PURGE
  SET MAXCC = 0
/*
//*
//*-------------------------------------------------------------------
//*  Step 2: Define new VSAM Linear Data Set
//*
//*  Key parameters explained:
//*    LINEAR         - No VSAM key/index, raw byte storage
//*    RECORDS(16)    - 16 control intervals (= 64K with 4K CI)
//*    CISZ(4096)     - 4K CI = one 4K page, optimal for DIV mapping
//*    SHAREOPTIONS(2 3) - Cross-region: read sharing ok
//*                        Cross-system: normal sharing
//*    FREESPACE not applicable for LDS (no key-based splits)
//*
//*-------------------------------------------------------------------
//DEFINE   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DEFINE CLUSTER -
         (NAME(&HLQ..KVSTORE.TABLE) -
          LINEAR -
          RECORDS(&TBLSZ) -
          CONTROLINTERVALSIZE(4096) -
          SHAREOPTIONS(2 3)) -
         DATA -
         (NAME(&HLQ..KVSTORE.TABLE.DATA))
  IF LASTCC = 0 THEN -
    DO
      LISTCAT ENT(&HLQ..KVSTORE.TABLE) ALL
    END
  ELSE -
    DO
      SET MAXCC = 12
    END
/*
//*
//*-------------------------------------------------------------------
//*  Step 3: Initialize the LDS with binary zeros
//*  This ensures a clean hash table on first use
//*-------------------------------------------------------------------
//INIT     EXEC PGM=IDCAMS
//INFILE   DD DSN=&HLQ..KVSTORE.TABLE,DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  REPRO INFILE(INFILE) -
        OUTFILE(INFILE) -
        REPLACE
  SET MAXCC = 0
/*
//
