#tag Class
Protected Class StrikeScript
Inherits XojoScript
	#tag Event
		Function CompilerError(location As XojoScriptLocation, error As XojoScript.Errors, errorInfo As Dictionary) As Boolean
		  raise new Strike3.Error(CurrentMethodName, Str(location.line) + ", " + Str(location.character))
		  
		End Function
	#tag EndEvent

	#tag Event
		Sub RuntimeError(error As RuntimeException)
		  raise new Strike3.Error("Script error", error.message)
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Sub Constructor(file as FolderItem, c as Strike3.ScriptContext)
		  self.Source = FileContents(file)
		  self.Context = c
		End Sub
	#tag EndMethod


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Source"
			Visible=true
			Type="String"
			EditorType="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="State"
			Group="Behavior"
			Type="States"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
