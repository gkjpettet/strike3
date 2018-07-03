#tag Module
Protected Module Markdown
	#tag Method, Flags = &h21
		Private Sub Initialise()
		  ' Initialises the required properties.
		  
		  if initialised then return
		  
		  myShell = new Shell
		  myShell.TimeOut = 10000
		  
		  try
		    #if TargetMacOS
		      pandoc = App.ExecutableFile.Parent.Child("pandoc")
		    #elseif TargetWindows
		      pandoc = App.ExecutableFile.Parent.Child("pandoc.exe")
		    #endif
		  catch
		    raise new Error(CurrentMethodName, "Unable to get a reference to the pandoc binary.")
		  end try
		  
		  initialised = True
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function Render(md as String) As String
		  ' Converts the passed Markdown to HTML using the bundled pandoc binary.
		  
		  const QUOTE as String = """"
		  
		  dim name as String
		  dim tempFile as FolderItem
		  dim tout as TextOutputStream
		  
		  if not initialised then Initialise()
		  
		  ' Write the Markdown to a temporary file
		  name = "pandoc" + Str(Microseconds) + ".md"
		  tempFile = SpecialFolder.Temporary.Child(name)
		  try
		    tout = TextOutputStream.Create(tempFile)
		    tout.Write(md)
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to write Markdown to temporary file.")
		  end try
		  
		  ' Use pandoc to transform the contents of our temporary file to HTML
		  dim command as String = pandoc.ShellPath + " " + QUOTE + tempFile.ShellPath + QUOTE + " " + OPTIONS
		  myShell.Execute(command)
		  
		  ' Delete the temporary file
		  tempFile.Delete()
		  
		  ' Return the result
		  try
		    return DefineEncoding(myShell.Result, Encodings.UTF8)
		  catch
		    return ""
		  end try
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private initialised As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21
		Private myShell As Shell
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pandoc As FolderItem
	#tag EndProperty


	#tag Constant, Name = OPTIONS, Type = String, Dynamic = False, Default = \"-f markdown", Scope = Private
	#tag EndConstant


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
End Module
#tag EndModule
