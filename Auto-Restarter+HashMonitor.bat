:: ###########################################################################
:: #                                                                         #
:: #                     'Auto-Restarter + HashMonitor'                      #
:: #                              Version 1.0                                #
:: #                        created by Natizyskunk.                          #
:: #                              It include:                                #
:: #          -Auto-Restarter v1.0 by Natizyskunk (no actaul repo).          #
:: #   -HashMonitor v2.7 by JerichoJones (https://github.com/JerichoJones).  #
:: #                                                                         #
:: ###########################################################################
::
:: ############################################
:: # PLEASE, Open the README.txt file first!  #
:: ############################################

@echo off
SETLOCAL EnableExtensions
set MINER1=Run_HashMonitor.cmd
set MINER2=powershell.exe
set EXE=xmr-stak.exe

echo #############################################################################
echo #############################################################################
echo ##                                                                         ##
echo ##                       'Auto-Restarter+HashMonitor'                      ##
echo ##                         created by Natizyskunk                          ##
echo ##                              It include:                                ##
echo ##          -Auto-Restarter v1.0 by Natizyskunk (no actaul repo)           ##
echo ##   -HashMonitor v2.7 by JerichoJones (https://github.com/JerichoJones)   ##
echo ##                                                                         ##
echo #############################################################################
echo #############################################################################
echo.
echo.


:STARTMINER1
echo launching XMR-STAK v2 Miner and HashMonitor v2.7
@echo off
start /B %MINER1%

:TESTMINER2
echo waiting 3 seconds before testing MINER2 and EXE
TIMEOUT /T 3 /NOBREAK
echo.
echo testing MINER2
FOR /F %%x IN ('tasklist /NH /FI "IMAGENAME eq %MINER2%"') DO IF %%x == %MINER2% goto TESTEXE
goto ProcessNotFoundMINER2

:TESTEXE
echo testing EXE
FOR /F %%x IN ('tasklist /NH /FI "IMAGENAME eq %EXE%"') DO IF %%x == %EXE% goto ProcessFoundEXE
goto ProcessNotFoundEXE




:ProcessNotFoundMINER2
echo %MINER2% is not running
echo restarting the HashMonitor and the miner.
start closeXmrStak
goto STARTMINER1

:ProcessFoundEXE
echo %MINER2% and %EXE% are running
goto TESTMINER2

:ProcessNotFoundEXE
echo %MINER2% is runing but %EXE% is not running
echo restarting the miner
start closePowershell
goto STARTMINER1

:END
echo Finished!