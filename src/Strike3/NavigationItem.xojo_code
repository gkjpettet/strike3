#tag Class
Protected Class NavigationItem
	#tag Method, Flags = &h0
		Sub Constructor(title as String, url as String, cssClass as String, parent as Strike3.NavigationItem=Nil)
		  self.title = title
		  self.url = url
		  self.cssClass = cssClass
		  self.parent = parent
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		children(-1) As Strike3.NavigationItem
	#tag EndProperty

	#tag Property, Flags = &h0
		cssClass As String
	#tag EndProperty

	#tag Property, Flags = &h0
		parent As Strike3.NavigationItem
	#tag EndProperty

	#tag Property, Flags = &h0
		title As String
	#tag EndProperty

	#tag Property, Flags = &h0
		url As String
	#tag EndProperty


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
		#tag ViewProperty
			Name="cssClass"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
