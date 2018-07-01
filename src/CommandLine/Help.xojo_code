#tag Class
Protected Class Help
	#tag Method, Flags = &h0
		Shared Sub BasicUsage()
		  ' Print out a message explaining the basic usage of the tool.
		  
		  using Rainbow
		  
		  Print "Strike3 is a flexible static site generator built with love by Garry Pettet and written in Xojo."
		  Print ""
		  Print "The main command is " + Colourise("strike3", Colour.magenta) + ", used to build your Strike3 site."
		  Print "Complete documentation can be found at " + _
		  Colourise("https://github.com/gkjpettet/strike3", Colour.magenta) + "."
		  Print ""
		  Print "Usage:"
		  Print "  strike3 [command]"
		  Print ""
		  Print "Available commands:"
		  Print "  create       Create new content for your site"
		  Print "  build        Build your site"
		  Print "  version      Print the version number of Strike3"
		  Print ""
		  Print "Use " + Colourise("strike3 help [command]", Colour.magenta) + _
		  " for detailed help on a specific command."
		  
		  Quit(0)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Sub Build()
		  ' Print out a message explaining how the build command works.
		  
		  using Rainbow
		  
		  Print "The " + Colourise("build", Colour.magenta) + " command is simple but powerful. " +_
		  "It's where all the magic happens."
		  Print "Running " + Colourise("strike3 build", Colour.magenta) + " from a site root will render " + _
		  "all of your content"
		  Print "(using the current theme) into the " + Colourise("/public", Colour.magenta) + " folder. " + _
		  "If an error occurs,"
		  Print "Strike3 will advise how to fix it. All that's left to do after that"
		  Print "is to publish the contents of " + Colourise("/public", Colour.magenta) + _
		  " to your web server."
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Sub CommandRequiresSiteRoot()
		  using Rainbow
		  
		  dim message() as String
		  
		  message.Append("Unable to locate config file. Perhaps you need to create a new site?")
		  message.Append("Run " + Colourise("strike3 help create", Colour.magenta) + " for details.")
		  
		  PrintError(message)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Sub Create()
		  ' Prints out the help message for the `create` command.
		  
		  using Rainbow
		  
		  Print "The create command can do one of two things:"
		  Print "1). Create a new site"
		  Print "2). Create a new theme template"
		  Print "Usage:"
		  Print "strike3 create site [site-name]"
		  Print "strike3 create theme [theme-name]"
		  
		  Quit(0)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Sub Version()
		  ' Prints out the help message for the 'version' command.
		  
		  Print "All software has a version number. For Strike3 it's " + Strike3.Version
		  
		  Quit(0)
		End Sub
	#tag EndMethod


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
			Name="Name"
			Visible=true
			Group="ID"
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
End Class
#tag EndClass
