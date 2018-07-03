#tag Class
Protected Class App
Inherits ConsoleApplication
	#tag Event
		Function Run(args() as String) As Integer
		  using CommandLine
		  
		  ' #if DebugBuild and TargetMacOS
		  ' try
		  ' Strike3.Build(SpecialFolder.UserHome.Child("Repos").Child("garrypettet.com").Child("src"))
		  ' return 0
		  ' catch
		  ' return -1
		  ' end try
		  ' #endif
		  
		  ' Remove the executable path (always passed as the first argument).
		  args.Remove(0)
		  
		  ' If no arguments passed we'll just print the basic usage and exit.
		  if args.Ubound < 0 then Help.BasicUsage
		  
		  ' Work out which command to run
		  select case args(0).Lowercase
		  case "build"
		    command = CommandType.build
		  case "create"
		    command = CommandType.create
		  case "help"
		    command = CommandType.help
		  case "set"
		    command = CommandType.set
		  case "version"
		    command = CommandType.version
		  else
		    PrintError("[" + args(0) + "] is an unknown command.")
		  end select
		  
		  ' Remove the command from the arguments array.
		  args.Remove(0)
		  
		  ' Parse the command options.
		  ParseCommandOptions(args)
		  
		  ' Run the command.
		  RunCommand()
		  
		  exception err as Strike3.Error
		    PrintError(err.message)
		End Function
	#tag EndEvent

	#tag Event
		Function UnhandledException(error As RuntimeException) As Boolean
		  CommandLine.PrintError("An unhandled error occurred: " + error.message)
		End Function
	#tag EndEvent


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
