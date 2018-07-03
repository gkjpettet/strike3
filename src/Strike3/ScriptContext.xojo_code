#tag Class
Protected Class ScriptContext
	#tag Method, Flags = &h0
		Sub CopyFromRootToPublic(from as String)
		  ' Used to copy a file or folder from a location within the site's root to the public root.
		  ' `from` is the path relative to the Strike3 root of the asset to copy.
		  
		  ' So, say we have the following Strike3 structure:
		  '  config.json
		  '  [content]
		  '  [scripts]
		  '  site.data
		  '  [storage]
		  '  [themes]
		  '  [misc]
		  '    - file1.html
		  '    - file2.html
		  
		  ' We can use this method to copy `file1.html` to the public root with the following syntax:
		  ' CopyFromRootToPublic("misc/file1.html")
		  ' We can also use this method to copy the entire [misc] folder to the public root like this:
		  ' CopyFromRootToPublic("misc")
		  
		  dim fromParts() as Text
		  dim source as FolderItem = Strike3.root
		  
		  ' Remove any leading and trailing slashes.
		  if from.Left(1) = "/" or from.Left(1) = "\" then from = from.Right(from.Len - 1)
		  if from.Right(1) = "/" or from.Right(1) = "\" then from = from.Left(from.Len - 1)
		  
		  ' Split `from` into its children.
		  #if TargetWindows
		    fromParts = from.ToText.Split("\")
		  #else
		    fromParts = from.ToText.Split("/")
		  #endif
		  
		  for each part as Text in fromParts
		    try
		      source = source.Child(part)
		    catch
		      raise new Error(CurrentMethodName, "Invalid source path.")
		    end try
		  next part
		  if source = Nil or not source.Exists then raise new Error(CurrentMethodName, "Invalid source path.")
		  if source = Nil or not source.Exists then raise new Error(CurrentMethodName, "Invalid source path.")
		  
		  ' Attempt the copy.
		  try
		    source.CopyTo(Strike3.publicFolder)
		  catch
		    raise new Error(CurrentMethodName, "Unable to copy source (" + source.NativePath + ") to the public folder.")
		  end try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub CopyFromThemeToPublic(from as String)
		  ' Used to copy a file or folder from a location within the current theme folder to the public root.
		  ' `from` is the path relative to the current theme root of the asset to copy.
		  
		  ' So, say we have the following theme structure:
		  ' [CURRENT THEME]
		  '  - [assets]
		  '  - [layouts]
		  '  - [favicons]
		  '    - favicon.ico
		  '  - [misc]
		  '    - cool.md
		  
		  ' We can use this method to copy `favicon.ico` to the public root with the following syntax:
		  ' CopyFromThemeToPublic("favicons/favicon.ico")
		  ' We can also use this method to copy the entire [misc] folder to the public root like this:
		  ' CopyFromThemeToPublic("misc")
		  
		  dim fromParts() as Text
		  dim source as FolderItem = Strike3.theme
		  
		  ' Remove any leading and trailing slashes.
		  if from.Left(1) = "/" or from.Left(1) = "\" then from = from.Right(from.Len - 1)
		  if from.Right(1) = "/" or from.Right(1) = "\" then from = from.Left(from.Len - 1)
		  
		  ' Split `from` into its children.
		  #if TargetWindows
		    fromParts = from.ToText.Split("\")
		  #else
		    fromParts = from.ToText.Split("/")
		  #endif
		  
		  for each part as Text in fromParts
		    try
		      source = source.Child(part)
		    catch
		      raise new Error(CurrentMethodName, "Invalid source path.")
		    end try
		  next part
		  if source = Nil or not source.Exists then raise new Error(CurrentMethodName, "Invalid source path.")
		  if source = Nil or not source.Exists then raise new Error(CurrentMethodName, "Invalid source path.")
		  
		  ' Attempt the copy.
		  try
		    source.CopyTo(Strike3.publicFolder)
		  catch
		    raise new Error(CurrentMethodName, "Unable to copy source (" + source.NativePath + ") to the public folder.")
		  end try
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
			InitialValue="-2147483648"
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
			InitialValue="0"
			Type="Integer"
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
