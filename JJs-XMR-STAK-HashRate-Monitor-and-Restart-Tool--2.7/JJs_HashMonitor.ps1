﻿<#	
	.NOTES
	JJ's XMR-STAK HashRate Monitor and Restart Tool

	Based on an idea by @CircusDad on SupportXMR Chat
	His Vega Mining Guide for XMR --> https://vegamining.blogspot.com/

	How many times have you walked away for your computer to come back
	and notice that your hash rate dropped by HUNDREDS of hashes?
	How many times did you wake up to that scenario and wonder how long it had been going on?
	
	What happens when you go away for a few days with your lady/gentleman or some other sexy creature? 
	If you're like me you stress over your rig! It really kills the mood.
	
	How much potential profit have you lost to this terror!
	
	Well, I have felt your pain and decided to sit down and come up with a solution and here it is.
	How much is your peace of mind worth? If you find that your daily hash rate has now increased
	because this is no longer happening to you I'd appreciate it if you would consider a donation
	toward my hard work.
	
	No amount is too small! I'm not greedy! :-)
	
	XMR: 42JFvWHSSGCFUBSwTz522zXrkSuhZ6WnwCFv1mFaokDS7LqfT2MyHW32QbmH3CL94xjXUW8UsQMAj8NFDxaVR8Y1TNqY54W
	
	Purpose:	To monitor the STAK hashrate. If it drops below the threshold,
				the script is restarted.
				
	Features:	Script elevates itself if not run in Admin context.
				Logging
				The Radeon RX Vega driver is disabled/enabled.
				Any tools defined in the "Start Video Card Management Tools Definitions"
				section below are executed in order.
				Sets developer suggested environment variables
				Miner is started.
				Hash rate is monitored.
				If hash rate falls below the target as defined in the $hdiff variable (default is 100 hashes) 
				or STAK stops responding the miner process is killed.
				Script re-starts itself.

	*** IMPORTANT NOTE ***: If the script cannot kill the miner it will stop and wait for input.
							Otherwise it would invoke the miner over and over until the PC ran out of memory.
							In testing I have not seen it fail to kill the miner but I need to account for it.

	Requirements:	Elevated privilege (Run as Administrator)
					Enable Powershell scripts to run.

	Software Requirements:	XMR-STAK.EXE - Other STAK implementations are no longer supported.
							By default the script is configured to use the following software:
							
								XMR-STAK.EXE <-- Don't remark out this one. That would be bad.
								OverdriveNTool.exe
								nvidiasetp0state.exe
								nvidiaInspector.exe
							
							If you do not wish to use some or all of them just REMARK (use a #)
							out the lines below where they are defined in the USER VARIABLES SECTION.
							All executable files must be in the same folder as the script.
							
							
	Configuration: See below in the script for configuration items.

	Usage:	Powershell.exe -ExecutionPolicy Bypass -File JJs_HashMonitor.ps1
	
	Future enhancements under consideration:	SMS/email alerts
												Move settings out of the script and into a simple
												txt file to make it easier to manage them.

	Author:	TheJerichoJones at the Google Monster mail system

	Version: 2.7
	
	Release Date: 2017-11-19

	Copyright 2017, TheJerichoJones

	License: 
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License version 3 as 
	published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

######################################################################################
#  !! Scroll down to "USER VARIABLES SECTION"
#  !! There are variables you want to review/modify for your setup
######################################################################################
$ver = "2.7"
######################################################################################
#################DO NOT MODIFY ANYTHING IN  THE ELEVATION SECTION ####################
############################## BEGIN ELEVATION #######################################
# If you can't Elevate you're going to have a bad time...
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = "JJ's XMR-STAK HashRate Monitor and Restart Tool v $ver"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
   }
else
   {
   # We are not running "as Administrator" - so relaunch as administrator
   
   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   
   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";
   
   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess) | Out-Null;
   
   # Exit from the current, unelevated, process
   exit
   }
 
Clear-Host
Write-Host "Starting the Hash Monitor Script..."

Push-Location $PSScriptRoot
######################################################################################
################# DO NOT MODIFY ANYTHING IN THE ELEVATION SECTION ####################
################################ END ELEVATION #######################################


############# STATIC Variables - DO NOT CHANGE ##########################
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ScriptName = $MyInvocation.MyCommand.Name
$global:runDays = $null
$global:runHours = $null
$global:runMinutes = $null
$global:web = New-Object System.Net.WebClient
$global:maxhash = 0
$global:currHash = 0
$vidTool = @()
########## END STATIC Variables - MAKE NO CHANGES ABOVE THIS LINE #######

######################################################################################
########################### USER VARIABLES SECTION ###################################
######################################################################################

#########################################################################
# Set the REQUIRED variables for your Mining Configuration
#########################################################################
# Read this section carefully or you may end up overclocking your video
# card when you don't want to!! YOU HAVE BEEN WARNED
#########################################################################
$Logfile = "XMR_Restart_$(get-date -f yyyy-MM-dd).log"	# Log what we do, delete or REMARK if you don't want logging
$global:STAKexe = "XMR-STAK.EXE"	# The miner. Expects to be in same folder as this script
#$global:STAKcmdline = "--config config.txt"	# STAK arguments. Not required, REMARK out if not needed
$stakIP = '127.0.0.1'	# IP or hostname of the machine running STAK (ALWAYS LOCAL) Remote start/restart of the miner is UNSUPPORTED.
						# !! DON'T FORGET TO ENABLE THE WEBSERVER IN YOUR CONFIG FILE !!
$stakPort = '420'		# Port STAK is listening on

##### Start Video Card Management Tools Definitions
# These will be executed in order prior to the miner
# Create as many as needed
#### Vid Tool 1
$vidTool += 'OverdriveNTool.exe -p1XMR'	# Expects to be in same folder as this script
										# Delete or REMARK if you don't want use it
#### Vid Tool 2
$vidTool += 'nvidiasetp0state.exe'	# Expects to be in same folder as this script
									# Delete or REMARK if you don't want use it
#### Vid Tool 3
$vidTool += 'nvidiaInspector.exe -setBaseClockOffset:0,0,65 -setMemoryClockOffset:0,0,495 -setOverVoltage:0,0 -setPowerTarget:0,110 -setTempTarget:0,0,79'	# Expects to be in same folder as this script
																																							# Delete or REMARK if you don't want use it
##### End VidTools
$global:Url = "http://$stakIP`:$stakPort/api.json" # <-- DO NOT CHANGE THIS !!
#########################################################################
# Set drop trigger and startup timeout
#########################################################################
$hdiff = 100			# This is the drop in total hash rate where we
#						trigger a restart (Starting HASHRATE-$hdiff)
#
$timeout = 60			# (STARTUP ONLY)How long to wait for STAK to
#						return a hashrate before we fail out and
#						restart. There is no limiter on the number of restarts.
#						Press CTRL-C to EXIT
#						
$STAKstable = 120		# How long to wait for the hashrate to stabilize.
#
#########################################################################
###################### END USER DEFINED VARIABLES #######################
#################### MAKE NO CHANGES BELOW THIS LINE ####################

#####  BEGIN FUNCTIONS #####

function call-self 
{
	Start-Process -FilePath "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Powershell.exe" -ArgumentList $ScriptDir\$ScriptName -WorkingDirectory $ScriptDir -NoNewWindow
	EXIT
}

Function log-Write
{
	Param ([string]$logstring)
	If ($Logfile)
	{
		Add-content $Logfile -value $logstring
	}
}

function reset-VegaDriver {
	###################################
	##### Reset Video Card driver #####
	##### No error checking
	Write-host "Resetting Driver..."
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Running Driver Reset")
	$d = Get-PnpDevice| where {$_.friendlyname -like 'Radeon RX Vega'}
	$d  | Disable-PnpDevice -ErrorAction Ignore -Confirm:$false | Out-Null
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Video driver disabled")
	Write-host -fore Green "Video driver disabled"
	# Wait 5 seconds
	Start-Sleep -s 5
	$d  | Enable-PnpDevice -ErrorAction Ignore -Confirm:$false | Out-Null
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Video driver enabled")
	Write-host -fore Green "Video driver enabled"
	# Wait 5 seconds
	Start-Sleep -s 10
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Video driver reset completed")
}

Function Run-Tools ($app)
{
	foreach ($item in $app)
	{
		$prog = ($item -split "\s", 2)
		if (Test-Path $prog[0])
		{
			Write-host -fore Green "Starting " $prog[0]
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	Starting $item ")
			If ($prog[1]) {
				Start-Process -FilePath $prog[0] -ArgumentList $prog[1] | Out-Null
			}
			Else
			{
			Start-Process -FilePath $prog[0] | Out-Null
			}
		Start-Sleep -s 1
		}
		Else
		{
		Write-Host -fore Red $prog[0] NOT found. This is not fatal. Continuing...
		}
	}
}

function start-Mining
{
	#####  Start STAK  #####
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Starting STAK...")
	If (Test-Path $global:STAKexe)
	{
		Write-Host "Starting STAK..."
		If ($STAKcmdline)
		{
			Start-Process -FilePath $ScriptDir\$STAKexe -ArgumentList $STAKcmdline -WindowStyle Minimized
		}
		Else
		{
			Start-Process -FilePath $ScriptDir\$STAKexe
		}
	}
	Else
	{
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$global:STAKexe NOT FOUND.. EXITING")
		Clear-Host
		Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -fore Red "         $global:STAKexe NOT found. "
        Write-Host -fore Red "   Can't do much without the miner now can you!"
		Write-Host -fore Red "          Now exploding... buh bye!"
		Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -NoNewLine "Press any key to continue..."
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit
	}
}

Function chk-STAK($global:Url) {
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Waiting for STAK HTTP daemon to start")
	Write-host "Waiting for STAK HTTP daemon to start"
	
	$flag = "False"
	$web = New-Object System.Net.WebClient
    $TimeStart = Get-Date -format HH:mm:ss
    $timer = $timeout
	DO {
		Try {
			$result = $web.DownloadString($global:Url)
			$flag = "True"
			}
		Catch {
            $timeEnd = Get-Date -format HH:mm:ss
            $timeDiff = (New-TimeSpan -Start $timeStart -End (Get-Date -format HH:mm:ss)).TotalSeconds
            If ($timeDiff -lt $timeout)
			{
				Write-host -fore Red "STAK not ready... Waiting up to $timer seconds."
				Write-host -fore Red "Press CTRL-C to EXIT NOW"
			}
            If ($timeDiff -gt $timeout)
            {
                $timeout = 0
            }
			Start-Sleep -s 10
            $timer = $timer - 10
			}
		} While (($timeout -gt 1) -And ($flag -eq "False"))
	If ($flag -eq "True")
	{
		Clear-Host
		Write-host -fore Green "`n`n`n## STAK HTTP daemon has started ##`n"
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	STAK started successfully")
		
	}
	ElseIf ($flag -eq "False")
	{
		Clear-Host
		Write-host -fore Red "`n`n`n!! Timed out waiting for STAK HTTP daemon to start !!`n"
		start-sleep -s 10
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	Timed out waiting for STAK HTTP daemon to start")
		Start-Sleep -s 10
		#Write-Host -NoNewLine "Press any key to EXIT..."
		#$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		call-Self
		EXIT
	}
	Else
	{
		Clear-Host
		Write-host -fore Red "`n`n`n*** Unknown failure (Daemon failed to start?)... EXITING ***`n"
		start-sleep -s 10
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	Unknown failure starting STAK (Daemon failed to start?)")
		Start-Sleep -s 10
		#Write-Host -NoNewLine "Press any key to EXIT..."
		#$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		call-Self
		EXIT
	}
	
}

function starting-Hash
{
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Waiting for hash rate to stabilize")
	#Write-host -fore Green "Waiting for hash rate to stabilize"

    #$startTestHash = 1
    $currTestHash = 0

	# Wait x seconds for hash rate to stabilize
	while ($STAKstable -gt 0)
	{
		$data = $null
		$total = $null
		$data = @{}
		$total = @{}
		$rawdata = Invoke-WebRequest -UseBasicParsing -Uri $global:Url
		If ($rawdata)
		{
			$data = $rawdata | ConvertFrom-Json
			$rawtotal = ($data.hashrate).total
			$total = $rawtotal | foreach {$_}
			$currTestHash = $total[0]
			If (!$startTestHash)
			{
				$startTestHash = $currTestHash
			}	

			Clear-Host
			If ($currTestHash)
			{
				Write-host -fore Green "`n`nCurrent Hash Rate: $currTestHash H/s"
			}
			Write-host -fore Green "`n`nWaiting $STAKstable seconds for hashrate to stabilize."
			Write-host -fore Green "Press CTRL-C to EXIT NOW"
			Start-Sleep -s 1
			$STAKstable = $STAKstable - 1
		}
    }
    If (!$currTestHash)
	{
		Clear-Host
		Write-host -fore Green `nCould not get hashrate... restarting
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	Could not get hashrate... restarting")
		call-Self
		Exit
	}
	ElseIf ($currTestHash -gt $startTestHash)
	{
		$global:maxhash = $currTestHash
	}
	Else
    {
		$global:maxhash = $startTestHash
	}

    $global:currHash = $currTestHash
	$global:rTarget = ($global:maxhash - $hdiff)
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Hash rate stabilized")
	log-Write ("$timeStamp	Starting Hashrate: $global:maxhash H/s	Drop Target Hashrate: $global:rTarget H/s")
}

function current-Hash
{
	# Check our current hashrate against low target every 60 seconds
	Clear-Host
	Write-host -fore Green `nHash monitoring has begun.
	$timer = 0
	$runTime = 0
	$flag = "False"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Hash monitoring has begun")

	DO
	{
	Try {
		$data = $null
		$total = $null
		$data = @{}
		$total = @{}
		Write-host -fore Green `nQuerying STAK...this can take a minute.
		$rawdata = Invoke-WebRequest -UseBasicParsing -Uri $global:Url
		$flag = "True"
		}
	Catch
		{
			Clear-Host
			Write-host -fore Red "`nWe seem to have lost connectivity to STAK"
			Write-host -fore Red "Restarting in 10 seconds"
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	Restarting - Lost connectivity to STAK")
			Start-Sleep -s 10
			kill-Process ($STAKexe)
			$flag = "False"
			#Break
		}
		If ($flag -eq "False")
		{
			Break
		}
		$data = $rawdata | ConvertFrom-Json
		$rawtotal = ($data.hashrate).total
		$total = $rawtotal | foreach {$_}
		$global:currHash = $total[0]

		refresh-Screen
		
		Start-Sleep -s 60
		$timer = ($timer + 60)
		$runTime = ($timer)
	} while ($global:currHash -gt $global:rTarget)
	
	If ($flag -eq "True")
	{
		Clear-Host
		Write-host -fore Red "`n`nHash rate dropped from $global:maxhash H/s to $global:currHash H/s"
		Write-host -fore Red "`nRestarting in 10 seconds"
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		$tFormat =  get-RunTime ($runTime)
		log-Write ("$timeStamp	Restarting after $tFormat - Hash rate dropped from $global:maxhash H/s to $global:currHash H/s")
		Start-Sleep -s 10
	}
}

function kill-Process ($STAKexe) {
	try
	{
		$prog = ($STAKexe -split "\.", 2)
		$prog = $prog[0]
		# get STAK process
		$stakPROC = Get-Process $prog -ErrorAction SilentlyContinue
		if ($stakPROC) {
			# try gracefully first
			$stakPROC.CloseMainWindow() | Out-Null
			# kill after five seconds
			Sleep 5
			if (!$stakPROC.HasExited) {
				$stakPROC | Stop-Process -Force | Out-Null
			}
			if (!$stakPROC.HasExited) {
				Write-host -fore Red "Failed to kill the process $prog"
				Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
				Write-host -fore Red "`nover and over until the PC crashed."
				Write-host -fore Red "`n`n That would be very bad."
				Write-host -fore Red 'Press any key to EXIT...';
				$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	Failed to kill $prog")
				EXIT
			}
			Else
			{
				Write-host -fore Green "Successfully killed the process $prog"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	STAK closed successfully")
			}
		}
		Else
		{
			Write-host -fore Green "`n$prog process was not found"
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$prog process was not found")
		}
	}
	Catch
	{
			Write-host -fore Red "Failed to kill the process $prog"
			Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
			Write-host -fore Red "`nover and over until the PC crashed."
			Write-host -fore Red "`n`n That would be very bad."
			Write-host -fore Red 'Press any key to EXIT...';
			$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	Failed to kill $prog")
			EXIT
	}
}

Function refresh-Screen
{
	Clear-Host
	$tFormat =  get-RunTime ($runTime)
	Write-Host "=================================================="
	Write-host -fore Green `nStarting Hash Rate:	$global:maxhash H/s 
	Write-host -fore Green `nRestart Target Hash Rate:	$global:rTarget H/s
	Write-host -fore Green `nCurrent Hash Rate: $global:currHash H/s
	Write-host -fore Green `nMonitoring Uptime:	$tFormat `n
	Write-Host "=================================================="
}

function resize-Console ($Width,$Height)
{
	$targetWindow = (get-host).ui.rawui
	$windowSize = $targetWindow.windowsize
	$windowSize.height = $Height
	$windowSize.width = $Width
	$targetWindow.windowsize = $windowSize
	$bufferSize = $targetWindow.buffersize
	$bufferSize.height = $Height
	$bufferSize.width = $Width
	$targetWindow.buffersize = $bufferSize
}

function set-STAKVars
{
	Write-host -fore Green "Setting Env Variables for STAK"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Setting Env Variables for STAK")

	[System.Environment]::SetEnvironmentVariable("GPU_FORCE_64BIT_PTR", "1", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_HEAP_SIZE", "99", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_ALLOC_PERCENT", "99", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_SINGLE_ALLOC_PERCENT", "99", "User")
	
	Write-host -fore Green "Env Variables for STAK have been set"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	Env Variables for STAK have been set")
}

function get-RunTime ($sec)
{
	$myTimeSpan = (new-timespan -seconds $sec)
	If ($sec -ge 3600 -And $sec -lt 86400)
	{ 
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runHours Hours $global:runMinutes Min"
	}
	ElseIf ($sec -ge 86400)
	{
		$global:runDays = $myTimeSpan.Days
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runDays Days $global:runHours Hours $global:runMinutes Min"
	}
	Elseif ($sec -ge 60 -And $sec -lt 3600)
	{
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runMinutes Min"
	}
	Elseif ($sec -lt 60)
	{
		Return "Less than 1 minute"
	}
}

##### END FUNCTIONS #####

##### MAIN - or The Fun Starts Here #####
$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
log-Write ("$timeStamp	Script Started")

resize-Console 50 12

kill-Process ($STAKexe)

reset-VegaDriver ($devID)

If ($vidTool) # If $vidTool is defined
{
	Run-Tools ($vidTool) # Run your tools
}

set-STAKVars # Set suggested environment variables

start-Mining # Start mining software

chk-STAK($global:Url) # Wait for STAK to return a hash rate

starting-Hash # Get the starting hash rate

current-Hash # Gather the current hash rate every 60 seconds until it drops beneath the threshold

$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
log-Write ("$timeStamp	Script Ended")

call-Self # Restart the script

##### The End of the World as we know it #####
EXIT
