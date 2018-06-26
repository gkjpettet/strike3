#tag Class
Protected Class Post
	#tag Method, Flags = &h0
		Sub Constructor()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(file as FolderItem)
		  self.file = file
		  self.data = new Xojo.Core.Dictionary
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Function FromRecordSet(rs as RecordSet) As Strike3.Post
		  ' Return the passed RecordSet as a Post class.
		  ' For performance, we assume that rs <> Nil and is pointing to a valid database table row.
		  
		  dim p as new Strike3.Post
		  dim tagsRecordSet as RecordSet
		  
		  p.contents = rs.Field("contents").StringValue
		  try
		    p.data = Xojo.Data.ParseJSON(rs.Field("data").StringValue.ToText)
		  catch
		    p.data = Nil
		  end try
		  p.date = new Xojo.Core.Date(rs.Field("date").IntegerValue, Xojo.Core.TimeZone.Current)
		  p.draft = rs.Field("draft").BooleanValue
		  p.hash = rs.Field("hash").StringValue
		  p.homepage = rs.Field("homepage").BooleanValue
		  p.lastUpdated = new Xojo.Core.Date(rs.Field("last_updated").IntegerValue, Xojo.Core.TimeZone.Current)
		  p.page = rs.Field("page").BooleanValue
		  p.sourcePath = rs.Field("source_path").StringValue
		  p.section = rs.Field("section").StringValue
		  p.slug = rs.Field("slug").StringValue
		  p.title = rs.Field("title").StringValue
		  p.url = rs.Field("url").StringValue
		  
		  ' Tags
		  tagsRecordSet = db.SQLSelect(SQL.TagsForPost(rs.Field("id").IntegerValue))
		  if tagsRecordSet = Nil or tagsRecordSet.EOF then return p ' no tags
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  while not tagsRecordSet.EOF
		    p.tags.Append(tagsRecordSet.Field("name").StringValue)
		    tagsRecordSet.MoveNext()
		  wend
		  
		  return p
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Summary(chars as Integer = 55) As String
		  ' Returns the specified number of characters of the rendered content with any HTML stripped.
		  
		  dim s as String = StripHTMLTags(contents)
		  
		  if s.Len > chars then s = s.Left(chars)
		  
		  return s + "..."
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function TagsAsHTML() As String
		  ' Returns this post's tags as an unordered HTML list.
		  
		  const QUOTE = """"
		  
		  dim html, tag as String
		  
		  if tags.Ubound < 0 then return ""
		  
		  html = "<ul class=" + QUOTE + "tags" + QUOTE + ">"
		  
		  for each tag in tags
		    
		    html = html + "<li><a href=" + QUOTE + Permalink(Strike3.publicFolder.Child("tag").Child(tag)) + _
		    QUOTE + ">" + tag + "</a></li>"
		    
		  next tag
		  
		  return html + "</ul>"
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		#tag Note
			This is the rendered Markdown for this file having run it through the Markdown parser.
		#tag EndNote
		contents As String
	#tag EndProperty

	#tag Property, Flags = &h0
		#tag Note
			Any data specified In this file's frontmatter as a Dictionary.
			We specifically exclude the following values (as they are stored as dedicated properties in the Post):
			- title
			- date
			- draft
			- slug
		#tag EndNote
		data As Xojo.Core.Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0
		date As Xojo.Core.Date
	#tag EndProperty

	#tag Property, Flags = &h0
		draft As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		file As FolderItem
	#tag EndProperty

	#tag Property, Flags = &h0
		hash As String
	#tag EndProperty

	#tag Property, Flags = &h0
		homepage As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		lastUpdated As Xojo.Core.Date
	#tag EndProperty

	#tag Property, Flags = &h0
		markdown As String
	#tag EndProperty

	#tag Property, Flags = &h0
		page As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		#tag Note
			The section this post is within. Subsections are separated by a "."
			www.example.com/blog/first-post.html           section = blog
			www.example.com/blog/personal/test.html        section = blog.personal
			www.example.com/about                        } section = about
			www.example.com/about/index.html             } section = about
		#tag EndNote
		section As String
	#tag EndProperty

	#tag Property, Flags = &h0
		slug As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sourcePath As String
	#tag EndProperty

	#tag Property, Flags = &h0
		tags() As String
	#tag EndProperty

	#tag Property, Flags = &h0
		title As String
	#tag EndProperty

	#tag Property, Flags = &h0
		#tag Note
			The URL for this Node.
			Only relevant for terminal nodes, not section nodes.
		#tag EndNote
		url As String
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="contents"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="draft"
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="hash"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="homepage"
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
		#tag EndViewProperty
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
			Name="markdown"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="page"
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="section"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="slug"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sourcePath"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="title"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="url"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
