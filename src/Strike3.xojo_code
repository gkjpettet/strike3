#tag Module
Protected Module Strike3
	#tag Method, Flags = &h21
		Private Sub AddPostToDatabase(p as Strike3.Post)
		  ' Adds the passed Post to the site's database.
		  
		  using Xojo.Data
		  
		  dim dRecord as DatabaseRecord
		  dim postID, tagID as Integer
		  dim rs as RecordSet
		  dim tagName as String
		  
		  dRecord = new DatabaseRecord
		  dRecord.Column("contents") = p.contents
		  dRecord.Column("data") = GenerateJSON(p.data)
		  
		  dRecord.IntegerColumn("date") = p.date.UnixTime
		  dRecord.IntegerColumn("date_year") = p.date.Year
		  dRecord.IntegerColumn("date_month") = p.date.Month
		  dRecord.IntegerColumn("date_day") = p.date.Day
		  
		  dRecord.BooleanColumn("draft") = p.draft
		  dRecord.Column("hash") = p.hash
		  dRecord.BooleanColumn("homepage") = p.homepage
		  dRecord.IntegerColumn("last_updated") = Xojo.Core.Date.Now.SecondsFrom1970
		  dRecord.BooleanColumn("page") = p.page
		  dRecord.Column("source_path") = p.sourcePath
		  dRecord.Column("section") = p.section
		  dRecord.Column("slug") = p.slug
		  dRecord.Column("title") = p.title
		  dRecord.Column("url") = p.url
		  dRecord.BooleanColumn("verified") = True
		  db.InsertRecord("posts", dRecord)
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  
		  ' Get the database ID of this post
		  postID = db.LastRowID
		  
		  ' Add tags
		  for each tagName in p.tags
		    ' Check if this tag has already been defined. If so, grab it's database ID.
		    rs = db.SQLSelect("SELECT id FROM tags WHERE name='" + tagName + "';")
		    if not rs.EOF then
		      tagID = rs.Field("id").IntegerValue
		    else
		      ' This tag has not yet been defined in the database - let's remedy that.
		      dRecord = new DatabaseRecord
		      dRecord.Column("name") = tagName
		      db.InsertRecord("tags", dRecord)
		      if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		      tagID = db.LastRowID
		    end if
		    ' Now we have the ID of this post and the ID of this tag. Create an entry in the pivot table.
		    dRecord = new DatabaseRecord
		    dRecord.IntegerColumn("posts_id") = postID
		    dRecord.IntegerColumn("tags_id") = tagID
		    db.InsertRecord("post_tags", dRecord)
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  next tagName
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub Build(site as FolderItem)
		  ' Builds the site.
		  ' We store the built HTML in root/public.
		  
		  dim f as FolderItem
		  
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
		  
		  ' Publish the 404 page
		  try
		    f = theme.Child("layouts").Child("404.html")
		  catch
		    raise new Error(CurrentMethodName, "Missing the theme's 404 page.")
		  end try
		  if not CopyFileOrFolder(f, publicFolder.Child("404.html")) then
		    raise new Error(CurrentMethodName, _
		    "Unable to copy the 404 page from the theme folder to the public folder.")
		  end if
		  
		  ' Set the verified status of every post in the database to False
		  db.SQLExecute("UPDATE posts SET verified=0;")
		  
		  ' Parse the contents folder into the site's database
		  Parse(root.Child("content"))
		  
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
		Protected Function ExtractFrontMatter(ByRef s as String) As String
		  ' Pulls out and removes JSON frontmatter from `s` (if present) and returns it as a String.
		  ' If present, frontmatter must occur at the beginning of s.
		  ' Frontmatter is in the format:
		  '  ;;;
		  '   {Valid JSON}
		  '  ;;;
		  ' Note that `s` is passed by reference and so will be altered by this method.
		  
		  dim rg as new RegEx
		  dim match as RegExMatch
		  dim frontmatter as String
		  
		  frontmatter = ""
		  
		  try
		    if s.Trim.Left(3) <> ";;;" then return ""
		  catch
		    return ""
		  end try
		  
		  rg.SearchPattern = "^(\;{3}(?:\n|\r)([\w\W]+?)\;{3})"
		  rg.ReplacementPattern = ""
		  
		  match = rg.Search(s)
		  if match <> Nil then
		    frontmatter = match.SubExpressionString(0).Replace(";;;", "")
		    frontmatter = frontmatter.Left(frontmatter.Len - 3).Trim
		    s = rg.Replace(s).Trim
		  end if
		  
		  ' Support the omission of flanking curly braces
		  if frontmatter.Left(1) <> "{" and frontmatter.Right(1) <> "}" then
		    frontmatter = "{" + frontmatter + "}"
		  end if
		  
		  return frontmatter
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FileExistsInDatabase(file as FolderItem) As Boolean
		  ' Returns True if this file has already been parsed into the site's database and has not altered
		  ' since then.
		  
		  ' If this file's hash and file path match a row in the database then this file exists and can 
		  ' be safely skipped.
		  ' If this file's hash isn't in the database but it's file path is then the user has modified 
		  ' a file but kept it in the same location in `/content`. The file will need to be removed and rebuilt.
		  
		  dim hash as String
		  dim rs as RecordSet
		  
		  ' Get this file's MD5 hash
		  hash = file.ToMD5
		  
		  ' Is there a post in the database with this hash and file path?
		  rs = db.SQLSelect("SELECT id FROM posts WHERE (hash='" + hash + "') AND (source_path = '" + _
		  file.ShellPath + "');")
		  if rs = Nil or rs.EOF then
		    return False
		  else
		    ' File paths and hashes match. We can safely skip this file but first flag that we've verified it
		    db.SQLExecute("UPDATE posts SET verified=1 WHERE id=" + rs.Field("id").IntegerValue.ToText + ";")
		    return True
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub FileToDatabase(file as FolderItem)
		  ' Takes a file and adds it to the site's database if needed.
		  
		  Using Xojo.Data
		  
		  dim post as new Post(file)
		  dim tin As TextInputStream
		  dim frontmatter, md As String
		  
		  ' Make sure this is a Markdown file. Otherwise skip it (don't raise an error).
		  try
		    if file.Name.Right(3) <> ".md" then return
		  catch
		    return
		  end try
		  
		  ' Do we need to add this file to the database or is it already there?
		  if FileExistsInDatabase(file) then return
		  
		  ' Get the contents of this file
		  try
		    tin = TextInputStream.Open(file)
		    md = tin.ReadAll()
		    tin.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to read the contents of `" + file.NativePath + "`.")
		  end try
		  
		  ' Extract the frontmatter from this file (if any)
		  frontmatter = ExtractFrontMatter(md)
		  post.markdown = md
		  
		  ' Parse any frontmatter in the file
		  ParseFrontmatter(post, frontmatter)
		  
		  ' Determine the public url for this post
		  post.url = URLForFile(file, post.slug)
		  
		  ' Determine this post's section
		  post.section = SectionForPost(post)
		  
		  ' Set the path for this post's source file
		  post.sourcePath = file.ShellPath.ToText
		  
		  ' Derive this post's file's MD5 hash
		  post.hash = file.ToMD5
		  
		  ' Set this post's updated date
		  post.lastUpdated = Xojo.Core.Date.Now
		  
		  ' Homepage, page or post?
		  if file.NativePath = root.Child("content").Child("index.md").NativePath then
		    post.homepage = True
		  elseif file.Name = "index.md" then
		    post.page = True
		  else
		    post.page = False
		  end if
		  
		  ' Render the Markdown
		  post.contents = Markdown.Render(md)
		  
		  ' Add this post to the database
		  AddPostToDatabase(post)
		  
		  
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
		Private Function NameWithoutMDExtension(Extends f as FolderItem) As String
		  ' Returns the name of this file without the .md file extension.
		  
		  try
		    if f.Name.Right(3) = ".md" then
		      return f.Name.Left(f.Name.Len - 3)
		    else
		      return f.Name
		    end if
		  catch
		    return f.Name
		  end try
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Parse(folder as FolderItem)
		  ' Traverses this folder and parses it into the site's database.
		  ' We call it recursively for each folder encountered within /content.
		  
		  dim f as FolderItem
		  dim i, folderCount as Integer
		  
		  folderCount = folder.Count
		  for i = 1 to folderCount
		    f = folder.TrueItem(i)
		    
		    if f.Directory then
		      Parse(f)
		    else
		      if f.Name <> "._DS_STORE" then FileToDatabase(f) ' Skip those pesky macOS files.
		    end if
		  next i
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ParseFrontmatter(post as Strike3.Post, frontmatter as String)
		  ' Parse `frontmatter` (if any) into this post's data and guaranteed properties.
		  
		  using Xojo.Core
		  using Xojo.Data
		  
		  if frontmatter = "" then
		    post.date = post.file.ModificationDate.ToModernDate
		    post.slug = post.file.NameWithoutMDExtension.Slugify
		    post.title = post.slug
		    return
		  end if
		  
		  try
		    post.data = ParseJSON(frontmatter.ToText)
		    ' Have the required post properties been overriden by the frontmatter?
		    ' Date.
		    if post.data.HasKey("date") then
		      post.date = Date.FromText(post.data.Value("date"))
		      post.data.Remove("date")
		    else
		      post.date = post.file.ModificationDate.ToModernDate
		    end if
		    ' Draft
		    if post.data.HasKey("draft") then
		      post.draft = post.data.Value("draft")
		      post.data.Remove("draft")
		    end if
		    ' Slug.
		    if post.data.HasKey("slug") then
		      post.slug = post.data.Value("slug")
		      post.data.Remove("slug")
		    else
		      post.slug = post.file.NameWithoutMDExtension.Slugify
		    end if
		    ' Title.
		    if post.data.HasKey("title") then
		      post.title = post.data.Value("title")
		      post.data.Remove("title")
		    else
		      post.title = post.file.NameWithoutMDExtension.Slugify
		    end if
		    ' Tags.
		    if post.data.HasKey("tags") then
		      dim autoTags() as Auto = post.data.Value("tags")
		      post.data.Remove("tags")
		      for each tag as Text in autoTags
		        post.tags.Append(tag)
		      next tag
		    end if
		  catch
		    raise new Error(CurrentMethodName, "The frontmatter within `" + post.file.NativePath + _
		    "` is not valid JSON.")
		  end try
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function Permalink(f as FolderItem) As String
		  ' Returns what will be the public URL of the passed file.
		  
		  return if(baseURL.Right(1) = "/", baseURL.Left(baseURL.Length - 1), baseURL) + _
		  f.NativePath.Replace(publicFolder.NativePath, "")
		End Function
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
		Private Function SectionForPost(post as Strike3.Post) As String
		  ' Returns the section for this post.
		  ' The section is a dot-delimited string value representing where in the /content hierarchy this post is.
		  ' E.g:
		  ' www.example.com/blog/first-post.html           section = blog
		  ' www.example.com/blog/personal/test.html        section = blog.personal
		  ' www.example.com/about                        } section = about
		  ' www.example.com/about/index.html             } section = about
		  ' The passed `post` MUST already have its url correctly set.
		  
		  dim section as String
		  
		  ' post.url is in the format: baseURL/section1/section[N]/fileName.html
		  try
		    section = post.url.Replace(baseURL, "")
		    section = section.Replace(post.slug + ".html", "")
		    section = section.ReplaceAll("/", ".").Trim
		    if section = "" then return ""
		    if section.Left(1) = "." then section = section.Right(section.Len - 1)
		    if section.Right(1) = "." then section = section.Left(section.Len - 1)
		  catch
		    raise new Error(CurrentMethodName, "Unable to determine post section for `" + _
		    post.file.NativePath + "`.")
		  end try
		  
		  return section
		  
		End Function
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
		Private Function Slugify(Extends s as String) As String
		  return Slugify(s)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function Slugify(s as String) As String
		  ' Returns the passed String `s` as a URL-friendly lowercase slug.
		  ' A slug is the part of an URL which identifies a page using human-readable keywords.
		  ' URL reserved characters:
		  '                      ! * ' ( ) ; : @ & = + $ , / ? # [ ]
		  
		  dim rg as new RegEx
		  
		  rg.Options.ReplaceAllMatches = True
		  
		  ' First remove all of the reserved characters
		  rg.SearchPattern = "([!*'();:@&=+$,/?#[\]])"
		  rg.ReplacementPattern = ""
		  s = rg.Replace(s)
		  
		  ' Replace % with percent
		  rg.SearchPattern = "([%])"
		  rg.ReplacementPattern = "percent"
		  s = rg.Replace(s)
		  
		  ' Replace all whitespace with "-"
		  rg.SearchPattern = "([\s])"
		  rg.ReplacementPattern = "-"
		  s = rg.Replace(s)
		  
		  ' Replace -- with -
		  rg.SearchPattern = "(-){2,}"
		  rg.ReplacementPattern = "-"
		  s = rg.Replace(s)
		  
		  ' Lowercase it and return
		  return s.Lowercase()
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function StripHTMLTags(s as String) As String
		  ' Strips all HTML tags from `s`.
		  
		  dim rg as new RegEx
		  dim match as RegExMatch
		  
		  rg.SearchPattern = REGEX_STRIP_HTML
		  rg.ReplacementPattern = ""
		  
		  do
		    match = rg.Search(s)
		    if match <> Nil then s = s.Replace(match.SubExpressionString(0), "")
		  loop until match = Nil
		  
		  return rg.Replace(s)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToClassic(Extends f as Xojo.IO.FolderItem) As FolderItem
		  ' Converts a modern framework FolderItem to a classic framework FolderItem.
		  return new FolderItem(f.Path, FolderItem.PathTypeNative)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToMD5(extends f as FolderItem) As String
		  ' Returns the MD5 hash for the passed file.
		  ' On macOS we'll use the built-in md5 command.
		  
		  #pragma Warning "Need to check InStr subtraction"
		  
		  dim myShell as new Shell
		  dim result as String
		  
		  myShell.Execute("md5 " + f.ShellPath)
		  
		  try
		    ' Example output: MD5 (PATH_TO_FILE) = MD5_HASH
		    result = myShell.Result
		    return result.Right(result.Len - InStr(result, "=") - 1)
		  catch
		    raise new Error(CurrentMethodName, "Error getting MD5 for file `" + f.NativePath + "`.")
		  end try
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToModernDate(extends d as Date) As Xojo.Core.Date
		  return new Xojo.Core.Date(d.Year, d.Month, d.Day, Xojo.Core.TimeZone.Current)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function UnixTime(Extends d as Xojo.Core.Date) As Double
		  ' A replacement for Xojo.Core.Date.SecondsFrom1970 that returns the Unix time for the passed date, 
		  ' respecting the current user's time zone.
		  
		  using Xojo.Core
		  
		  return d.SecondsFrom1970 + (d.TimeZone.SecondsFromGMT - TimeZone.Current.SecondsFromGMT)
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function URLForFile(file as FolderItem, slug as String) As String
		  ' Determines the public URL for the passed file.
		  
		  dim content, item as FolderItem
		  dim url as String
		  
		  content = root.Child("content")
		  item = file.Parent
		  
		  do until item.NativePath = content.NativePath
		    
		    url = if(url = "", item.Name.Slugify + url, item.Name + "/" + url)
		    
		    item = item.Parent
		    
		  loop
		  
		  return baseURL + url + if(url = "", "", "/") + slug + ".html"
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

	#tag Property, Flags = &h1
		Protected publicFolder As FolderItem
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

	#tag Constant, Name = REGEX_STRIP_HTML, Type = String, Dynamic = False, Default = \"<(\?:[^>\x3D]|\x3D\'[^\']*\'|\x3D\"[^\"]*\"|\x3D[^\'\"][^\\s>]*)*>", Scope = Private
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
	#tag EndViewBehavior
End Module
#tag EndModule
