#tag Class
Protected Class RSSItem
	#tag Method, Flags = &h0
		Sub Constructor(title as String, link as String, pubDate as Xojo.Core.Date, description as String)
		  self.title = title
		  self.link = link
		  self.pubDate = pubDate
		  self.description = description
		  
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		description As String
	#tag EndProperty

	#tag Property, Flags = &h0
		link As String
	#tag EndProperty

	#tag Property, Flags = &h0
		pubDate As Xojo.Core.Date
	#tag EndProperty

	#tag Property, Flags = &h0
		title As String
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="description"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
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
			Name="link"
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
	#tag EndViewBehavior
End Class
#tag EndClass
