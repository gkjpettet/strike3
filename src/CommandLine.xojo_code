#tag Module
Protected Module CommandLine
	#tag Method, Flags = &h1
		Protected Sub ParseCommandOptions(options() as String)
		  ' Having parsed which command to run and ensuring we have a valid command,
		  ' does further parsing of the command's options (if required).
		  
		  select case command
		  case CommandType.build
		    ' Handle any flags
		    SetFlags(options)
		  case CommandType.create
		    ' We need to parse more options for this command
		    ParseCreate(options)
		  case CommandType.help
		    RunHelp(options)
		  case CommandType.version
		    PrintVersion()
		  else
		    ' This shouldn't happen...
		    PrintError("Unknown command to run.")
		  end select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ParseCreate(options() as String)
		  ' Parses the required subcommand and options for the `create` command.
		  ' Valid syntax is:
		  ' create site [site-name]
		  ' create theme [theme-name]
		  
		  if options.Ubound < 1 then PrintError("Insufficient number of arguments provided.")
		  
		  ' Get the subcommand.
		  select case options(0).Lowercase
		  case "site", "theme"
		    subcommand = options(0).Lowercase
		  else
		    PrintError("[" + options(0) + "] is an invalid subcommand or type.")
		  end select
		  
		  ' Get the name of the item to create.
		  name = options(1).Lowercase
		  
		  ' Handle any flags by parsing what's left after removing the subcommand/section and the name.
		  options.Remove(0)
		  options.Remove(0)
		  SetFlags(options)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub PrintError(errMessages() as String)
		  ' Prints the following array of strings to the console and then quits.
		  
		  using Rainbow
		  
		  dim message as String
		  
		  if errMessages.Ubound < 0 then Quit(-1)
		  
		  for each message in errMessages
		    Print Colourise("Error: ", Colour.red) + " " + message
		  next message
		  
		  Quit(-1)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub PrintError(errMessage as String)
		  ' Prints the passed error message to the console and quits.
		  
		  using Rainbow
		  
		  Print Colourise("Error: " + errMessage, Colour.red)
		  
		  Quit(-1)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub PrintVersion()
		  ' Prints out the current version of the tool.
		  
		  Print("Strike3, a static site generator. Version: " + Strike3.Version)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub RunBuild()
		  ' Build the site.
		  
		  using Rainbow
		  
		  dim startTime, endTime as Double
		  dim t as Integer
		  dim site as FolderItem
		  
		  #if DebugBuild
		    site = SpecialFolder.Desktop.Child("blog")
		  #else
		    ' Set the site root to the current working directory
		    site = SpecialFolder.CurrentWorkingDirectory
		  #endif
		  
		  try
		    startTime = Microseconds
		    Strike3.Build(site)
		    endTime = Microseconds - startTime
		    t = endTime/1000
		    Print Colourise("Success ✔︎", Colour.green)
		    Print("Site built in " + Str(t) + " ms")
		    Quit(0)
		  catch e as Strike3.Error
		    Print Colourise("An error occurred whilst building. " + e.where + ". " + e.message, Colour.Red)
		    Quit(-1)
		  end try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub RunCommand()
		  ' Having parsed the command and subcommand to run as well as having set any flags, we are now ready
		  ' to actually do something.
		  ' The `help` and `version` commands are handled elsewhere.
		  
		  select case command
		  case CommandType.build
		    RunBuild()
		  case CommandType.create
		    select case subcommand
		    case "site"
		      RunCreate(name)
		    case "theme"
		      RunCreateTheme(name)
		    end select
		  end select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub RunCreate(siteName as String)
		  using Rainbow
		  
		  dim cwd, site as FolderItem
		  
		  ' Set the site root to the current working directory.
		  #if DebugBuild
		    cwd = SpecialFolder.Desktop ' Just use the desktop when debugging.
		  #else
		    cwd = SpecialFolder.CurrentWorkingDirectory
		  #endif
		  
		  try
		    site = Strike3.CreateSite(siteName, cwd, True)
		    
		    Print Colourise("Success ✔︎", Colour.green)
		    Print "Your new site was created at " + Strike3.root.NativePath
		    Print "A single post and a simple page have been created in " + Colourise("/content", Colour.magenta) + _
		    ". A simple default theme called "
		    Print "'" + Strike3.DEFAULT_THEME_NAME + "' has been created for you in " + _
		    Colourise("/themes", Colour.magenta) + "."
		    Print "Feel free to create your own with " + Colourise("strike3 create theme [name]", Colour.magenta) + "."
		    Quit(0)
		  catch e As Strike3.Error
		    Print Colourise("Something went wrong when creating your site. " + e.message + _
		    " (" + e.where + ").", Colour.Red)
		    Quit(-1)
		  end try
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub RunCreateTheme(themeName as String)
		  using Rainbow
		  
		  ' Set the site root to the current working directory.
		  #if DebugBuild
		    Strike3.Initialise(SpecialFolder.Desktop.Child("blog"))
		  #else
		    Strike3.Initialise(SpecialFolder.CurrentWorkingDirectory)
		  #endif
		  
		  try
		    Strike3.CreateTheme(themeName)
		    Print Colourise("Success ✔︎", Colour.green)
		    Print "Your new theme " + Colourise(themeName, Colour.magenta) + " was created at " + _
		    Strike3.root.Child("themes").NativePath
		    Quit(0)
		  catch e As Strike3.Error
		    Print Colourise("Something went wrong when creating your new theme. " + e.message + _
		    " (" + e.where + ").", Colour.Red)
		    Quit(-1)
		  end try
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub RunHelp(options() as String)
		  ' Displays help on the specified command.
		  
		  ' Check if no options passed. In which case, print basic usage and exit
		  if options.Ubound < 0 then Help.BasicUsage
		  
		  ' Make sure no more than one option is passed
		  if (options.Ubound > 0) then 
		    PrintError("Too many options passed to help command")
		  end if
		  
		  ' Catch the edge case of maebh help help`
		  if options(0).Lowercase = "help" then 
		    PrintError("Too many options passed to help command")
		  end if
		  
		  ' Which command does the user want help with?
		  select case options(0).Lowercase
		  case "build"
		    Help.Build
		  case "create"
		    Help.Create
		  case "version"
		    Help.Version
		  else ' Unknown command
		    PrintError("[" + options(0) + "] is an unknown command.")
		  end select
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetFlags(flags() as String)
		  ' Strike3 will (eventually) accept a number of flags at the end of the arguments string. This method 
		  ' takes an array containing flags and sets them accordingly.
		  
		  #pragma Warning "TODO"
		  
		  if flags.Ubound < 0 then return
		  
		  
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h1
		Protected command As CommandType
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected name As String
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected subcommand As String
	#tag EndProperty


	#tag Enum, Name = CommandType, Flags = &h0
		build
		  create
		  help
		  version
		  undefined
		set
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="name"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule
