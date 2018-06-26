#tag Module
Protected Module SQL
	#tag Method, Flags = &h1
		Protected Function AllPosts(postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts in the site limited to `postsPerPage`
		  ' with an offset calculated from the passed `currentPage`.
		  
		  using Xojo.Core
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  dim offset as Integer = (currentPage * postsPerPage) - postsPerPage
		  
		  if buildDrafts then
		    return "SELECT * FROM posts WHERE page=0 AND date <= " + Date.Now.SecondsFrom1970.ToText + _
		    " ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  else
		    return "SELECT * FROM posts WHERE page=0 AND draft=0 AND date <= " + Date.Now.SecondsFrom1970.ToText + _
		    " ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  end if
		  
		  
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function AllTags() As String
		  ' Returns the SQL query to return a RecordSet containing all tags in the database.
		  
		  return "SELECT * FROM tags;"
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function DaysWithPostsInMonthAndYear(year as Integer, month as Integer) As String
		  ' Returns the SQL statement to return a record set containing the days from the specified month and 
		  ' year that have posts.
		  ' Exclude pages.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT DISTINCT(date_day) AS day FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND page='0' AND homepage='0';"
		  else
		    return "SELECT DISTINCT(date_day) AS day FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND page='0' AND homepage='0 AND draft=0';"
		  end if
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function MonthsWithPostsInYear(year as Integer) As String
		  ' Returns the SQL statement to return a record set containing the months from the specified year
		  ' that have posts.
		  ' Exclude pages.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT DISTINCT(date_month) AS month FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND page='0' AND homepage='0';"
		  else
		    return "SELECT DISTINCT(date_month) AS month FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND page='0' AND homepage='0 AND draft=0';"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostCountForDay(year as Integer, month as Integer, day as Integer) As String
		  ' Returns the SQL statement to return the number of posts from the specified day, month and year.
		  ' Don't include pages.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND date_day='" + day.ToText + "' " +_
		    "AND page=0 AND homepage='0';"
		  else
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND date_day='" + day.ToText + "' " +_
		    "AND page=0 AND homepage='0' AND draft=0;"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostCountForMonth(year as Integer, month as Integer) As String
		  ' Returns the SQL statement to return the number of posts from the specified month and year.
		  ' Don't include pages.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND page=0 AND homepage='0';"
		  else
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND date_month='" + month.ToText + "' " +_
		    "AND page=0 AND homepage='0' AND draft=0;"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostCountForTag(tagName as String) As String
		  ' Returns the SQL statement to return the number of posts with the specified tag.
		  
		  return "SELECT COUNT(DISTINCT posts.id) As 'total' FROM posts INNER Join post_tags ON " +_
		  "post_tags.posts_id = posts.id INNER Join tags ON " +_
		  "tags.id = post_tags.tags_id WHERE tags.name IN ('" + tagName + "');"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostCountForYear(year as Integer) As String
		  ' Returns the SQL statement to return the number of posts from the specified year.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND page=0 AND homepage='0';"
		  else
		    return "SELECT COUNT(*) AS 'total' FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND page=0 AND homepage='0' AND draft=0;"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostsForDay(year as Integer, month as Integer, day as Integer, postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts from the specified day, month and year limited 
		  ' to `postsPerPage` with an offset calculated from the passed `currentPage`.
		  ' Don't include pages.
		  
		  dim offset as Integer = (currentPage * postsPerPage) - postsPerPage
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND date_month='" + month.ToText + "' " + _
		    "AND date_day='" + day.ToText + "' " + _
		    "AND page='0' AND homepage='0' " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  else
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND date_month='" + month.ToText + "' " + _
		    "AND date_day='" + day.ToText + "' " + _
		    "AND page='0' AND homepage='0' AND draft=0 " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostsForMonth(year as Integer, month as Integer, postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts from the specified month and year limited 
		  ' to `postsPerPage` with an offset calculated from the passed `currentPage`.
		  ' Don't include pages.
		  
		  dim offset As Integer = (currentPage * postsPerPage) - postsPerPage
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND date_month='" + month.ToText + "' " + _
		    "AND page='0' AND homepage='0' " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  else
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " + _
		    "AND date_month='" + month.ToText + "' " + _
		    "AND page='0' AND homepage='0' AND draft=0 " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostsForSection(section as String, postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts in the specified section limited to `postsPerPage`
		  ' with an offset calculated from the passed `currentPage`.
		  ' `section` should be dot-delimited (e.g: blog.personal for posts in content/blog/personal.
		  
		  using Xojo.Core
		  
		  dim offset as Integer = (currentPage * postsPerPage) - postsPerPage
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT * FROM posts WHERE section='" + section + "' " + _
		    "AND date <= " + Date.Now.SecondsFrom1970.ToText + " ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  else
		    return "SELECT * FROM posts WHERE section='" + section + "' AND draft=0 " + _
		    "AND date <= " + Date.Now.SecondsFrom1970.ToText + " ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  end if
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostsForTag(tagName as String, postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts with the specified tag limited to `postsPerPage`
		  ' with an offset calculated from the passed `currentPage`.
		  
		  dim offset As Integer = (currentPage * postsPerPage) - postsPerPage
		  
		  return "SELECT DISTINCT posts.* FROM posts INNER Join post_tags ON post_tags.posts_id " + _
		  "= posts.id INNER Join tags ON tags.id = post_tags.tags_id WHERE tags.name IN ('" + tagName + "') " + _
		  "ORDER BY posts.date DESC LIMIT " + postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function PostsForYear(year as Integer, postsPerPage as Integer, currentPage as Integer) As String
		  ' Returns the SQL statement to select all posts from the specified year limited to `postsPerPage`
		  ' with an offset calculated from the passed `currentPage`.
		  ' Don't include pages.
		  
		  dim offset as Integer = (currentPage * postsPerPage) - postsPerPage
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND page='0' AND homepage='0' " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  else
		    return "SELECT * FROM posts WHERE date_year='" + year.ToText + "' " +_
		    "AND page='0' AND homepage='0' AND draft=0 " +_
		    "ORDER BY date DESC LIMIT " + _
		    postsPerPage.ToText + " OFFSET " + offset.ToText + ";"
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function TagsForPost(postID as Integer) As String
		  ' Returns the SQL statement to select all tags for a particular post ID.
		  ' Kudos to http://lekkerlogic.com/2016/02/site-tags-using-mysql-many-to-many-tags-schema-database-design/
		  
		  return "SELECT tags.* FROM tags INNER JOIN post_tags ON tags.id = post_tags.tags_id " + _
		  "INNER JOIN posts ON post_tags.posts_id = posts.id WHERE posts.id = " + postID.ToText + ";"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function YearsWithPosts() As String
		  ' Returns the SQL statement to return a record set containing the years that have posts.
		  ' Exclude pages.
		  
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    return "SELECT DISTINCT(date_year) AS year FROM posts WHERE page='0' " + _
		    "AND homepage='0' ORDER BY date_year DESC;"
		  else
		    return "SELECT DISTINCT(date_year) AS year FROM posts WHERE page='0' " + _
		    "AND homepage='0' AND draft=0 ORDER BY date_year DESC;"
		  end if
		  
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
