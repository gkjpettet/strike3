#tag Module
Protected Module Sorting
	#tag Method, Flags = &h1
		Protected Function CompareRSSItemDates(r1 as Strike3.RSSItem, r2 as Strike3.RSSItem) As Integer
		  ' Used to sort RSS items by their publication date.
		  
		  if r1.pubDate.SecondsFrom1970 < r2.pubDate.SecondsFrom1970 then return 1
		  if r1.pubDate.SecondsFrom1970 > r2.pubDate.SecondsFrom1970 then return -1
		  return 0
		End Function
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
End Module
#tag EndModule
