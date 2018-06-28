#tag Class
Protected Class StrikeScript
Inherits XojoScript
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


End Class
#tag EndClass
