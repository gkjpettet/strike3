#tag Module
Protected Module Strike3
	#tag Method, Flags = &h21
		Private Function AddNavigationChildren(extends parent as Strike3.NavigationItem, folder as FolderItem) As Strike3.NavigationItem
		  dim f as FolderItem
		  dim ni as Strike3.NavigationItem
		  dim i, folderCount as Integer
		  
		  folderCount = folder.Count
		  for i = 1 to folderCount
		    f = folder.TrueItem(i)
		    if f.Directory then
		      ni = new NavigationItem(f.Name, NavigationPermalink(f), "", parent)
		      parent.children.Append(ni.AddNavigationChildren(f))
		    end if
		  next i
		  
		  return parent
		  
		End Function
	#tag EndMethod

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

	#tag Method, Flags = &h21
		Private Sub AddSectionFolder(source as FolderItem, destination as FolderItem)
		  ' Used to recursively copy the folder structure of /content into our public build folder.
		  
		  dim f, newDestination as FolderItem
		  dim i, sourceCount as Integer
		  
		  if source.Directory then
		    if source.NativePath = root.Child("content").NativePath then
		      ' Don't create a `content` folder in the destination!
		      newDestination = destination
		    else
		      newDestination = destination.Child(source.Name)
		      newDestination.CreateAsFolder()
		    end if
		    sourceCount = source.Count
		    for i = 1 to sourceCount
		      f = source.TrueItem(i)
		      if f.Directory then AddSectionFolder(f, newDestination)
		    next i
		  end if
		  
		End Sub
	#tag EndMethod

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
		  ' if publicFolder.Exists then ReallyDelete(publicFolder)
		  if publicFolder.Exists then
		    DeleteFolderContents(publicFolder)
		  else
		    publicFolder.CreateAsFolder()
		  end if
		  
		  ' Load the site's configuration.
		  LoadConfig()
		  
		  ' Set the theme.
		  SetTheme()
		  
		  ' Reset the RSS items.
		  redim rssItems(-1)
		  
		  ' Publish the 404 page.
		  try
		    theme.Child("layouts").Child("404.html").ToModern.CopyTo(publicFolder.ToModern.Child("404.html"))
		  catch
		    raise new Error(CurrentMethodName, _
		    "Unable to copy the 404 page from the theme folder to the public folder.")
		  end try
		  
		  ' Set the verified status of every post in the database to False.
		  db.SQLExecute("UPDATE posts SET verified=0;")
		  
		  ' Parse the contents folder into the site's database.
		  Parse(root.Child("content"))
		  
		  ' Remove any posts in the database which were not verified.
		  ' These will be posts that have been removed since the last build was ran.
		  db.SQLExecute("DELETE FROM posts WHERE verified=0;")
		  
		  ' Create the required folder structure in the output FolderItem to house the HTML files.
		  BuildSiteFolders()
		  
		  ' Copy theme assets.
		  CopyThemeAssets()
		  
		  ' Copy storage contents.
		  CopyStorageContent()
		  
		  ' Site navigation.
		  BuildNavigation()
		  
		  ' Tags.
		  BuildTags()
		  
		  ' Archives.
		  BuildArchives()
		  
		  ' Render the posts in the database.
		  RenderPosts()
		  
		  ' Create required list pages.
		  BuildLists(root.Child("content"))
		  
		  ' Create the RSS feed (if desired).
		  if config.Value("rss") then ConstructRSSFeed()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildArchives()
		  ' Build the archive folders and files.
		  ' baseURL/archive/<year>/index.html
		  ' baseURL/archive/<year>/<month>/index.html
		  ' baseURL/archive/<year>/<month>/<day>/index.html
		  ' baseURL/archive/<year>/page/<pageNumber>/index.html   etc
		  
		  const QUOTE = """"
		  
		  ' Does the user want us to build archives? They are computationally expensive to build.
		  if config.Value("archives") = False then return
		  
		  dim year, years(), month, months(), day, days() as Integer
		  dim rs as RecordSet
		  dim archiveFolder, yearFolder, monthFolder, dayFolder as FolderItem
		  dim url as String
		  dim arcYear as ArchiveYear
		  dim arcMonth as ArchiveMonth
		  
		  ' Get an array of years that have posts.
		  rs = db.SQLSelect(SQL.YearsWithPosts)
		  if rs = Nil or rs.EOF then return ' No posts.
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  while not rs.EOF
		    years.Append(rs.Field("year").IntegerValue)
		    rs.MoveNext()
		  wend
		  
		  ' Create the parent archive folder.
		  archiveFolder = publicFolder.Child("archive")
		  archiveFolder.CreateAsFolder()
		  
		  ' Clear out any previously created archive tree.
		  redim archiveTree(-1)
		  
		  ' Build each archive year.
		  for each year in years
		    arcYear = new ArchiveYear(year)
		    
		    yearFolder = archiveFolder.Child(Str(year))
		    yearFolder.CreateAsFolder()
		    BuildArchivesList(yearFolder, year)
		    
		    ' Get an array of months of this year that have posts.
		    redim months(-1)
		    rs = db.SQLSelect(SQL.MonthsWithPostsInYear(year))
		    if rs = Nil or rs.EOF then continue ' No posts for this month.
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		    while not rs.EOF
		      months.Append(rs.Field("month").IntegerValue)
		      rs.MoveNext()
		    wend
		    
		    ' Build each archive month for this year.
		    for each month in months
		      arcMonth = new ArchiveMonth(month)
		      
		      monthFolder = yearFolder.Child(Str(month))
		      monthFolder.CreateAsFolder()
		      BuildArchivesList(monthFolder, year, month)
		      
		      ' Get an array of days of this month and year that have posts.
		      redim days(-1)
		      rs = db.SQLSelect(SQL.DaysWithPostsInMonthAndYear(year, month))
		      if rs = Nil or rs.EOF then continue ' No posts for this day.
		      if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		      while not rs.EOF
		        days.Append(rs.Field("day").IntegerValue)
		        rs.MoveNext()
		      wend
		      
		      ' Build each archive day for this month and year.
		      for each day in days
		        arcMonth.days.Append(day)
		        
		        dayFolder = monthFolder.Child(Str(day))
		        dayFolder.CreateAsFolder()
		        BuildArchivesList(dayFolder, year, month, day)
		      next day
		      
		      arcYear.months.Append(arcMonth)
		    next month
		    
		    archiveTree.Append(arcYear)
		  next year
		  
		  ' Build an unordered HTML list of the archives by short and long month.
		  ' These are avaliable as {{archives.months}} and {{archives.longMonths}} tags.
		  archiveMonthsHTML = "<ul class=" + QUOTE + "archive-months" + QUOTE + "</ul>"
		  archiveLongMonthsHTML = "<ul class=" + QUOTE + "archive-long-months" + QUOTE + "</ul>"
		  for each arcYear in archiveTree
		    for each arcMonth In arcYear.months
		      url = publicFolder.Child("archive").Child(Str(arcYear.value)).Child(Str(arcMonth.value)).ToPermalink
		      archiveMonthsHTML = archiveMonthsHTML + "<li>" + _
		      "<a href=" + QUOTE + url + QUOTE + ">" + arcMonth.shortName +" " + _
		      Str(arcYear.value) + "</a></li>"
		      archiveLongMonthsHTML = archiveLongMonthsHTML + "<li>" + _
		      "<a href=" + QUOTE + url + QUOTE + ">" + arcMonth.longName +" " + _
		      Str(arcYear.value) + "</a></li>"
		    next arcMonth
		  next arcYear
		  archiveMonthsHTML = archiveMonthsHTML + "</ul>"
		  archiveLongMonthsHTML = archiveLongMonthsHTML + "</ul>"
		  
		  ' Render baseURL/archive/index.html.
		  RenderArchivePage()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildArchivesList(enclosingFolder as FolderItem, year as Integer, month as Integer = -1, day as Integer = -1)
		  ' Build the archive folders and files for this year.
		  ' We know that there is at least one post made in this year.
		  
		  dim rs as RecordSet
		  dim postCount, numListPages, currentPage, a, prevNum, nextNum as Integer
		  dim templateFile, pageFolder as FolderItem
		  dim template, type as String
		  dim postsPerPage as Integer = config.Value("postsPerPage")
		  dim context as Strike3.ListContext
		  
		  ' What type of archives list is this?
		  if month = -1 then
		    type = "year"
		  elseif day = -1 then
		    type = "month"
		  else
		    type = "day"
		  end if
		  
		  ' How many posts for this type?
		  select case type
		  case "year"
		    rs = db.SQLSelect(SQL.PostCountForYear(year))
		  case "month"
		    rs = db.SQLSelect(SQL.PostCountForMonth(year, month))
		  case "day"
		    rs = db.SQLSelect(SQL.PostCountForDay(year, month, day))
		  else
		    raise new Error(CurrentMethodName, "Invalid type `" + type + "`.")
		  end select
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil.")
		  postCount = rs.Field("total").IntegerValue
		  
		  ' Get the "archives.html" template file text to use to render this year's archive list page(s).
		  templateFile = theme.Child("layouts").Child("archives.html")
		  if not templateFile.Exists then raise new Error(CurrentMethodName, _
		  "The `archives.html` template file is missing.")
		  template = FileContents(templateFile)
		  
		  ' As we know how many posts to list per page and we know how many posts there are, we can 
		  ' calculate how many list pages we need.
		  numListPages = Ceil(postCount/postsPerPage)
		  
		  ' Construct any required pagination folders.
		  if numListPages > 1 then
		    pageFolder = enclosingFolder.Child("page")
		    pageFolder.CreateAsFolder
		    for a = 2 to numListPages
		      pageFolder.Child(a.ToText).CreateAsFolder()
		    next a
		  end if
		  
		  ' Get all required posts, ordered by published date, paginated and render them.
		  for currentPage = 1 To numListPages
		    select case type
		    case "year"
		      rs = db.SQLSelect(SQL.PostsForYear(year, postsPerPage, currentPage))
		    case "month"
		      rs = db.SQLSelect(SQL.PostsForMonth(year, month, postsPerPage, currentPage))
		    case "day"
		      rs = db.SQLSelect(SQL.PostsForDay(year, month, day, postsPerPage, currentPage))
		    else
		      raise new Error(CurrentMethodName, "Invalid type `" + type + "`.")
		    end select
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		    if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil")
		    
		    ' Create the context for this list page.
		    context = new Strike3.ListContext
		    if numListPages = 1 then ' Only one page.
		      context.prevPage = ""
		      context.nextPage = ""
		    else ' Multiple pages.
		      if currentPage = numListPages then ' Last page of multiple pages.
		        prevNum = currentPage - 1
		        if prevNum = 1 then
		          context.prevPage = enclosingFolder.Child("index.html").ToPermalink
		        else
		          context.prevPage = enclosingFolder.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = ""
		      elseif currentPage = 1 then ' First page of multiple pages.
		        context.prevPage = ""
		        nextNum = currentPage + 1
		        context.nextPage = enclosingFolder.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      else ' Not the first or last of multiple pages.
		        prevNum = currentPage - 1
		        nextNum = currentPage + 1
		        if prevNum = 1 then
		          context.prevPage = enclosingFolder.Child("index.html").ToPermalink
		        else
		          context.prevPage = enclosingFolder.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = enclosingFolder.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      end if
		    end if
		    
		    RenderListPage(rs, context, currentPage, template, enclosingFolder)
		  next currentPage
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildLists(folder as FolderItem)
		  ' Builds the list page(s) for all sections in the content folder to the /public folder.
		  
		  dim f as FolderItem
		  dim i, folderCount as Integer
		  
		  if folder.Directory then
		    if IsSection(folder) then RenderList(folder)
		    folderCount = folder.Count
		    for i = 1 to folderCount
		      f = folder.TrueItem(i)
		      if f.Directory then BuildLists(f)
		    next i
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildNavigation()
		  ' Creates the main site navigation tree.
		  
		  ' Create the root.
		  siteNavTree = new Strike3.NavigationItem("root", "baseURL", "")
		  
		  ' Add the home link.
		  siteNavTree.children.Append(new NavigationItem("home", baseURL, "home", siteNavTree))
		  
		  ' Add the sections in the /content folder.
		  siteNavTree = siteNavTree.AddNavigationChildren(root.Child("content"))
		  
		  ' Add the archive (if required).
		  if config.Value("archives") then 
		    siteNavTree.children.Append(new NavigationItem("archive", baseURL + "archive.html", "archives", siteNavTree))
		  end if
		  
		  ' Convert the siteNavTree into HTML and cache it.
		  siteNavigationHTML = siteNavTree.NavItemToHTML("site-nav")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildSiteFolders()
		  ' Construct required folders in the public folder to house the rendered HTML files.
		  
		  dim f, content as FolderItem
		  
		  content = root.Child("content")
		  
		  ' User defined content sections
		  AddSectionFolder(content, publicFolder)
		  
		  ' Storage folder
		  f = publicFolder.Child("storage")
		  f.CreateAsFolder()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildTags()
		  ' Build the tag folders and files.
		  ' baseURL/tag/<tag-name>/index.html
		  ' baseURL/tag/<tag-name>/page/2/index.html, etc
		  
		  dim tagRoot, tagFolder as FolderItem
		  dim rs as RecordSet
		  dim tagName as String
		  
		  rs = db.SQLSelect(SQL.AllTags)
		  if rs = Nil or rs.EOF then return ' No tags to render.
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  
		  ' Create the root folder for all tags.
		  tagRoot = publicFolder.Child("tag")
		  tagRoot.CreateAsFolder()
		  
		  ' Render each tag
		  while not rs.EOF
		    tagName = rs.Field("name").StringValue
		    tagFolder = tagRoot.Child(tagName)
		    tagFolder.CreateAsFolder()
		    RenderTag(tagName, tagFolder)
		    
		    rs.MoveNext()
		  wend
		  
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
		Private Sub ConstructRSSFeed()
		  ' Constructs the RSS feed and saves it to /rss.xml
		  
		  using Sorting 
		  
		  dim rssFile as FolderItem
		  dim xml as new XmlDocument
		  dim root, channel, title, description, link, item, pubDate as XmlNode
		  
		  root = xml.AppendChild(xml.CreateElement("rss"))
		  root.SetAttribute("version", "2.0")
		  
		  channel = root.AppendChild(xml.CreateElement("channel"))
		  title = XmlNodeWithText(xml, channel, "title", config.Value("title"))
		  description = XmlNodeWithText(xml, channel, "description", config.Value("description"))
		  link = XmlNodeWithText(xml, channel, "link", baseURL)
		  
		  if rssItems.Ubound >= 0 then
		    ' Sort the RSS items by date (newest first).
		    rssItems.Sort(AddressOf CompareRSSItemDates)
		    
		    ' Add each item to the XML document.
		    for each ri as RSSItem in rssItems
		      item = channel.AppendChild(xml.CreateElement("item"))
		      title = XmlNodeWithText(xml, item, "title", ri.title)
		      link = XmlNodeWithText(xml, item, "link", ri.link)
		      pubDate = XmlNodeWithText(xml, item, "pubDate", ri.pubDate.ToText)
		      description = XmlNodeWithText(xml, item, "description", ri.description)
		    next ri
		  end if
		  
		  ' Write the XML to public/rss.xml.
		  try
		    rssFile = publicFolder.Child("rss.xml")
		    WriteToFile(rssFile, xml.ToString)
		  catch
		    raise new Error(CurrentMethodName, "Unable To create the rss.xml file.")
		  end try
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub CopyStorageContent()
		  ' Copies any files in root/storage to public/storage.
		  
		  // TODO: Implement caching so we only copy files we actually need to
		  
		  dim f, storage, publicStorage as Xojo.IO.FolderItem
		  
		  publicStorage = publicFolder.ToModern.Child("storage")
		  
		  storage = root.Child("storage").ToModern
		  
		  if storage.Count > 0 then
		    for each f in storage.Children
		      f.CopyTo(publicStorage)
		    next f
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub CopyThemeAssets()
		  ' Copies any assets provided by the current theme to public/theme/assets.
		  
		  dim f, themeAssets, publicAssets as Xojo.IO.FolderItem
		  
		  publicAssets = publicFolder.ToModern.Child("assets")
		  themeAssets = theme.Child("assets").ToModern
		  
		  if themeAssets.Count > 0 then
		    f = publicAssets
		    f.CreateAsFolder()
		    for each f in themeAssets.Children
		      f.CopyTo(publicAssets)
		    next f
		  end if
		  
		  
		End Sub
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
		  'schema = Xojo.IO.SpecialFolder.GetResource("database_schema.sql").ToClassic
		  schema = App.ExecutableFile.Parent.Child("database_schema.sql")
		  
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

	#tag Method, Flags = &h21
		Private Sub CreateSampleContent()
		  ' Create some boilerplate/starter content for the site within `root`.
		  
		  const QUOTE = """"
		  
		  dim tout as TextOutputStream
		  dim f as FolderItem
		  
		  ' Create a 'Hello World' post.
		  try
		    f = root.Child("content").Child("Hello World.md")
		    tout = TextOutputStream.Create(f)
		    tout.WriteLine(";;;")
		    tout.WriteLine(QUOTE + "title" + QUOTE + ": " + QUOTE + "Hello World!" + QUOTE)
		    tout.WriteLine(";;;")
		    tout.WriteLine("")
		    tout.WriteLine("This is your first post. Feel free to edit or delete it.")
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to create sample content (`Hello World post`).")
		  end try
		  
		  ' Create a test page.
		  try
		    root.Child("content").Child("about").CreateAsFolder()
		    f = root.Child("content").Child("about").Child("index.md")
		    tout = TextOutputStream.Create(f)
		    tout.WriteLine(";;;")
		    tout.WriteLine(QUOTE + "title" + QUOTE + ": " + QUOTE + "Test Page" + QUOTE)
		    tout.WriteLine(";;;")
		    tout.WriteLine("")
		    tout.Write("This is an example of a page. You can find its content in **/content/about/index.md**. ")
		    tout.Write("Feel free to edit or delete it.")
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to create sample content (`About page`).")
		  end try
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function CreateSite(name as String, where as FolderItem, sampleContent as Boolean = True) As FolderItem
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
		    jsonDict.Value("rss") = DEFAULT_RSS
		    jsonDict.Value("title") = name
		    tout.Write(GenerateJSON(jsonDict))
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to write to the config.json file.")
		  end try
		  
		  ' Get the default theme from the app's resources folder and copy it.
		  'dim defaultTheme as Xojo.IO.FolderItem = Xojo.IO.SpecialFolder.GetResource("primary")
		  dim defaultTheme as Xojo.IO.FolderItem = App.ExecutableFile.Parent.ToModern.Child("primary")
		  try
		    defaultTheme.CopyTo(root.Child("themes").ToModern)
		  catch
		    raise new Error(CurrentMethodName, "Unable to copy the default theme root/themes.")
		  end try
		  
		  ' Create some starter content for this new site to get the user going if desired.
		  if sampleContent then CreateSampleContent()
		  
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
		  dim fModern as Xojo.IO.FolderItem
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
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to write to the theme.json file.")
		  end try
		  
		  ' assets/
		  f = newTheme.Child("assets")
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the assets folder.")
		  end if
		  
		  ' layouts/
		  f = newTheme.Child("layouts")
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layout folder.")
		  end if
		  
		  ' layouts/partials/
		  try
		    f = newTheme.Child("layouts").Child("partials")
		  catch
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to find the `layouts` folder.")
		  end try
		  f.CreateAsFolder()
		  if f.LastErrorCode <> FolderItem.NoError then
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/partials folder.")
		  end if
		  
		  ' layouts/404.html.
		  try
		    'fModern = Xojo.IO.SpecialFolder.GetResource("404.html")
		    fModern = App.ExecutableFile.Parent.ToModern.Child("404.html")
		    fModern.CopyTo(newTheme.Child("layouts").ToModern)
		  catch
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/404.html file.")
		  end try
		  
		  ' layouts/archive.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("archive.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/archive.html file.")
		  End Try
		  
		  ' layouts/archives.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("archives.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/archives.html file.")
		  end try
		  
		  ' layouts/home.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("home.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/home.html file.")
		  end try
		  
		  ' layouts/page.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("page.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/page.html file.")
		  end try
		  
		  ' layouts/post.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("post.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/post.html file.")
		  end try
		  
		  ' layouts/list.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("list.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/list.html file.")
		  end try
		  
		  ' layouts/tags.html
		  try
		    tout = TextOutputStream.Create(newTheme.Child("layouts").Child("tags.html"))
		    tout.Close()
		  catch e
		    ReallyDelete(newTheme)
		    raise new Error(CurrentMethodName, "Unable to create the layouts/tags.html file.")
		  end try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub DeleteFolderContents(folder as FolderItem)
		  ' Quickly deletes the contents of a folder.
		  
		  if not folder.Directory then return
		  if folder.ShellPath = "/" then
		    raise new Error(CurrentMethodName, "Will not allow you to remove the computer's root!")
		  end if
		  
		  dim sh as new Shell
		  
		  sh.Mode = 0 ' Synchronous.
		  sh.Execute("rm -rf " + folder.ShellPath + "/*")
		  
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
		Private Function FileContents(file as FolderItem) As String
		  ' Gets the string contents of the passed file.
		  ' We will standardise line endings to EndOfLine.UNIX
		  
		  dim tin as TextInputStream
		  dim s as String
		  
		  try
		    tin = TextInputStream.Open(file)
		    s = tin.ReadAll()
		    return ReplaceLineEndings(s, EndOfLine.UNIX)
		  catch
		    return ""
		  end try
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FileCount(extends folder as FolderItem) As Integer
		  ' Returns the number of files (not folders) in the passed FolderItem.
		  ' We exclude macOS .DS_STORE files.
		  
		  dim f as FolderItem
		  dim count, i, folderCount as Integer = 0
		  
		  if folder.Directory = False then return 0
		  
		  folderCount = folder.Count
		  for i = 1 to folderCount
		    f = folder.TrueItem(i)
		    if f.Name = ".DS_STORE" then continue
		    if not f.Directory then count = count + 1
		  next i
		  
		  return count
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
		  
		  using Xojo.Data
		  
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

	#tag Method, Flags = &h21
		Private Function FolderAsSection(folder as FolderItem) As String
		  ' Returns the section for this folder.
		  ' The section is a dot-delimited Text value representing where in the /content hierarchy this folder is.
		  ' E.g:
		  ' www.example.com/blog/             section = blog
		  ' www.example.com/blog/personal/    section = blog.personal
		  ' www.example.com/about/            section = about
		  
		  dim url as String
		  
		  if not folder.Directory then
		    raise new Error(CurrentMethodName, "`" + folder.NativePath + "` is not a folder.")
		  end if
		  
		  url = folder.URLPath ' example: file://path/to/file
		  url = url.Right(url.Len - url.InStr("content/") - 8)
		  if url = "" then return "" ' Content folder (the root section).
		  if url.Right(1) = "/" then url = url.Left(url.Len - 1)
		  return url.ReplaceAll("/", ".")
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function GetTemplateFile(type as String, p as Strike3.Post) As FolderItem
		  ' Returns the template file to use to render this post.
		  ' `type` is either "page" or "post".
		  
		  dim template as FolderItem
		  dim section, sections() as String
		  
		  if type <> "page" and type <> "post" then
		    raise new Error(CurrentMethodName, "Invalid template file type `" + type + "`.")
		  end if
		  
		  ' Get the template file to use to render this post.
		  ' We default to theme/page.html or theme/post.html if we can't find theme/sectionPath/page.html
		  ' or theme/sectionPath/page.html (depending on `type`)
		  template = theme.Child("layouts")
		  sections = p.section.Split(".")
		  for each section in sections
		    template = template.Child(section)
		    if not template.Exists then
		      template = theme.Parent
		      exit
		    end if
		  next section
		  template = template.Child(type + ".html")
		  
		  ' Check that the "page.html" or "post.html" template file for this section exists.
		  if not template.Exists and _
		    template.NativePath <> theme.Child("layouts").Child(type + ".html").NativePath then
		    ' It doesn't exist. Fallback to the default "page.html" or "post.html" template file.
		    template = theme.Child("layouts").Child(type + ".html")
		  end if
		  
		  if not template.Exists then raise new Error(CurrentMethodName, _
		  "Cannot find the default `" + type + ".html` template file.")
		  
		  return template
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function GetTemplateListFile(section as String) As FolderItem
		  ' Returns the template file to use to render this section list.
		  ' `section` is the dot-delimited section path.
		  
		  dim template as FolderItem
		  dim s, sections() as String
		  
		  ' Get the template file to use to render this post.
		  ' We default to theme/list.html if we can't find theme/sectionPath/list.html.
		  template = theme.Child("layouts")
		  sections = section.Split(".")
		  for each s in sections
		    template = template.Child(s)
		    if not template.Exists then
		      template = theme.Parent
		      exit
		    end if
		  next s
		  template = template.Child("list.html")
		  
		  ' Check that the "list.html" template file for this section exists.
		  if not template.Exists and template.NativePath <> theme.Child("layouts").Child("list.html").NativePath then
		    ' It doesn't exist. Fallback to the default "list.html" template file.
		    template = theme.Child("layouts").Child("list.html")
		  end if
		  
		  if not template.Exists then raise new Error(CurrentMethodName, _
		  "Cannot find the default `list.html` template file.")
		  
		  return template
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function HelperTag(value as String) As String
		  ' Strike3 provides a number of miscellaneous tags that can be called from any template file .
		  ' {{helper.day}}        The current day Of the month (two digits)
		  ' {{helper.longMonth}}  The current month (e.g. January)
		  ' {{helper.shortMonth}} The current month (e.g. Jan)
		  ' {{helper.month}}      The current month (two digits)
		  ' {{helper.year}}       The current year (four digits)
		  
		  dim d as Xojo.Core.Date = Xojo.Core.Date.Now
		  
		  select case value
		  case "day"
		    if d.Day < 10 then
		      return "0" + Str(d.Day)
		    else
		      return Str(d.Day)
		    end if
		  case "longMonth"
		    return d.LongMonth
		  case "shortMonth"
		    return d.ShortMonth
		  case "month"
		    if d.Month < 10 then
		      return "0" + Str(d.Month)
		    else
		      return Str(d.Month)
		    end if
		  case "year"
		    return Str(d.Year)
		  case else
		    raise new Error(CurrentMethodName, "Unknown helper value `" + value + "`.")
		  end select
		  
		  
		End Function
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
		Private Function Insert(extends s as String, stringToInsert as String, position as Integer) As String
		  ' Inserts the passed string `stringToInsert` into string `s` at `position` (zero based).
		  
		  dim left, right as String
		  
		  if s = "" then return stringToInsert
		  if stringToInsert = "" then return s
		  if (position + 1) > s.Len then return s
		  if position = 0 then return stringToInsert + s
		  if position = s.Len - 1 then return s + stringToInsert
		  
		  left = s.Left(position)
		  right = s.Right(s.Len - position)
		  
		  return left + stringToInsert + right
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsSection(folder as FolderItem) As Boolean
		  ' Takes a folder within /content and returns True if it's a section rather than a page.
		  ' If a folder in /content contains just a single index.md file then it's a page, otherwise it's
		  ' a section.
		  
		  dim hasIndexPage as Boolean = False
		  
		  if folder.Child("index.md").Exists then hasIndexPage = True
		  
		  if not hasIndexPage then return True ' Section.
		  
		  if folder.FileCount = 1 then ' Page (has an index.md file and there is only one file in the folder).
		    return False
		  end if
		  
		  return True ' Section.
		  
		End Function
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
		  
		  ' Create an RSS feed?
		  if not config.HasKey("rss") then config.Value("rss") = DEFAULT_RSS
		  
		  ' How many posts per list page?
		  if not config.HasKey("postsPerPage") then config.Value("postsPerPage") = DEFAULT_POSTS_PER_PAGE
		  
		  ' Which theme?
		  if not config.HasKey("theme") then config.Value("theme") = DEFAULT_THEME_NAME
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function LongMonth(extends d as Xojo.Core.Date) As String
		  ' returns the month of the passed date in long form.
		  
		  if d = Nil then
		    return ""
		  else
		    select case d.Month
		    case 1
		      return "January"
		    case 2
		      return "February"
		    case 3
		      return "March"
		    case 4
		      return "April"
		    case 5
		      return "May"
		    case 6
		      return "June"
		    case 7
		      return "July"
		    case 8
		      return "August"
		    case 9
		      return "September"
		    case 10
		      return "October"
		    case 11
		      return "November"
		    case 12
		      return "December"
		    else
		      return ""
		    end select
		  end if
		End Function
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
		Private Function NavigationPermalink(folder as FolderItem) As String
		  ' Returns the public permalink for the specified folder in the /content folder.
		  ' Used when generating the main site navigation.
		  ' We keep error checking light here as it should have been done beforehand...
		  
		  dim url as String
		  dim f as FolderItem
		  
		  f = folder
		  do
		    if url <> "" then
		      url = f.Name.Slugify  + "/" + url
		    else
		      url = f.Name.Slugify
		    end if
		    f = f.Parent
		  loop until f.NativePath = root.Child("content").NativePath
		  
		  return baseURL + url + "/index.html"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function NavItemToHTML(extends item as Strike3.NavigationItem, theClass as String="") As String
		  ' Returns the passed NavigationItem as an unordered HTML list.
		  
		  const QUOTE = """"
		  
		  dim html as String
		  dim child As Strike3.NavigationItem
		  
		  if item.children.Ubound < 0 then return ""
		  
		  if theClass = "" then
		    html = "<ul>"
		  else
		    html = "<ul class=" + QUOTE + theClass + QUOTE + ">" 
		  end if
		  
		  for each child in item.children
		    if child.children.Ubound < 0 then
		      html = html + "<li" + if(child.cssClass <> "", " class=" + QUOTE + child.cssClass + QUOTE, "") + _
		      "><a href=" + QUOTE + child.url + QUOTE + ">"+ child.title + "</a></li>"
		    else
		      html = html + "<li" + if(child.cssClass <> "", " class=" + QUOTE + child.cssClass + QUOTE, "") + _
		      "><a href=" + QUOTE + child.url + QUOTE + ">"+ child.title + "</a>" + child.NavItemToHTML + "</li>"
		    end if
		  next child
		  
		  return html + "</ul>"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function OutputPathForPost(p as Strike3.Post) As FolderItem
		  ' Returns the FolderItem for where this post should be rendered to in the output folder.
		  
		  dim section as String
		  dim sections() as String = p.section.Split(".")
		  dim destination as FolderItem = publicFolder
		  
		  if p.section = "" then return publicFolder.Child(p.slug + ".html")
		  
		  for each section in sections
		    destination = destination.Child(section)
		    if not destination.Exists then raise New Error(CurrentMethodName, "Output destination `" + _
		    destination.NativePath + "` does not exist.")
		  next section
		  
		  return destination.Child(p.slug + ".html")
		  
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
		    "` is not valid.")
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
		Private Function PostCountForSection(section as String) As Integer
		  ' Returns the number of posts in the specified section.
		  ' `section` should be dot-delimited (e.g: blog.personal for posts in content/blog/personal).
		  
		  dim rs as RecordSet
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    rs = db.SQLSelect("SELECT COUNT(*) FROM posts WHERE section='" + section + "';")
		  else
		    rs = db.SQLSelect("SELECT COUNT(*) FROM posts WHERE section='" + section + "' " + _
		    "AND draft=0;")
		  end if
		  
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  if rs = Nil or rs.EOF = True then
		    return 0
		  else
		    return rs.Field("COUNT(*)").IntegerValue
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub ReallyDelete(what as FolderItem)
		  dim lastErr, itemCount as Integer
		  dim files(), dirs(), f as FolderItem
		  
		  if what = Nil or not what.Exists then return ' Nothing to do.
		  
		  ' Collect the folder‘s contents first.
		  ' This is faster than collecting them in reverse order and deleting them right away!
		  itemCount = what.Count
		  for i as Integer = 1 to itemCount
		    f = what.TrueItem(i)
		    if f <> Nil then
		      if f.Directory then
		        dirs.Append(f)
		      else
		        files.Append(f)
		      end if
		    end if
		  next i
		  
		  ' Now delete the files.
		  for each f in files
		    f.Delete()
		    lastErr = f.LastErrorCode ' Check if an error occurred.
		    if lastErr <> 0 then
		      ' Cancel the deletion and raise an error.
		      raise new Error(CurrentMethodName, "Unable to delete `" + f.Name + "`.")
		    end if
		  next f
		  
		  redim files(-1) ' Free the memory used by the files array before we enter recursion.
		  
		  ' Now delete the directories.
		  for each f in dirs
		    try
		      ReallyDelete(f)
		    catch err as Error
		      ' Cancel the deletion and propagate the error.
		      raise new Error(CurrentMethodName, "Unable to delete `" + f.Name + "`.")
		    end try
		  next f
		  
		  ' The folder should be empty and we can delete it.
		  what.Delete()
		  
		  if what.LastErrorCode <> 0 then
		    raise new Error(CurrentMethodName, "Unable to delete `" + what.Name + "`.")
		  end if
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderArchivePage()
		  ' Renders the baseURL/archive/index.html page.
		  
		  dim templateFile, destination as FolderItem
		  dim result, tag, resolvedTag as String
		  dim rg as RegEx
		  dim match as RegExMatch
		  
		  ' Get the "archive.html" template file text to use to render this post.
		  templateFile = theme.Child("layouts").Child("archive.html")
		  if not templateFile.Exists then raise new Error(CurrentMethodName, _
		  "The `archive.html` template file is missing")
		  result = FileContents(templateFile)
		  
		  destination = publicFolder.Child("archive.html")
		  
		  ' Check there actually content in this template file.
		  if result = "" then
		    WriteToFile(destination, "")
		    return
		  end if
		  
		  ' Find the template tags within `result`.
		  rg = new RegEx
		  rg.SearchPattern = "{{\s?([^}]*)\s?}}"
		  
		  ' Analyse each one and replace.
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      ' Get the tag contents.
		      tag = match.SubExpressionString(0)
		      ' Resolve the contents of this tag.
		      resolvedTag = ResolveArchiveIndexTag(tag)
		      ' Replace tag with resolvedTag.
		      result = result.Replace(tag, resolvedTag)
		    end if
		  loop until match = Nil
		  
		  ' Write the contents to disk.
		  WriteToFile(destination, result.Trim)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderHomePage(p as Strike3.Post)
		  ' Renders the home page (content/index.md) as HTML to the /public folder.
		  
		  dim template as FolderItem
		  dim result, tag, resolvedTag as String
		  dim rg as RegEx
		  dim match as RegExMatch
		  
		  ' Get the "home.html" template file text to use to render the homepage.
		  template = theme.Child("layouts").Child("home.html")
		  if not template.Exists Then raise new Error(CurrentMethodName, "The `home.html` template file is missing.")
		  result = FileContents(template)
		  
		  ' Check there actually content in this template file.
		  if result = "" then
		    WriteToFile(publicFolder.Child("index.html"), "")
		    return
		  end if
		  
		  ' Find the template tags within `result`.
		  rg = new RegEx
		  rg.SearchPattern = "{{\s?([^}]*)\s?}}"
		  
		  ' Analyse each one and replace.
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      ' Get the tag contents.
		      tag = match.SubExpressionString(0)
		      ' Resolve the contents of this tag.
		      resolvedTag = ResolveSingleTag(tag, p)
		      ' Replace tag with resolvedTag.
		      result = result.Replace(tag, resolvedTag)
		    end if
		  loop until match = Nil
		  
		  ' Write the contents to disk.
		  WriteToFile(publicFolder.Child("index.html"), result.Trim)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderHomePageList()
		  ' List all site posts.
		  
		  dim template as String
		  dim rs as RecordSet
		  dim postCount, currentPage, numListPages as Integer
		  dim postsPerPage as Integer = config.Value("postsPerPage")
		  dim templateFile, destination, pageFolder as FolderItem
		  dim a, prevNum, nextNum as Integer
		  dim context as Strike3.ListContext
		  
		  ' How many posts are in this section?
		  postCount = SitePostCount()
		  
		  if postCount = 0 then
		    raise new Error(CurrentMethodName, "There are no posts to render.")
		  end if
		  
		  ' Get a reference to the parent folder that will contain this section's list pages.
		  destination = publicFolder
		  
		  ' Get the "list.html" template file text to use to render this list page.
		  templateFile = GetTemplateListFile("")
		  template = FileContents(templateFile)
		  
		  ' As we know how many posts to list per page and we know how many posts there are, we can 
		  ' calculate how many list pages we need.
		  numListPages = Ceil(postCount/postsPerPage)
		  
		  ' Construct any required pagination folders.
		  if numListPages > 1 then
		    pageFolder = destination.Child("page")
		    pageFolder.CreateAsFolder()
		    for a = 2 to numListPages
		      pageFolder.Child(Str(a)).CreateAsFolder()
		    next a
		  end if
		  
		  ' Get all posts belonging to this section, ordered by published date, paginated and render them.
		  for currentPage = 1 to numListPages
		    rs = db.SQLSelect(SQL.AllPosts(postsPerPage, currentPage))
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		    if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil.")
		    
		    ' Create the context for this list page.
		    context = new Strike3.ListContext
		    if numListPages = 1 then ' Only one page.
		      context.prevPage = ""
		      context.nextPage = ""
		    else ' Multiple pages.
		      if currentPage = numListPages then ' Last page of multiple pages.
		        prevNum = currentPage - 1
		        if prevNum = 1 then
		          context.prevPage = destination.Child("index.html").ToPermalink
		        else
		          context.prevPage = destination.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = ""
		      elseif currentPage = 1 then ' First page of multiple pages.
		        context.prevPage = ""
		        nextNum = currentPage + 1
		        context.nextPage = destination.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      else ' Not the first or last of multiple pages.
		        prevNum = currentPage - 1
		        nextNum = currentPage + 1
		        if prevNum = 1 then
		          context.prevPage = destination.Child("index.html").ToPermalink
		        else
		          context.prevPage = destination.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = destination.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      end if
		    end if
		    
		    RenderListPage(rs, context, currentPage, template, destination)
		  next currentPage
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderList(sectionFolder as FolderItem)
		  ' Renders the list page(s) for the specified section as HTML to the /public folder.
		  
		  dim s, section, sections(), template as String
		  dim rs as RecordSet
		  dim postCount, currentPage, numListPages as Integer
		  dim postsPerPage as Integer = config.Value("postsPerPage")
		  dim templateFile, destination, pageFolder as FolderItem
		  dim a, prevNum, nextNum as Integer
		  dim context as Strike3.ListContext
		  
		  ' Convert the passed section folder into a dot-delimited path (as stored in the database).
		  section = FolderAsSection(sectionFolder)
		  
		  ' How many posts are in this section?
		  postCount = PostCountForSection(section)
		  if postCount = 0 then
		    if sectionFolder.NativePath = root.Child("content").NativePath then
		      ' No static home page defined and no posts within the content folder. Need to list all posts.
		      RenderHomePageList()
		    else
		      raise new Error(CurrentMethodName, "There is no content in `" + sectionFolder.NativePath + "`.")
		    end if
		  end if
		  
		  ' Get a reference to the parent folder that will contain this section's list pages.
		  destination = publicFolder
		  sections = section.Split(".")
		  if sections.Ubound < 0 then sections.Append("")
		  if sections(0) <> "" then
		    for each s in sections
		      destination = destination.Child(s)
		    next s
		  end if
		  if not destination.Exists then raise new Error(CurrentMethodName, _
		  "The destination for section `" + section + "` does not exist.")
		  
		  ' Get the "list.html" template file text to use to render this list page.
		  templateFile = GetTemplateListFile(section)
		  template = FileContents(templateFile)
		  
		  ' As we know how many posts to list per page and we know how many posts there are, we can 
		  ' calculate how many list pages we need
		  numListPages = Ceil(postCount/postsPerPage)
		  
		  ' Construct any required pagination folders
		  if numListPages > 1 then
		    pageFolder = destination.Child("page")
		    pageFolder.CreateAsFolder()
		    for a = 2 to numListPages
		      pageFolder.Child(a.ToText).CreateAsFolder()
		    next a
		  end if
		  
		  ' Get all posts belonging to this section, ordered by published date, paginated and render them.
		  for currentPage = 1 to numListPages
		    rs = db.SQLSelect(SQL.PostsForSection(section, postsPerPage, currentPage))
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		    if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil.")
		    
		    ' Create the context for this list page.
		    context = new Strike3.ListContext
		    if numListPages = 1 then ' Only one page.
		      context.prevPage = ""
		      context.nextPage = ""
		    else ' Multiple pages.
		      if currentPage = numListPages then ' Last page of multiple pages.
		        prevNum = currentPage - 1
		        if prevNum = 1 then
		          context.prevPage = destination.Child("index.html").ToPermalink
		        else
		          context.prevPage = destination.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = ""
		      elseif currentPage = 1 then ' First page of multiple pages.
		        context.prevPage = ""
		        nextNum = currentPage + 1
		        context.nextPage = destination.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      else ' Not the first or last of multiple pages.
		        prevNum = currentPage - 1
		        nextNum = currentPage + 1
		        if prevNum = 1 then
		          context.prevPage = destination.Child("index.html").ToPermalink
		        else
		          context.prevPage = destination.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = destination.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      end if
		    end if
		    
		    RenderListPage(rs, context, currentPage, template, destination)
		  next currentPage
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderListPage(rs as RecordSet, context as Strike3.ListContext, pageNumber as Integer, template as String, enclosingFolder as FolderItem)
		  /// ------------------------------------------------------------------------------------------------
		  ' Takes a RecordSet of posts from our database that should be rendered as a list page.
		  ' `pageNumber` is the page number for this collection of posts and `totalNumPages` is the total 
		  ' number of pages that make up this section's list.
		  ' E.g: if we have 10 posts in a section and we are displaying 3 posts per page then `totalNumPages`
		  ' would be 4 (as we need 4 pages: 1/2/3, 4/5/6, 7/8/9 and 10)
		  ' Assumes that RecordSet is not Nil.
		  ' `template` is the text contents of the "list.html" file to use to render this page (also assumed not Nil).
		  
		  ' `enclosingFolder` is the folder in the built site that contains the list index and page subfolders
		  ' E.g: If there are 3 list pages for blog/personal then `enclosingFolder` will be set to /public/blog/personal
		  ' and we have the following structure:
		  ' /public/blog/personal
		  '   index.html      <-- page 1 list contents
		  '   page/2/index.html
		  '   page/3/index.html
		  /// ------------------------------------------------------------------------------------------------
		  
		  dim pageFile as FolderItem
		  dim post, posts() as Post
		  dim rg, rgLoop as RegEx
		  dim match, matchLoop as RegExMatch
		  dim result, rawLoop, loopContents, pageLoop, tag, resolvedTag, resolvedLoop as String
		  dim startIndex as Integer
		  
		  ' Get a reference to the FolderItem on disk where we'll store the finished page.
		  if pageNumber = 1 then
		    pageFile = enclosingFolder.Child("index.html")
		  else
		    pageFile = enclosingFolder.Child("page").Child(Str(pageNumber)).Child("index.html")
		  end if
		  
		  ' Convert this RecordSet to an array of posts.
		  try
		    while not rs.EOF
		      posts.Append(Post.FromRecordSet(rs))
		      rs.MoveNext()
		    wend
		  catch err as RuntimeException
		    raise new Error(CurrentMethodName, _
		    "An error occured whilst trying to convert a RecordSet to Post instance.")
		  end try
		  
		  ' Resolve any for each loops.
		  ' These are blocks of templating code that need to be run for each post in posts()
		  ' Syntax:
		  ' {{foreach}}
		  '     Any valid templating code
		  ' {{endeach}}
		  rg = new RegEx
		  rg.SearchPattern = "{{foreach}}[\s\S]*?{{endeach}}"
		  
		  result = template
		  
		  ' Check there is actually content in this template file.
		  if result = "" then
		    WriteToFile(pageFile, "")
		    return
		  end if
		  
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      rawLoop = match.SubExpressionString(0)
		      
		      ' Store the character position of the start of this loop
		      startIndex = match.SubExpressionStartB(0)
		      
		      ' Found a loop. Remove the {{foreach}} and {{endeach}} to get the loop contents
		      loopContents = rawLoop.Replace("{{foreach}}", "").Trim
		      loopContents = loopContents.Left(loopContents.Len - 11).Trim
		      
		      ' Now look for tags in this loop
		      rgLoop = new RegEx
		      rgLoop.SearchPattern = "{{\s?([^}]*)\s?}}"
		      
		      ' For each post, we need to resolve the loopContents
		      for each post in posts
		        
		        rgLoop = new RegEx
		        rgLoop.SearchPattern = "{{\s?([^}]*)\s?}}"
		        
		        pageLoop = loopContents
		        
		        ' Analyse each one and replace.
		        do
		          matchLoop = rgLoop.Search(pageLoop)
		          if matchLoop <> Nil then
		            ' Get the tag contents.
		            tag = matchLoop.SubExpressionString(0)
		            ' Resolve the contents of this tag.
		            resolvedTag = ResolveListTag(tag, post, context)
		            ' Replace tag with resolvedTag.
		            pageLoop = pageLoop.Replace(tag, resolvedTag)
		          end if
		        loop Until matchLoop = Nil
		        
		        resolvedLoop = resolvedLoop + pageLoop
		        
		      next post
		      
		      ' Insert the resolved loop at the start index of the rawLoop.
		      result = result.Insert(resolvedLoop, startIndex)
		      
		    end if
		    
		    ' Remove this raw loop.
		    try
		      result = result.Replace(rawLoop, "")
		    catch
		      ' Move along.
		    end try
		    
		  loop until match = Nil
		  
		  ' Now resolve any other tags outside of a loop.
		  rg = new RegEx
		  rg.SearchPattern = "{{\s?([^}]*)\s?}}"
		  
		  ' Analyse each one and replace.
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      ' Get the tag contents.
		      tag = match.SubExpressionString(0)
		      ' Resolve the contents of this tag.
		      resolvedTag = ResolveListTag(tag, post, context)
		      ' Replace tag with resolvedTag.
		      result = result.Replace(tag, resolvedTag)
		    end if
		  loop until match = Nil
		  
		  result = result.Trim
		  
		  ' Write the result to disk
		  WriteToFile(pageFile, result.Trim)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderPage(p as Strike3.Post)
		  ' Renders an individual page as HTML to the /public folder.
		  
		  dim template as FolderItem
		  dim result, tag, resolvedTag as String
		  dim rg as RegEx
		  dim match as RegExMatch
		  
		  ' Get the "page.html" template file text to use to render this post.
		  template = GetTemplateFile("page", p)
		  result = FileContents(template)
		  
		  ' Check there actually content in this template file.
		  if result = "" then
		    WriteToFile(OutputPathForPost(p), "")
		    return
		  end if
		  
		  ' Find the template tags within `result`.
		  rg = new RegEx
		  rg.SearchPattern = "{{\s?([^}]*)\s?}}"
		  
		  ' Analyse each one and replace.
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      ' Get the tag contents.
		      tag = match.SubExpressionString(0)
		      ' Resolve the contents of this tag.
		      resolvedTag = ResolveSingleTag(tag, p)
		      ' Replace tag with resolvedTag.
		      result = result.Replace(tag, resolvedTag)
		    end if
		  loop until match = Nil
		  
		  ' Write the contents to disk.
		  WriteToFile(OutputPathForPost(p), result.Trim)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderPost(p as Strike3.Post)
		  ' Renders an individual post as HTML to the /public folder.
		  
		  dim template as FolderItem
		  dim result, tag, resolvedTag as String
		  dim rg as RegEx
		  dim match as RegExMatch
		  
		  ' Get the "post.html" template file text to use to render this post.
		  template = GetTemplateFile("post", p)
		  result = FileContents(template)
		  
		  ' Check there actually content in this template file.
		  if result = "" then
		    WriteToFile(OutputPathForPost(p), "")
		    return
		  end if
		  
		  ' Find the template tags within `result`.
		  rg = new RegEx
		  rg.SearchPattern = "{{\s?([^}]*)\s?}}"
		  
		  ' Analyse each one and replace.
		  do
		    match = rg.Search(result)
		    if match <> Nil then
		      ' Get the tag contents.
		      tag = match.SubExpressionString(0)
		      ' Resolve the contents of this tag.
		      resolvedTag = ResolveSingleTag(tag, p)
		      ' Replace tag with resolvedTag.
		      result = result.Replace(tag, resolvedTag)
		    end if
		  loop until match = Nil
		  
		  ' Write the contents to disk.
		  WriteToFile(OutputPathForPost(p), result.Trim)
		  
		  ' Add this page to rssItems (if desired).
		  if config.Value("rss") then rssItems.Append(new Strike3.RSSItem(p.title, p.url, p.date, p.Summary))
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderPosts()
		  ' Renders the posts in the site database to HTML with the current theme.
		  
		  using Xojo.Core
		  
		  dim rs as RecordSet
		  dim p as Strike3.Post
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  ' Get the posts as a RecordSet.
		  if buildDrafts then
		    rs = db.SQLSelect("SELECT * FROM posts WHERE verified=1 AND date <= " + Date.Now.SecondsFrom1970.ToText + ";")
		  else
		    rs = db.SQLSelect("SELECT * FROM posts WHERE verified=1 AND draft=0 AND date <= " + Date.Now.SecondsFrom1970.ToText + ";")
		  end if
		  if rs = Nil or rs.EOF then return ' No posts to render.
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  
		  while not rs.EOF
		    p = Post.FromRecordSet(rs)
		    
		    if p.homepage then
		      RenderHomePage(p)
		    elseif p.page then 
		      RenderPage(p)
		    else
		      RenderPost(p)
		    end if
		    
		    rs.MoveNext()
		  wend
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RenderTag(tagName as String, tagFolder as FolderItem)
		  ' Renders the tag list files/folders for the passed tag
		  ' tagFolder is the parent folder for this tag, e.g: the 'happy' tag parent folder is:
		  '         baseURL/tag/happy/
		  
		  dim rs as RecordSet
		  dim postCount, numListPages, currentPage, a, prevNum, nextNum as Integer
		  dim templateFile, pageFolder as FolderItem
		  dim template as String
		  dim postsPerPage as Integer = config.Value("postsPerPage")
		  dim context as ListContext
		  
		  ' How many posts have this tag?
		  rs = db.SQLSelect(SQL.PostCountForTag(tagName))
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil")
		  postCount = rs.Field("total").IntegerValue
		  
		  ' Get the "tags.html" template file text to use to render the tag list page(s).
		  templateFile = theme.Child("layouts").Child("tags.html")
		  if not templateFile.Exists then raise new Error(CurrentMethodName, _
		  "The `tags.html` template file is missing.")
		  template = FileContents(templateFile)
		  
		  ' As we know how many posts to list per page and we know how many posts there are, we can 
		  ' calculate how many list pages we need.
		  numListPages = Ceil(postCount/postsPerPage)
		  
		  ' Construct any required pagination folders.
		  if numListPages > 1 then
		    pageFolder = tagFolder.Child("page")
		    pageFolder.CreateAsFolder()
		    for a = 2 to numListPages
		      pageFolder.Child(Str(a)).CreateAsFolder()
		    next a
		  end if
		  
		  ' Get all posts with this tag, ordered by published date, paginated and render them.
		  for currentPage = 1 to numListPages
		    rs = db.SQLSelect(SQL.PostsForTag(tagName, postsPerPage, currentPage))
		    if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		    if rs = Nil then raise new Error(CurrentMethodName, "rs = Nil")
		    
		    ' Create the context for this list page.
		    context = new ListContext
		    if numListPages = 1 then ' Only one page.
		      context.prevPage = ""
		      context.nextPage = ""
		    else ' Multiple pages.
		      if currentPage = numListPages then ' Last page of multiple pages.
		        prevNum = currentPage - 1
		        if prevNum = 1 Then
		          context.prevPage = tagFolder.Child("index.html").ToPermalink
		        else
		          context.prevPage = tagFolder.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = ""
		      elseif currentPage = 1 then ' First page of multiple pages.
		        context.prevPage = ""
		        nextNum = currentPage + 1
		        context.nextPage = tagFolder.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      else ' Not the first or last of multiple pages.
		        prevNum = currentPage - 1
		        nextNum = currentPage + 1
		        if prevNum = 1 then
		          context.prevPage = tagFolder.Child("index.html").ToPermalink
		        else
		          context.prevPage = tagFolder.Child("page").Child(Str(prevNum)).Child("index.html").ToPermalink
		        end if
		        context.nextPage = tagFolder.Child("page").Child(Str(nextNum)).Child("index.html").ToPermalink
		      end if
		    end if
		    context.tag = tagName
		    
		    RenderListPage(rs, context, currentPage, template, tagFolder)
		  next currentPage
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ResolveArchiveIndexTag(tag as String) As String
		  ' Takes a tag from the archives.html page in the form {{something}} and resolves it to 
		  ' a string value.
		  
		  dim partialName as String
		  dim partialFile as FolderItem
		  
		  ' Remove the starting {{ and trailing }}.
		  tag = tag.Right(tag.Len - 2)
		  tag = tag.Left(tag.Len - 2)
		  
		  ' ------------------------------------------------------
		  ' {{partial FILE-NAME}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "partial" then
		    partialName = tag.Replace("partial", "").Trim ' The name of the partial file to include.
		    try
		      ' Does this file exist in the current theme?
		      partialFile = theme.Child("layouts").Child("partials").Child(partialName + ".html")
		      return FileContents(partialFile) ' Yep.
		    catch ' Nope.
		      raise new Error(CurrentMethodName, "Cannot locate the partial template file `" + partialName + "`.")
		    end try
		  end if
		  
		  ' ------------------------------------------------------
		  ' {{assets}}
		  ' ------------------------------------------------------
		  if tag = "assets" then return SpecialURL("assets")
		  
		  ' ------------------------------------------------------
		  ' {{navigation}}
		  ' ------------------------------------------------------
		  if tag = "navigation" then return siteNavigationHTML
		  
		  ' ------------------------------------------------------
		  ' RSS feed tag?
		  ' {{feedURL}}
		  ' ------------------------------------------------------
		  if tag = "feedURL" then return baseURL + "rss.xml"
		  
		  ' ------------------------------------------------------
		  ' Site data?
		  ' {{site.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 5 and tag.Left(5) = "site." then return SiteTag(tag.Replace("site.", ""))
		  
		  ' ------------------------------------------------------
		  ' Helper tag?
		  ' {{helper.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "helper." then return HelperTag(tag.Replace("helper.", ""))
		  
		  ' ------------------------------------------------------
		  ' Strike3 tag?
		  ' {{strike3.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 8 and tag.Left(8) = "strike3." then return Strike3Tag(tag.Replace("strike3.", ""))
		  
		  ' ------------------------------------------------------
		  ' Archives tag?
		  ' {{archives.VALUE}}
		  ' ------------------------------------------------------
		  if tag = "archives.months" then return archiveMonthsHTML
		  if tag = "archives.longMonths" then return archiveLongMonthsHTML
		  if tag = "archives.url" then return publicFolder.Child("archive.html").ToPermalink
		  
		  raise new Error(CurrentMethodName, "Unknown post tag `{{" + tag + "}}`.")
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ResolveListTag(tag as String, post as Strike3.Post, context as Strike3.ListContext) As String
		  ' Takes a tag from a list page in the form {{something}} and resolves it to a String value.
		  
		  dim partialName as String
		  dim partialFile as FolderItem
		  
		  ' Remove the starting {{ and trailing }}.
		  tag = tag.Right(tag.Len - 2)
		  tag = tag.Left(tag.Len - 2)
		  
		  ' ------------------------------------------------------
		  ' {{partial FILE-NAME}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "partial" then
		    partialName = tag.Replace("partial", "").Trim ' The name of the partial file to include.
		    try
		      ' Does this file exist in the current theme?
		      partialFile = theme.Child("layouts").Child("partials").Child(partialName + ".html")
		      return FileContents(partialFile) ' Yep.
		    catch ' Nope.
		      raise new Error(CurrentMethodName, "Cannot locate the partial template file `" + partialName + "`.")
		    end try
		  end if
		  
		  ' ------------------------------------------------------
		  ' {{assets}}
		  ' ------------------------------------------------------
		  if tag = "assets" then return SpecialURL("assets")
		  
		  ' ------------------------------------------------------
		  ' {{navigation}}
		  ' ------------------------------------------------------
		  if tag = "navigation" then return siteNavigationHTML
		  
		  ' ------------------------------------------------------
		  ' RSS feed tag?
		  ' {{feedURL}}
		  ' ------------------------------------------------------
		  if tag = "feedURL" then return baseURL + "rss.xml"
		  
		  ' ------------------------------------------------------
		  ' Site data?
		  ' {{site.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 5 and tag.Left(5) = "site." then return SiteTag(tag.Replace("site.", ""))
		  
		  ' ------------------------------------------------------
		  ' Helper tag?
		  ' {{helper.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "helper." then return HelperTag(tag.Replace("helper.", ""))
		  
		  ' ------------------------------------------------------
		  ' Maebh tag?
		  ' {{maebh.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 8 And tag.Left(8) = "strike3." then return Strike3Tag(tag.Replace("strike3.", ""))
		  
		  ' ------------------------------------------------------
		  ' Archives tag?
		  ' {{archives.VALUE}}
		  ' ------------------------------------------------------
		  if tag = "archives.months" then return archiveMonthsHTML
		  if tag = "archives.longMonths" then return archiveLongMonthsHTML
		  if tag = "archives.url" then return publicFolder.Child("archive.html").ToPermalink
		  
		  ' ------------------------------------------------------
		  ' Specialist list tag?
		  ' {{list.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 5 and tag.Left(5) = "list." then
		    tag = tag.Replace("list.", "")
		    if tag = "tag" then return context.tag
		  end if
		  
		  ' ------------------------------------------------------
		  ' List tags
		  ' ------------------------------------------------------
		  if tag = "content" then return post.contents
		  if tag = "date" then return post.date.ToText
		  if tag = "date.second" then return if(post.date.Second < 10, "0" + Str(post.date.Second), Str(post.date.Second))
		  if tag = "date.minute" then return if(post.date.Minute < 10, "0" + Str(post.date.Minute), Str(post.date.Minute))
		  if tag = "date.hour" then return if(post.date.Hour < 10, "0" + Str(post.date.Hour), Str(post.date.Hour))
		  if tag = "date.day" then return Str(post.date.Day)
		  if tag = "date.month" then return Str(post.date.Month)
		  if tag = "date.longMonth" then return post.date.LongMonth
		  if tag = "date.shortMonth" then return post.date.ShortMonth
		  if tag = "date.year" then return Str(post.date.Year)
		  if tag = "nextPage" then return context.nextPage
		  if tag = "prevPage" then return context.prevPage
		  if tag = "title" then return post.title
		  if tag = "permalink" then return post.url
		  if tag = "readingTime" then return post.contents.TimeToRead
		  if tag = "summary" then return post.Summary
		  if tag = "title" then return post.title
		  if tag = "wordCount" then return post.contents.WordCount.ToText
		  if tag = "tags" then return post.TagsAsHTML
		  
		  raise new Error(CurrentMethodName, "Unknown tag '{{" + tag + "}}'")
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ResolveSingleTag(tag as String, post as Strike3.Post) As String
		  ' Tags a tag from a post (homepage, page or post)in the form {{something}} and resolves it to 
		  ' a string value.
		  
		  dim partialName as String
		  dim partialFile as FolderItem
		  
		  ' Remove the starting {{ and trailing }}.
		  tag = tag.Right(tag.Len - 2)
		  tag = tag.Left(tag.Len - 2)
		  
		  ' ------------------------------------------------------
		  ' {{partial FILE-NAME}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "partial" then
		    partialName = tag.Replace("partial", "").Trim ' The name of the partial file to include.
		    try
		      ' Does this file exist in the current theme?
		      partialFile = theme.Child("layouts").Child("partials").Child(partialName + ".html")
		      return FileContents(partialFile) ' Yep.
		    catch ' Nope.
		      raise new Error(CurrentMethodName, "Cannot locate the partial template file `" + partialName + "`.")
		    end try
		  end if
		  
		  ' ------------------------------------------------------
		  ' {{assets}}
		  ' ------------------------------------------------------
		  if tag = "assets" then return SpecialURL("assets")
		  
		  ' ------------------------------------------------------
		  ' {{navigation}}
		  ' ------------------------------------------------------
		  if tag = "navigation" then return siteNavigationHTML
		  
		  ' ------------------------------------------------------
		  ' RSS feed tag?
		  ' {{feedURL}}
		  ' ------------------------------------------------------
		  if tag = "feedURL" then return baseURL + "rss.xml"
		  
		  ' ------------------------------------------------------
		  ' Site data?
		  ' {{site.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 5 and tag.Left(5) = "site." then return SiteTag(tag.Replace("site.", ""))
		  
		  ' ------------------------------------------------------
		  ' Helper tag?
		  ' {{helper.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 7 and tag.Left(7) = "helper." then return HelperTag(tag.Replace("helper.", ""))
		  
		  ' ------------------------------------------------------
		  ' Strike3 tag?
		  ' {{strike3.VALUE}}
		  ' ------------------------------------------------------
		  if tag.Len >= 8 and tag.Left(8) = "strike3." then return Strike3Tag(tag.Replace("strike3.", ""))
		  
		  ' ------------------------------------------------------
		  ' Archives tag?
		  ' {{archives.VALUE}}
		  ' ------------------------------------------------------
		  if tag = "archives.months" then return archiveMonthsHTML
		  if tag = "archives.longMonths" then return archiveLongMonthsHTML
		  if tag = "archives.url" then return publicFolder.Child("archive.html").ToPermalink
		  
		  ' ------------------------------------------------------
		  ' Post-specific tags posts
		  ' ------------------------------------------------------
		  if tag = "content" then return post.contents
		  if tag = "date" then return post.date.ToText
		  if tag = "date.second" then return If(post.date.Second < 10, "0" + Str(post.date.Second), Str(post.date.Second))
		  if tag = "date.minute" then return If(post.date.Minute < 10, "0" + Str(post.date.Minute), Str(post.date.Minute))
		  if tag = "date.hour" then return if(post.date.Hour < 10, "0" + Str(post.date.Hour), Str(post.date.Hour))
		  if tag = "date.day" then return Str(post.date.Day)
		  if tag = "date.month" then return Str(post.date.Month)
		  if tag = "date.longMonth" then return post.date.LongMonth
		  if tag = "date.shortMonth" then return post.date.ShortMonth
		  if tag = "date.year" then return Str(post.date.Year)
		  if tag = "permalink" then return post.url
		  if tag = "readingTime" then return post.contents.TimeToRead
		  if tag = "summary" then return post.Summary
		  if tag = "title" then return post.title
		  if tag = "wordCount" then return Str(post.contents.WordCount)
		  if tag = "tags" then return post.TagsAsHTML()
		  
		  ' ------------------------------------------------------
		  ' Post data?
		  ' ------------------------------------------------------
		  if post.data <> Nil and post.data.HasKey("tag") then return post.data.Value("tag")
		  
		  raise new Error(CurrentMethodName, "Unknown post tag `{{" + tag + "}}`.")
		  
		End Function
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
		Private Function ShortMonth(extends d as Xojo.Core.Date) As String
		  ' returns the month of the passed date in short form.
		  
		  if d = Nil then
		    return ""
		  else
		    select case d.Month
		    case 1
		      return "Jan"
		    case 2
		      return "Feb"
		    case 3
		      return "Mar"
		    case 4
		      return "Apr"
		    case 5
		      return "May"
		    case 6
		      return "Jun"
		    case 7
		      return "Jul"
		    case 8
		      return "Aug"
		    case 9
		      return "Sep"
		    case 10
		      return "Oct"
		    case 11
		      return "Nov"
		    case 12
		      return "Dec"
		    else
		      return ""
		    end select
		  end if
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function SitePostCount() As Integer
		  ' Returns the number of posts in the site.
		  
		  dim rs as RecordSet
		  dim buildDrafts as Boolean = config.Lookup("buildDrafts", True)
		  
		  if buildDrafts then
		    rs = db.SQLSelect("SELECT COUNT(*) FROM posts WHERE page=0;")
		  else
		    rs = db.SQLSelect("SELECT COUNT(*) FROM posts WHERE page=0 AND draft=0;")
		  end if
		  
		  if db.Error then raise new Error(CurrentMethodName, db.ErrorMessage)
		  if rs = Nil or rs.EOF = True then
		    return 0
		  else
		    return rs.Field("COUNT(*)").IntegerValue
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function SiteTag(name as String) As String
		  ' Returns (as Text) the requested site data.
		  ' The value Of any variable in the site’s config.json file can be retrieved from any template file 
		  ' with the tag {{site.VARIABLE_NAME}}, this includes user-defined variables. This is the prefered 
		  ' method To set global data values.
		  ' For example, To get the base URL Of the entire site from within a template file, simply use the 
		  ' tag {{site.baseURL}}
		  
		  if config.HasKey(name) then
		    return config.Value(name)
		  else
		    raise new Error(CurrentMethodName, "Unknown site value `site." + name + "`.")
		  end if
		  
		End Function
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
		Private Function SpecialURL(name as String) As String
		  ' Returns the requested special URL.
		  ' Strike3 has a number of special URLs such as theme assets, RSS feed, archives, etc
		  
		  select case name
		  case "assets"
		    return baseURL + "assets"
		  end select
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function Strike3Tag(value as String) As String
		  ' Strike3 provides a number of generator-specific tags.
		  ' {{strike3.generator}} Meta tag For the version of Strike3 that built the site. 
		  '                     Example output: <meta name="generator" content="Strike3 0.9.0" />
		  ' {{strike3.version}}   Strike3’s version number
		  
		  const QUOTE = """"
		  
		  select case value
		  case "generator"
		    return "<meta name=" + QUOTE + "generator" + QUOTE + " content=" + QUOTE + "Strike3 " + _
		    Version() + QUOTE + "/>"
		  case "version"
		    return Version()
		  else
		    raise new Error(CurrentMethodName, "Unknown strike3 tag '{{strike3." + value + "}}'")
		  end select
		  
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
		Private Function TimeToRead(Extends s as String) As String
		  ' Returns the formatted estimated time to read this string content.
		  ' The maths is based on this post: 
		  ' http://marketingland.com/estimated-reading-times-increase-engagement-79830
		  
		  const WORDS_PER_MIN = 225
		  
		  dim time as Double
		  dim minutes, seconds as Integer
		  
		  time = s.WordCount/WORDS_PER_MIN
		  minutes = time
		  seconds = Ceil((time - minutes) * 0.6)
		  
		  if seconds > 30 then minutes = minutes + 1
		  if minutes <=0 then minutes = 1
		  
		  return Str(minutes) + " min read"
		  
		  
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
		Private Function ToModern(extends f as FolderItem) As Xojo.IO.FolderItem
		  ' Converts a classic framework FolderItem to the new framework.
		  
		  if f = Nil then return Nil
		  
		  return new Xojo.IO.FolderItem(f.NativePath.ToText)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToModernDate(extends d as Date) As Xojo.Core.Date
		  return new Xojo.Core.Date(d.Year, d.Month, d.Day, Xojo.Core.TimeZone.Current)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToPermalink(Extends f as FolderItem) As String
		  ' Returns what will be the public URL of the passed file.
		  
		  return if(baseURL.Right(1) = "/", baseURL.Left(baseURL.Length-1), baseURL) + _
		  f.NativePath.Replace(publicFolder.NativePath, "")
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

	#tag Method, Flags = &h21
		Private Function WordCount(extends s as String) As Integer
		  ' Returns the number of words in the passed string..
		  
		  Return s.Split().Ubound + 1
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub WriteToFile(file as FolderItem, contents as String)
		  ' Writes the passed String to the specified file.
		  
		  dim tout as TextOutputStream
		  
		  try
		    tout = TextOutputStream.Create(file)
		    tout.Write(contents)
		    tout.Close()
		  catch
		    raise new Error(CurrentMethodName, "Unable to write to `" + file.NativePath + "`.")
		  end try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function XmlNodeWithText(ByRef xml as XmlDocument, ByRef parentNode as XmlNode, nodeTitle as String, textToAdd as String) As XmlNode
		  /// ------------------------------------------------------------------------------------------------
		  ' Convenience method for adding a text node to the specified parent node.
		  /// ------------------------------------------------------------------------------------------------
		  
		  dim node as XmlNode
		  dim textNode as XmlTextNode
		  
		  if xml = Nil or parentNode = Nil then return Nil
		  
		  node = parentNode.AppendChild(xml.CreateElement(nodeTitle))
		  textNode = xml.CreateTextNode(nodeTitle)
		  textNode.Value = textToAdd
		  node.AppendChild(textNode)
		  
		  return node
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private archiveLongMonthsHTML As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private archiveMonthsHTML As String
	#tag EndProperty

	#tag Property, Flags = &h21
		#tag Note
			Computed within BuildArchives() and used to generate the archives <ul> HTML
		#tag EndNote
		Private archiveTree() As Strike3.ArchiveYear
	#tag EndProperty

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
		Private rssItems() As Strike3.RSSItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private siteNavigationHTML As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private siteNavTree As Strike3.NavigationItem
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

	#tag Constant, Name = DEFAULT_RSS, Type = Boolean, Dynamic = False, Default = \"False", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_SITE_TITLE, Type = Text, Dynamic = False, Default = \"My Website", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DEFAULT_THEME_NAME, Type = Text, Dynamic = False, Default = \"primary", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = REGEX_STRIP_HTML, Type = String, Dynamic = False, Default = \"<(\?:[^>\x3D]|\x3D\'[^\']*\'|\x3D\"[^\"]*\"|\x3D[^\'\"][^\\s>]*)*>", Scope = Private
	#tag EndConstant

	#tag Constant, Name = VERSION_BUG, Type = Double, Dynamic = False, Default = \"3", Scope = Public
	#tag EndConstant

	#tag Constant, Name = VERSION_MAJOR, Type = Double, Dynamic = False, Default = \"0", Scope = Public
	#tag EndConstant

	#tag Constant, Name = VERSION_MINOR, Type = Double, Dynamic = False, Default = \"9", Scope = Public
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
