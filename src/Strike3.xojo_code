#tag Module
Protected Module Strike3
	#tag Method, Flags = &h1
		Protected Sub Build(site as FolderItem)
		  ' Builds the site.
		  ' We store the built HTML in root/public.
		  
		  ' Initialise. This will check for site validity amongst other things.
		  try
		    Initialise(site)
		  catch err as Error
		    raise err
		  end try
		  
		  ' Set the public folder.
		  publicFolder = root.Child("public")
		  if publicFolder.Exists then publicFolder.ReallyDelete()
		  
		  ' Load the site's configuration.
		  LoadConfig()
		  
		  ' Set the theme.
		  SetTheme()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ConnectToDatabase()
		  ' Attempts to connect to this site's SQLite database.
		  ' Assumes that Strike3.root has been set to a valid site folder.
		  
		  try
		    db = new SQLiteDatabase
		    dbFile = root.Child("site.data")
		    db.DatabaseFile = dbFile
		    if not db.Connect() then 
		      raise new Error(CurrentMethodName, "Unable to connect to the site's database.")
		    end if
		  catch
		    raise new Error(CurrentMethodName, "Unable to connect to the site's database. Is it missing?")
		  end try
		  
		  ' Enable foreign key support in SQLite
		  db.SQLExecute("PRAGMA FOREIGN_KEYS = ON;")
		  if db.Error then raise new Error(CurrentMethodName, "Unable to enable foreign key support.")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CopyFileOrFolder(source as FolderItem, destination as FolderItem) As Boolean
		  ' Copies `source` to `destination`.
		  ' Returns True if OK, False if an error occurs.
		  
		  dim newFolder, sourceItem as FolderItem
		  dim i, sourceCount as Integer
		  
		  if source.Directory then ' Copying a folder.
		    
		    newFolder = destination.Child(source.Name)
		    newFolder.CreateAsFolder()
		    if not newFolder.Exists or not newFolder.Directory then return False
		    
		    sourceCount = source.Count
		    for i = 1 To sourceCount
		      sourceItem = source.TrueItem(i)
		      if sourceItem = Nil then return False
		      if not CopyFileOrFolder(sourceItem, newFolder) then return False
		    next i
		    
		  else ' Copying a file.
		    source.CopyFileTo(destination)
		    if source.LastErrorCode <> FolderItem.NoError then return False
		  end if
		  
		  return True
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub CreateDatabase()
		  ' Every site has a SQLite database stored in the root named `site.data`.
		  ' The database is populated/altered during a site build.
		  ' This method creates an empty database in the site's root.
		  
		  dim tin as TextInputStream
		  dim sql as String
		  dim schema as FolderItem
		  
		  ' Create the actual file on disk that will contain the SQLite database.
		  dbFile = root.Child("site.data")
		  db = new SQLiteDatabase
		  db.DatabaseFile = dbFile
		  if not db.CreateDatabaseFile() then
		    raise new Error(CurrentMethodName, "Unable to create the database file.")
		  end if
		  
		  ' Get the database schema file from within the app's Resources folder.
		  schema = Xojo.IO.SpecialFolder.GetResource("database_schema.sql").ToClassic
		  
		  ' Get the contents of the database schema file as a String.
		  try
		    tin = TextInputStream.Open(schema)
		    sql = tin.ReadAll()
		    tin.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to read `database_schema.sql` from the `resources` folder.")
		  end try
		  
		  ' Run the schema to construct an empty database.
		  db.SQLExecute(sql)
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function CreateSite(name as String, where as FolderItem) As FolderItem
		  ' Create a new site named `name` within the parent folder `where`.
		  ' Returns a reference to the newly created site folder.
		  
		  using Xojo.Data
		  
		  dim configFile as FolderItem
		  dim tout as TextOutputStream
		  dim jsonDict as new Xojo.Core.Dictionary
		  
		  ' Create the site root folder
		  root = where.Child(name)
		  if root.Exists then
		    raise new Error(CurrentMethodName, "Cannot create a site named `" + name + "` - a folder with " + _
		    "that name already exists")
		  else
		    root.CreateAsFolder()
		    if root.LastErrorCode <> FolderItem.NoError then
		      raise new Error(CurrentMethodName, "Unable to create the root folder for the site.")
		    end if
		  end if
		  
		  ' Create the required folders (content, storage, themes)
		  root.Child("content").CreateAsFolder()
		  if root.LastErrorCode <> FolderItem.NoError then
		    raise new Error(CurrentMethodName, "Unable to create the `content` folder for the site.")
		  end if
		  root.Child("storage").CreateAsFolder()
		  if root.LastErrorCode <> FolderItem.NoError then
		    raise new Error(CurrentMethodName, "Unable to create the `storage` folder for the site.")
		  end if
		  root.Child("themes").CreateAsFolder()
		  if root.LastErrorCode <> FolderItem.NoError then
		    raise new Error(CurrentMethodName, "Unable to create the `theme` folder for the site.")
		  end if
		  
		  ' Create the config file
		  configFile = root.Child("config.json")
		  try
		    tout = TextOutputStream.Create(configFile)
		  catch
		    raise new Error(CurrentMethodName, "Unable to either create the config.json file.")
		  end try
		  
		  ' Create the default JSON for the config file.
		  try
		    jsonDict.Value("archives") = DEFAULT_ARCHIVES
		    jsonDict.Value("baseURL") = DEFAULT_BASE_URL
		    jsonDict.Value("description") = DEFAULT_DESCRIPTION
		    jsonDict.Value("postsPerPage") = DEFAULT_POSTS_PER_PAGE
		    jsonDict.Value("theme") = DEFAULT_THEME_NAME
		    jsonDict.Value("title") = name
		    tout.Write(GenerateJSON(jsonDict))
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to write to the config.json file.")
		  end try
		  
		  ' Create the site's database
		  CreateDatabase()
		  
		  ' Done.
		  return root
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub CreateTheme(name as String)
		  ' Creates a new blank theme within the `root` folder.
		  ' Assumes that `root` is a valid site root folder.
		  
		  Using Xojo.Data
		  
		  dim themes, newTheme, f As FolderItem
		  dim jsonDict as new Xojo.Core.Dictionary
		  dim tout as TextOutputStream
		  
		  ' Get the parent `themes` folder (create if needed).
		  themes = root.Child("themes")
		  if not themes.Exists then themes.CreateAsFolder()
		  
		  ' Theme root.
		  newTheme = themes.Child(name)
		  if newTheme.Exists then raise new Error(CurrentMethodName, "A theme named [" + name + "] already exists.")
		  newTheme.CreateAsFolder()
		  if newTheme.LastErrorCode <> FolderItem.NoError then
		    raise new Error(CurrentMethodName, "Unable To create theme folder.")
		  end if
		  
		  ' theme.json
		  f = newTheme.Child("theme.json")
		  Try
		    tout = TextOutputStream.Create(f)
		    jsonDict.Value("name") = name
		    jsonDict.Value("description") = "My new theme"
		    jsonDict.Value("minVersion") = Version
		    tout.Write(GenerateJSON(jsonDict))
		    tout.Close()
		  catch
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to write to the theme.json file.")
		  end try
		  
		  ' assets/
		  f = newTheme.Child("assets")
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the assets folder.")
		  end if
		  
		  ' layouts/
		  f = newTheme.Child("layouts")
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layout folder.")
		  end if
		  
		  ' layouts/partials/
		  try
		    f = newTheme.Child("layouts").Child("partials")
		  catch
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to find the `layouts` folder.")
		  end try
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/partials folder.")
		  end if
		  
		  ' layouts/404.html
		  try
		    f = Xojo.IO.SpecialFolder.GetResource("404.html").ToClassic
		  catch
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, _
		    "Unable to retrieve the 404 boilerplate from the app's resources folder.")
		  end try
		  if not CopyFileOrFolder(f, newTheme.Child("layouts")) then
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/404.html file.")
		  end if
		  
		  ' layouts/archive.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("archive.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/archive.html file.")
		  End Try
		  
		  ' layouts/archives.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("archives.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/archives.html file.")
		  end try
		  
		  ' layouts/home.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("home.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/home.html file.")
		  end try
		  
		  ' layouts/page.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("page.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/page.html file.")
		  end try
		  
		  ' layouts/post.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("post.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/post.html file.")
		  end try
		  
		  ' layouts/list.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("list.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/list.html file.")
		  end try
		  
		  ' layouts/tags.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("tags.html"))
		    tout.Close()
		  catch e
		    newTheme.ReallyDelete()
		    raise new Error(CurrentMethodName, "Unable to create the layouts/tags.html file.")
		  end try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub Initialise(siteRoot as FolderItem)
		  ' Assigns an existing site folder to Strike3 and prepares the engine.
		  
		  ' Check that siteRoot is a valid Strike3 site.
		  if not ValidateSite(siteRoot) then
		    raise new Error(CurrentMethodName, _
		    "Unable to initialise Strike3 to the specified site root as it is invalid.")
		  end if
		  root = siteRoot
		  
		  ' Connect to the site's database.
		  ConnectToDatabase()
		  
		  config = new Xojo.Core.Dictionary
		  baseURL = DEFAULT_BASE_URL
		  theme = Nil
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub LoadConfig()
		  ' Read the site's config.json file into our `config` Dictionary.
		  
		  using Xojo.Data
		  
		  dim jsonText as Text
		  dim tin as TextInputStream
		  
		  ' Open the config file
		  try
		    tin = TextInputStream.Open(root.Child("config.json"))
		    jsonText = tin.ReadAll().ToText
		    tin.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to read the contents of config.json.")
		  End Try
		  
		  ' Parse the config JSON into our `config` dictionary
		  try
		    config = ParseJSON(jsonText)
		  catch
		    raise new Error(CurrentMethodName, "The contents of config.json is not valid JSON.")
		  end try
		  
		  ' #########################
		  ' ### Add default values
		  ' #########################
		  ' Site title
		  if not config.HasKey("title") then config.Value("title") = DEFAULT_SITE_TITLE
		  
		  ' Base URL
		  if not config.HasKey("baseURL") or config.Value("baseURL") = "" then
		    config.Value("baseURL") = DEFAULT_BASE_URL
		  end if
		  baseURL = config.Value("baseURL")
		  baseURL = if(baseURL.Right(1) <> "/", baseURL + "/", baseURL) ' Make sure there's a trailing slash.
		  config.Value("baseURL") = baseURL
		  
		  ' Site description
		  if not config.HasKey("description") then config.Value("description") = DEFAULT_DESCRIPTION
		  
		  ' Build archives?
		  if not config.HasKey("archives") then config.Value("archives") = DEFAULT_ARCHIVES
		  
		  ' How many posts per list page?
		  if not config.HasKey("postsPerPage") then config.Value("postsPerPage") = DEFAULT_POSTS_PER_PAGE
		  
		  ' Which theme?
		  if not config.HasKey("theme") then config.Value("theme") = DEFAULT_THEME_NAME
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ReallyDelete(extends theFolder as FolderItem)
		  ' Deletes the passed FolderItem, even if it contains sub folders and files.
		  ' We'll use a Shell as it's the fastest way to do this reliably.
		  
		  dim s as new Shell
		  
		  #if TargetWindows
		    s.Execute("rd /s /q " + theFolder.ShellPath)
		  #else
		    s.Execute("rm -rf " + theFolder.ShellPath)
		  #endif
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SetTheme()
		  ' Figures out which theme to use and checks that it's valid.
		  ' Assumes we have set a valid site root and have loaded the site config file.
		  
		  try
		    theme = root.Child("themes").Child(config.Lookup("theme", DEFAULT_THEME_NAME))
		  catch
		    raise new Error(CurrentMethodName, "Unable to locate the specified theme folder.")
		  end try
		  
		  ' Check the theme is valid.
		  if not ValidateTheme(theme) then
		    raise new Error(CurrentMethodName, "'" + theme.Name + "' is not a valid theme.")
		  end if
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToClassic(Extends f as Xojo.IO.FolderItem) As FolderItem
		  ' Converts a modern framework FolderItem to a classic framework FolderItem.
		  return new FolderItem(f.Path, FolderItem.PathTypeNative)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function ValidateSite(site as FolderItem) As Boolean
		  ' Returns True if `site` is a valid Strike3 site folder, False otherwise.
		  
		  if site = Nil or not site.Exists then return False
		  if site.Child("content") = Nil or not site.Child("content").Exists then return False
		  if site.Child("storage") = Nil or not site.Child("storage").Exists then return False
		  if site.Child("themes") = Nil or not site.Child("themes").Exists then return False
		  if site.Child("site.data") = Nil or not site.Child("site.data").Exists then return False
		  if site.Child("config.json") = Nil or not site.Child("config.json").Exists then return False
		  
		  return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function ValidateTheme(themeFolder as FolderItem) As Boolean
		  ' Returns True if `themeFolder` is a valid theme. False otherwise.
		  
		  if not themeFolder.Child("theme.json").Exists then return False
		  if not themeFolder.Child("assets").Exists then return False
		  if not themeFolder.Child("layouts").Exists then return False
		  if not themeFolder.Child("layouts").Child("404.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("archive.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("archives.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("home.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("page.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("post.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("list.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("tags.html").Exists then return False
		  if not themeFolder.Child("layouts").Child("partials").Exists then return False
		  
		  ' Must be valid
		  return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function Version() As String
		  ' Returns the current version of Strike3 as a String.
		  
		  return Str(VERSION_MAJOR) + "." + Str(VERSION_MINOR) + "." + Str(VERSION_BUG)
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private baseURL As Text
	#tag EndProperty

	#tag Property, Flags = &h21
		Private config As Xojo.Core.Dictionary
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected db As SQLiteDatabase
	#tag EndProperty

	#tag Property, Flags = &h21
		Private dbFile As FolderItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private publicFolder As FolderItem
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected root As FolderItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private theme As FolderItem
	#tag EndProperty


	#tag Constant, Name = DEFAULT_ARCHIVES, Type = Boolean, Dynamic = False, Default = \"True", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_BASE_URL, Type = Text, Dynamic = False, Default = \"/", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_DESCRIPTION, Type = Text, Dynamic = False, Default = \"My great website", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_POSTS_PER_PAGE, Type = Double, Dynamic = False, Default = \"10", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_SITE_TITLE, Type = Text, Dynamic = False, Default = \"My Website", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_THEME_NAME, Type = Text, Dynamic = False, Default = \"", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = VERSION_BUG, Type = Double, Dynamic = False, Default = \"0", Scope = Public
	#tag EndConstant

	#tag Constant, Name = VERSION_MAJOR, Type = Double, Dynamic = False, Default = \"0", Scope = Public
	#tag EndConstant

	#tag Constant, Name = VERSION_MINOR, Type = Double, Dynamic = False, Default = \"1", Scope = Public
	#tag EndConstant


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
		#tag ViewProperty
			Name="root"
			Group="Behavior"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule
