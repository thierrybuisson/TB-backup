# http://9to5it.com/powershell-logging-function-library/
function LogWrite{
	Param (
		[Parameter(Mandatory=$true)]
		[string]$message,

		[Parameter(Mandatory=$false)]
		[string]$component,
		
		#The severity (1- Information, 2- Warning, 3 - Error, 4 - Info, 5 - Debug)
		[parameter(Mandatory=$false)] 
		[ValidateRange(1,5)] 
		[Single]$severity =1,
				
		[Parameter(Mandatory=$false)]
		[string]$color,
		
		[Parameter(Mandatory=$false)]
		[bool]$nonewline=$false,
		
		[Parameter(Mandatory=$false)]
		[bool]$logsession=$false
      
	)
		
	$Acolor=@("magenta","white","yellow","red","green","gray")
	if ($color){
		$scolor=$color
	}else{$scolor=$Acolor[$severity]}
	
	if (!$nonewline){write-host -ForegroundColor $scolor " . $message"	}
	else{write-host -ForegroundColor $scolor " $message" -nonewline}

}


function LogTrace(){
	Param (
		[Parameter(Mandatory=$true)]
		[string]$message,
		
		[Parameter(Mandatory=$true)]
		[string]$logfile,

		[Parameter(Mandatory=$false)]
		[string]$component,
		
		#The severity (1- Information, 2- Warning, 3 - Error, 4 - Info, 5 - Debug) 
		[parameter(Mandatory=$false)] 
		[ValidateRange(1,5)] 
		[Single]$severity =1

	)

		$Aseverity=@("","information","warning","error","debug","verbose")
	
		#Obtain UTC offset 
		$DateTime = New-Object -ComObject WbemScripting.SWbemDateTime  
		$DateTime.SetVarDate($(Get-Date)) 
		$UtcValue = $DateTime.Value 
		$UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21) 
		
		$type= $Aseverity[$severity]
		
		# $component = $myinvocation.mycommand.name
		# $component= [System.Diagnostics.Process]::GetCurrentProcess()
		$thread = $([Threading.Thread]::CurrentThread.ManagedThreadId)
		# $thread = $gGuid
		# $file = $MyInvocation.MyCommand.Definition
		$file=$PSCommandPath
		#Create the line to be logged (cmtrace mode)
		$LogLine =  "<![LOG[$message]LOG]!>" +` 
				"<time=`"$(Get-Date -Format HH:mm:ss.mmmm)$($UtcOffset)`" " +` 
				"date=`"$(Get-Date -Format M-d-yyyy)`" " +` 
				"component=`"$component`" " +`  
				"context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +` 
				"type=`"$severity`" " +` 
				"thread=`"$thread`" " +` 
				"file=`"$file`">" 

		$LogLine | Out-File -Append -Encoding UTF8 -FilePath $logfile -Force


}
