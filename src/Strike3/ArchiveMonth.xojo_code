#tag Class
Protected Class ArchiveMonth
	#tag Method, Flags = &h0
		Sub Constructor(month as Integer)
		  self.value = month
		  
		  select case month
		  case 1
		    self.shortName = "Jan"
		    self.longName = "January"
		  case 2
		    self.shortName = "Feb"
		    self.longName = "February"
		  case 3
		    self.shortName = "Mar"
		    self.longName = "March"
		  case 4
		    self.shortName = "Apr"
		    self.longName = "April"
		  case 5
		    self.shortName = "May"
		    self.longName = "May"
		  case 6
		    self.shortName = "Jun"
		    self.longName = "June"
		  case 7
		    self.shortName = "Jul"
		    self.longName = "July"
		  case 8
		    self.shortName = "Aug"
		    self.longName = "August"
		  case 9
		    self.shortName = "Sep"
		    self.longName = "September"
		  case 10
		    self.shortName = "Oct"
		    self.longName = "October"
		  case 11
		    self.shortName = "Nov"
		    self.longName = "November"
		  case 12
		    self.shortName = "Dec"
		    self.longName = "December"
		  else
		    raise new Error(CurrentMethodName, "Invalid month value: " + Str(month) + ".")
		  end select
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		days() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		longName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		shortName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		value As Integer
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
			Name="longName"
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
			Name="shortName"
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
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="value"
			Group="Behavior"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
