/* REXX ****************************************************************
*  KVDRIVER - Interactive and batch test driver for KV Store
*
*  This REXX exec provides two modes:
*    INTERACTIVE - Prompts for operations (INSERT/LOOKUP/etc.)
*    STRESS n    - Batch insert + lookup of n records with timing
*
*  Usage:
*    TSO KVDRIVER                     (interactive mode)
*    TSO KVDRIVER STRESS 500          (stress test, 500 records)
*    TSO KVDRIVER STRESS 1000         (stress test, 1000 records)
*
*  The exec calls KVMAIN via TSO CALL, passing operation parameters.
*  It captures return codes and reports results.
*
*  This demonstrates cross-language integration (REXX calling HLASM)
*  which is standard practice in production z/OS environments.
*
*  Author:  Portfolio Project
*  Date:    2024
*
******************************************************************* */

PARSE ARG mode count .

IF mode = '' THEN mode = 'INTERACTIVE'
mode = TRANSLATE(mode)    /* Uppercase */

SELECT
  WHEN mode = 'INTERACTIVE' THEN CALL RunInteractive
  WHEN mode = 'STRESS'      THEN CALL RunStress count
  OTHERWISE DO
    SAY 'KVDRIVER: Unknown mode "'mode'"'
    SAY 'Usage: KVDRIVER [INTERACTIVE | STRESS n]'
    EXIT 16
  END
END

EXIT 0

/* -----------------------------------------------------------------
   RunInteractive - Prompt-driven operation execution
   ----------------------------------------------------------------- */
RunInteractive:
  SAY '============================================='
  SAY '  z/OS HLASM Key-Value Store - Test Console  '
  SAY '============================================='
  SAY ''
  SAY 'Commands:'
  SAY '  INSERT key value  - Store a key-value pair'
  SAY '  LOOKUP key        - Retrieve a value by key'
  SAY '  UPDATE key value  - Update an existing entry'
  SAY '  DELETE key        - Remove an entry'
  SAY '  STATS             - Show table statistics'
  SAY '  QUIT              - Exit'
  SAY ''

  DO FOREVER
    SAY ''
    CALL CHAROUT , 'KV> '
    PARSE PULL cmdline
    cmdline = STRIP(cmdline)

    IF cmdline = '' THEN ITERATE

    PARSE VAR cmdline cmd key value
    cmd = TRANSLATE(cmd)

    SELECT
      WHEN cmd = 'QUIT' | cmd = 'EXIT' | cmd = 'Q' THEN DO
        SAY 'Goodbye.'
        LEAVE
      END
      WHEN cmd = 'INSERT' THEN DO
        IF key = '' | value = '' THEN DO
          SAY 'Error: INSERT requires key and value'
          ITERATE
        END
        parm = 'INSERT,'key','value
        CALL ExecuteOp parm
      END
      WHEN cmd = 'LOOKUP' THEN DO
        IF key = '' THEN DO
          SAY 'Error: LOOKUP requires a key'
          ITERATE
        END
        parm = 'LOOKUP,'key
        CALL ExecuteOp parm
      END
      WHEN cmd = 'UPDATE' THEN DO
        IF key = '' | value = '' THEN DO
          SAY 'Error: UPDATE requires key and value'
          ITERATE
        END
        parm = 'UPDATE,'key','value
        CALL ExecuteOp parm
      END
      WHEN cmd = 'DELETE' THEN DO
        IF key = '' THEN DO
          SAY 'Error: DELETE requires a key'
          ITERATE
        END
        parm = 'DELETE,'key
        CALL ExecuteOp parm
      END
      WHEN cmd = 'STATS' THEN DO
        parm = 'STATS'
        CALL ExecuteOp parm
      END
      OTHERWISE DO
        SAY 'Unknown command: 'cmd
        SAY 'Valid: INSERT LOOKUP UPDATE DELETE STATS QUIT'
      END
    END
  END
RETURN

/* -----------------------------------------------------------------
   RunStress - Batch performance test
   Insert <count> records, then look them all up, report timing.
   ----------------------------------------------------------------- */
RunStress:
  PARSE ARG numrecs

  IF numrecs = '' | \DATATYPE(numrecs, 'W') THEN DO
    SAY 'KVDRIVER STRESS: Please specify record count'
    SAY 'Usage: KVDRIVER STRESS 500'
    EXIT 16
  END

  numrecs = numrecs + 0   /* Force numeric */

  SAY '============================================='
  SAY '  KV Store Stress Test - 'numrecs' records'
  SAY '============================================='
  SAY ''

  /* --- Phase 1: INSERT records --- */
  SAY 'Phase 1: Inserting 'numrecs' records...'
  ins_ok = 0
  ins_fail = 0
  ins_start = TIME('E')    /* Elapsed timer start */

  DO i = 1 TO numrecs
    key = 'REC'RIGHT(i, 5, '0')         /* REC00001 .. REC99999 */
    val = 'VAL-'RIGHT(i, 5, '0')'-DATA' /* VAL-00001-DATA       */
    parm = 'INSERT,'key','val

    CALL ExecuteOp parm
    IF RESULT = 0 THEN ins_ok = ins_ok + 1
                  ELSE ins_fail = ins_fail + 1

    /* Progress indicator every 100 records */
    IF i // 100 = 0 THEN
      SAY '  ... inserted 'i' of 'numrecs
  END

  ins_elapsed = TIME('E')

  SAY ''
  SAY 'INSERT phase complete:'
  SAY '  Successful: 'ins_ok
  SAY '  Failed:     'ins_fail
  SAY '  Elapsed:    'FORMAT(ins_elapsed,,2)' seconds'
  IF ins_ok > 0 THEN
    SAY '  Avg/record: 'FORMAT(ins_elapsed/ins_ok,,4)' seconds'
  SAY ''

  /* --- Phase 2: LOOKUP all records --- */
  SAY 'Phase 2: Looking up 'numrecs' records...'
  lkp_ok = 0
  lkp_fail = 0
  lkp_start = TIME('R')    /* Reset elapsed timer */

  DO i = 1 TO numrecs
    key = 'REC'RIGHT(i, 5, '0')
    parm = 'LOOKUP,'key

    CALL ExecuteOp parm
    IF RESULT = 0 THEN lkp_ok = lkp_ok + 1
                  ELSE lkp_fail = lkp_fail + 1

    IF i // 100 = 0 THEN
      SAY '  ... looked up 'i' of 'numrecs
  END

  lkp_elapsed = TIME('E')

  SAY ''
  SAY 'LOOKUP phase complete:'
  SAY '  Found:      'lkp_ok
  SAY '  Not found:  'lkp_fail
  SAY '  Elapsed:    'FORMAT(lkp_elapsed,,2)' seconds'
  IF lkp_ok > 0 THEN
    SAY '  Avg/lookup: 'FORMAT(lkp_elapsed/lkp_ok,,4)' seconds'
  SAY ''

  /* --- Phase 3: STATS --- */
  SAY 'Phase 3: Table statistics'
  CALL ExecuteOp 'STATS'

  /* --- Summary --- */
  SAY ''
  SAY '============================================='
  SAY '  Stress Test Summary'
  SAY '============================================='
  SAY '  Records:          'numrecs
  SAY '  Table buckets:    1024'
  SAY '  Load factor:      'FORMAT(numrecs/1024*100,,1)'%'
  SAY '  Insert success:   'ins_ok'/'numrecs
  SAY '  Lookup success:   'lkp_ok'/'numrecs
  SAY '  Total time:       'FORMAT(ins_elapsed+lkp_elapsed,,2)' sec'
  SAY '============================================='

RETURN

/* -----------------------------------------------------------------
   ExecuteOp - Call KVMAIN with the given PARM string
   Returns the program's return code.
   ----------------------------------------------------------------- */
ExecuteOp:
  PARSE ARG opParm

  /* Build and execute TSO CALL command */
  ADDRESS TSO "CALL *(KVMAIN) '"opParm"'"

  call_rc = RC

  /* Interpret return code */
  SELECT
    WHEN call_rc = 0  THEN msg = 'OK'
    WHEN call_rc = 4  THEN msg = 'Key not found'
    WHEN call_rc = 8  THEN msg = 'Table full'
    WHEN call_rc = 12 THEN msg = 'Duplicate key'
    WHEN call_rc = 16 THEN msg = 'Invalid parm'
    WHEN call_rc = 20 THEN msg = 'VSAM I/O error'
    OTHERWISE              msg = 'Unknown RC='call_rc
  END

  SAY '  ['opParm'] -> RC='call_rc' ('msg')'

RETURN call_rc
