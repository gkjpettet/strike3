# Strike3
This is the comprehensive guide to my static site generator.

### Table of contents
1. [Introduction](#intro)
2. [Installation](#installation)
3. [Quickstart](#quickstart)
4. [Configuration](#config)
5. [Content organisation](#content-organisation)
6. [Frontmatter](#frontmatter)
7. [Sections](#sections)
8. [Slugs](#slugs)
9. [Content example](#content-example)
10. [Themes oveview](#themes-overview)
11. [Using a theme](#using-a-theme)
12. [Creating a theme](#creating-a-theme)
13. [Disco](#disco)
14. [The context](#the-context)
15. [Variables](#variables)
16. [Single templates](#single-templates)
17. [List templates](#list-templates)
18. [Homepage](#homepage)
19. [Tags](#tags)
19. [Archives](#archives)
20. [Navigation](#navigation)
21. [Pagination](#pagination)
22. [RSS](#rss)

## <a id="intro">Introduction</a>
Strike3 is a static site generator. Put simply, Strike3 takes a folder of Markdown files and a theme (a collection of HTML files) and uses those to create a completely self-contained website.
Strike3 is the name of the engine (and my youngest daughter) and `strike3` is the name of the command line tool. It's written in [Xojo][xojo].

## <a id="installation">Installation</a>
**macOS**  
If you're using macOS you can use the excellent [Homebrew][homebrew] package manager to quickly install Strike3:
```
brew tap gkjpettet/homebrew-strike3
brew install strike3
```

You can make sure that you've always got the latest version of Strike3 by running `brew update` in the Terminal. You'll know there's an update available if you see the following:

```
==> Updated Formulae
gkjpettet/strike3/strike3 ✔
```

Then you'll know there's a new version available. To install it simply type `brew upgrade` in the Terminal. 

## <a id="quickstart">Quickstart</a>
This quick tutorial will get you up and started with a simple blog in no time. Our blog will list posts on the home page and contain just a single page. I'll assume you've already installed `strike3` as described above.

### Step 1: Create the basic site framework
Strike3 has a simple command for creating a new site that will create all the required files/folders for you to get working. Navigate the filesystem to where you want your site to be stored and execute the following command:

`$ strike3 create site my-blog`

If everything is well, you should see something like the following:

```
Success ✓
Your new site was created in /Users/xxx/Desktop/testing
A single post and a simple page have been created in /content. 
A simple default theme called 'primary' has been created for you in /themes.
Feel free to create your own with strike3 create theme [name].
```

You can check out the contents of your new site with `ls`:

`config.json   content   site.data   storage   themes`

As you can see, a Strike3 site has a very simple basic structure: three folders, a configuration file and a SQLite database. Let’s look at them one-by-one:

##### config.json
Every website must have a configuration file at its root in JSON format. The settings within config.json apply to the whole site. Required and valid options are detailed in the [configuration](#config) section. Additionally, you can provide site-wide data that's accessible from themes in this file.

##### content
As the name suggests, this is where you store the content of your website. Inside content you create folders for different sections. Let’s suppose our blog has three types of content: posts, reviews and tutorials. You would then create three folders in content titled `post`, `review` and `tutorial` (note I’ve used the singular form of the word as it looks better in the resultant URLs). The name of the section is important as it affects not only the final URL but also the styling applied to the page by the theme (as themes can style sections differently from one another if you wish). A simple blog doesn’t require any sections, you can just place Markdown files in the root of the content folder too if you wish.

##### site.data
This is a SQLite database which is used to cache your content for faster rendering. You shouldn't really ever need to edit this.

##### storage
Any file or folder you place in here will be copied to `/public/storage` in the built site. This is a good location to put images, etc.

##### themes
This is the folder to place themes you have created or downloaded. They are then applied by specifying their name in `config.json` (read more about themes [here](#themes)).

### Step 2: Add content
Helpfully, when creating a new site, Strike3 also creates some dummy content for us. Strike3 creates a post called `Hello World.md` in `/content` and a simple about page in `/content/about`. You can keep and edit these or delete them and add your own content. Just use your favourite editor (I use [Atom][atom]).

If you open up the sample post created by Strike3 (`/content/Hello World.md`), you’ll see an example of (optional) frontmatter which looks like this:

```
;;;
"title": "Hello World!"
;;;
```

Note the flanking three semicolons in the [frontmatter](#frontmatter) which separate it from your post content.

### Step 3: Set the theme
Every site needs a theme and Strike3 supports a comprehensive theming system. You can either create your own or download one made by our community. Helpfully, Strike3 provides a very simple theme to get you started called `primary`. Strike3 sets this as your site’s theme. Using a different theme is easy - just copy the theme folder to `/themes` in the site root and set the `theme` value in `config.json` to the theme name. You can read more about this [here](#themes).

### Step 4: Build the site
Building your site is quick and easy. Just navigate to the root of your site in Terminal and type: `strike3 build`:

```
Success ✓
Site built in 88 ms
```

### Step 5: Upload your site
Simply copy the contents of the `/public` folder created by the build command to the root of your web host and your site is live.

## <a id="config">Configuration</a>
Strike3 requires the presence of a configuration file in the root of the site directory named `config.json`. Not only does this contain a number of mandatory values needed by Strike3 to build your site but it can specify additional options and arbitrary data for your themes to use.

Below is the configuration file created by Strike3 when you run the `strike3 create site` command:

```
{
  "title":"my-blog",
  "theme":"",
  "archives":false,
  "rss":true,
  "baseURL":"\/",
  "description":"My great website",
  "postsPerPage":10
}
```
Omitting any of the values above will cause Strike3 to use it’s defaults. A list of all values controlling site creation recognised by Aoife are listed below:

```
archives:                   true
# Whether or not build archive listings (set to true if active theme demands it)

baseURL:                    "/"
# Hostname (and path) to the root, e.g. http://aoife.io

description:                "My great website"
# A description of the site. Used in some themes as a tagline

postsPerPage:               10
# The number of posts to show on listing pages

rss:                        false
# Whether or not to build an RSS feed at /rss.xml

theme:                      "primary"
# Theme name to use (this must be set to a valid theme in the /themes folder)

title:                      "My Website"
# Site title
```
I addition to the values above, you are free to add any other valid JSON key/value and this will be accessible by all template files in the active theme. For instance, you may want to set details about the site author:

`"author": "Garry Pettet"`

This would then be accesible from a theme template file with the tag `{{site.author}}`.

## <a id="content-organisation">Content organisation</a>
Content in a Strike3 site comprises Markdown text files with the extension `.md`. These files can have optional information at the very beginning called the [frontmatter](#frontmatter). Strike3 respects the hierarchical file/folder organisation you provide for your content to simplify things.

Strike3 expects your content to be arranged on disk in the same way you want it to appear in the final rendered website. Without any additional configuration on your part, the following source organisation will just work and provide a functioning website:

```
content
  - about
  --- index.md            // http://mysite.com/about
  - post
  --- First Post.md       // http://mysite.com/post/first-post.html
  --- Second Post.md      // http://mysite.com/post/second-post.html
  --- sub-section
  ------ Third Post.md    // http://mysite.com/post/sub-section/third-post.html
  - review
  --- Die Hard.md         // http://mysite.com/review/die-hard.html
```

You can nest content at any level but the top level folders within the `/content` folder are special and are either [sections](#sections) or **pages**.

### Structure
It makes sense that the way you store your files on disk is the way you want them displayed to the user in the final rendered website. As displayed above, the organisation of your source content will be mirrored in the URL of your site. Notice that the top level `/about` page URL was created using a directory named `about` with a single `index.md` file inside. This is the organisation format you should use to create a single page. Creating a top-level folder containing Markdown files without an `index.md` file creates a `section` rather than a page. The `index.html` for that section will be automatically created by Strike3 during the build process.

Sometimes, you need more granular control over your content. In these cases, you can use the [frontmatter](#frontmatter) at the beginning of each Markdown file to do just that.

## <a id="frontmatter">Frontmatter</a>
Frontmatter is great. It not only allows some flexibility to how posts appear and when they are published but it allows provides you with the ability to add custom data to a post that can then be used by themes.

Strike3 supports frontmatter in JSON format. Although optional, if you include frontmatter in your Markdown files, it must occur at the very top of the file. Frontmatter is identified by flanking it with `;;;`. Example:

```
;;;
"title": "My first post",
"date": "2016-12-09:10",
;;;
```

### Frontmatter variables
Variables can be accessed from within a theme template file simply by enclosing the variable name in double curly braces, like so: `{{title}}`. There are a few predefined variables that Strike3 uses and will create for you if not specified in the frontmatter or if no frontmatter is defined.

#### Reserved variables
##### date
The publication date for the content. Should be in SQL date format. Valid examples include: `2016-12-06 10:40`, `2016-12-06` and `2016-12-06 10:40:35`. If not specified then MAebh will use the modification date of the file. If the publication date is in the future then the content will not be rendered.

##### title
The title for the content. If not specified in the frontmatter then Strike3 will slugify the file name.

##### draft
If `true` then this post will not be rendered _unless_ then `buildDrafts` value in the site's `config.json` file is set to `true`.

## <a id="sections">Sections</a>
As discussed in the [content organisation](#content-organisation) section, how you organise your content in your file system is mirrored in the final built site. With this in mind, Strike3 uses the top level folders within the `/content` folder as the **section**.

The following example site has a static home page and two sections - `post` and `review`:

```
content
  - index.md              // http://example.com/
  - post
  --- First Post.md       // http://example.com/post/first-post.html
  --- Second Post.md      // http://example.com/post/second-post.html
  - review
  --- Die Hard.md         // http://example.com/review/die-hard.html
  --- Star Trek.md        // http://example.com/star-trek.html
```

### Section lists
If a file titled `index.md` is located within a top-level (section) folder then Strike3 will render that at `/section-name/index.html`. If no `index.md` file is present then Strike3 will automatically generate an index page listing all content within that section. It will automatically paginate the index if there are more posts than specified in the `postsPerPage` variable in the site’s `config.json` file. For example if `postsPerPage = 10` and there are 18 posts in our review section, Strike3 will create a site structure as below:

```
http://example.com/review         // listing of first 10 reviews
http://example.com/review/page/2  // listing of reviews 11-18
```

For more information on how to style these automatically generated lists from a theme, including how to access information on the individual posts in the list, see the [list content](#list-content) section.

## <a id="slugs">Slugs</a>
Just so we’re all clear, let’s look at an illustration of the terms used to describe both a content path (i.e. a file path within your `/content` folder) and a URL. The following file path:

`content/review/**Die Hard.md`

will generate this URL:

`http://example.com/review/die-hard.html`

Where **example.com** is the `baseURL` value in `config.json`, **review** is the **section** (a folder titled `review` in the `content` folder) and **die-hard** is the **slug**. 

The slug is created automatically by Strike3 from the file name by removing/substituting illegal URL characters. You can specify your own slug for a post by adding it to the post's [frontmatter](#frontmatter) like so:

```
"slug": "my-great-slug"
```

## <a id="content-example">Content example</a>
They say a picture is worth a thousand words. To that effect, below is a basic example of a content file written in Markdown. We’ll assume its file path is `my-site/content/review/Die Hard.md`. This will result in a final URL of `http://example.com/review/die-hard.html`. Kudos to [Empire][die hard review] for the text.

```
;;;
"title": Die Hard Review,
"date": "2016-12-06 16:39"
;;;

## Intro ##
New York cop _John McClane_ is visiting his estranged wife Holly in LA for
Christmas. Arriving in time for her Christmas party at the Nakatomi Plaza
skyscraper, he is unfortunately also just in time to see terrorists take
everyone there hostage. As the only cop inside the building, McClane does 
his best to sort the situation out.

## About ##
The smart-mouthed, high-rise thriller which launched [Bruce Willis][hero] as 
an action figure and accidentally rekindled Hollywoods enthusiasm for 
disaster movies (a worthy 80s cousin to The Towering Inferno). Die Hard has 
proved a reliable video fixture for the home and looks great on DVD; just 
dying to be racked alongside its two successors.

## Verdict ##
John McClane's smartmouthed New York cop was a career-defining turn, mixing 
banter, action heroics and a dirty white vest to stunning effect. Acting up 
to him every step of the way is [Alan Rickman][rickman], at his sneering 
best - but the script and cast are pretty much flawless. The very pinnacle 
of the '80s action movie, and if it's not the greatest action movie ever 
made, then it's damn close.

[hero]: https://en.wikipedia.org/wiki/Bruce_Willis
[rickman]: https://en.wikipedia.org/wiki/Alan_Rickman
```

This would be rendered as below:

```html
<h2>Intro</h2>
<p>New York cop <em>John McClane</em> is visiting his estranged wife Holly in LA for Christmas. 
Arriving in time for her Christmas party at the Nakatomi Plaza skyscraper, he is unfortunately 
also just in time to see terrorists take everyone there hostage. As the only cop inside the building, 
McClane does his best to sort the situation out.</p>

<h2>About</h2>
<p>The smart-mouthed, high-rise thriller which launched 
<a href="https://en.wikipedia.org/wiki/Bruce_Willis">Bruce Willis</a> as an action figure and 
accidentally rekindled Hollywoods enthusiasm for disaster movies (a worthy 80s cousin to 
The Towering Inferno). Die Hard has proved a reliable video fixture for the home and looks great 
on DVD; just dying to be racked alongside its two successors.</p>

<h2>Verdict</h2>
<p>John McClane’s smartmouthed New York cop was a career-defining turn, mixing banter, 
action heroics and a dirty white vest to stunning effect. Acting up to him every step of the way 
is <a href="https://en.wikipedia.org/wiki/Alan_Rickman">Alan Rickman</a>, at his sneering 
best - but the script and cast are pretty much flawless. The very pinnacle of the ‘80s action 
movie, and if it’s not the greatest action movie ever made, then it’s damn close.</p>
```

## <a id="themes-overview">Themes overview</a>
Strike3 has a powerful but very simple theming system which is capable of styling both basic and complicated sites. As an example, [my personal website](http://garrypettet.com) is built with Strike3 using a theme I built in an afternoon.

Strike3 themes are powered by Strike3's **Disco engine** and are therefore termed **Disco themes**. Disco themes are deliberately logic-less as their purpose is purely for the display of content, its Strike3's job as the rendering engine to handle logic. This means anybody with a basic knowledge of HTML and CSS can create a beautiful theme. Disco themes are structured in a way to reduce code duplication and are ridiculously easy to install and modify.

Strike3 currently ships with a simple default theme called `primary` to get you started.

## <a id="using-a-theme">Using a theme</a>
Community themes can be found in the `/Themes` folder of this repository. If you have created a theme and would like to share it then submit a pull request and I'll happily add it.

### Installing a community theme
Simply download your new theme folder and place it in the `/themes` folder within the root of your site. To activate it, set the value of the `theme` variable in the site’s `config.json` file to the name of the theme’s folder and rebuild the site.

### Creating your own theme
It is very much encouraged that you create your own theme. Not only will this give you full creative control over how your site looks but it’s really quite straightforwards and requires only a small amount of confidence with HTML and CSS. You can find out more in the [creating a theme](#creating-a-theme) section.

## <a id="creating-a-theme">Creating a theme</a>
Strike3 can create a new theme for you in your `/themes` directory with the `create theme` command:

`strike3 create theme [theme-name]`

This command will initialise all of the files and folders a basic theme requires. Strike3 themes are written in the [Disco templating language](#disco) which is essentially HTML with a few Strike3-specific tags to inject content-related stuff.

### Theme components
A theme comprises template files and static assets (such as CSS and javascript). Below are the files/folders required for a valid theme:

```
assets/
layouts/
 - 404.html
 - archive.html
 - archives.html
 - home.html
 - page.html
 - post.html
 - list.html
 - tags.html
 -- partials/
theme.json
```
This structure is created with the `create theme` command.

##### theme.json
This is the theme’s configuration file in JSON format. There are currently three variables within:

- `name`: The name of the theme
- `description`: A brief description of the theme
- `minVersion`: The minimum version of Strike3 required to use the theme

##### assets/
This is where a theme should store all of its static assets - things like CSS, javascript and image files. After building, they will be copied to `/public/assets/`. Files placed here are accesible from within a theme template file with the tag `{{assets}}`. For example, if your theme has a stylesheet called `styles.css`, you might want to organise it as follows:

```
- assets/
-- css/
--- styles.css
```

`styles.css` would then be copied to `public/assets/css/styles.css`. You can access it from your theme template files with `{{assets}}/css/styles.css`.

##### layouts/
This is the meat of the theme. The `layouts/` folder contains the various template files which specify how certain pages are rendered. It contains a single folder, `partials/` which contains template files (partial views) that can be injected into other template files. `layouts/` also contains the seven template files listed below:

- `404.html`: Detail on how to render the 404 page
- `archive.html`: Controls how the `/archive/index.html` page is rendered
- `archives.html`: Specifies how individual archive year and archive month pages are rendered
- `home.html`: If a static home page is required, this controls how it’s rendered
- `list.html` How to display the default list of content
- `page.html`: Default rendering for a page
- `post.html`: Default rendering for a single post

Additionally, a theme can have folders within `layouts/` named the same as sections in the site which specifiy how content in those sections is rendered. For example, suppose my content is structured as follows:

```
content
- index.md
- post/
-- first-post.md
- review/
-- Die Hard.md
- Another Post.md
```

I can easily style the appearance of a `post` and a `review` differently in a theme with the following structure

```
- theme.json
- assets/
- layouts/
-- partials/
-- post
--- post.html     // will style http://example.com/post/first-post.html
--- list.html     // will style http://example.com/post/
-- review
--- post.html    // will style http://example.com/review/die-hard.html
--- list.html      // will style http://example.com/review/
-- 404.html
-- archive.html
-- archives.html
-- home.html         // will style http://example.com/index.html
-- list.html
-- post.html       // will style http://example.com/another-post.html
```

You don't have to specify both a `post.html` and a `list.html` file for each section as, if not present, the default `layouts/post.html` and `layouts/list.html` files will be used.

## <a id="disco">Disco</a>
Disco is Strike3's templating language. In essence, it’s normal HTML with a limited number of **tags** that will be transformed by Strike3 during rendering into the required value.

### Basic syntax
As mentioned above, Disco template files are normal HTML files with the `.html` file extension but with the addition of variables and functions known as **tags**. Tags are called within double curly braces: `{{tag-name}}`

### Template variables
Each template file has a `context` object made available to it. Strike3 passes either a `post context` or a `list context` to a template file, depending on the type of content being rendered. More detail is available in the [variables](#variables) section.

A variable is accessed by referencing the variable’s name within a tag, e.g. the `title` variable:

```html
<title>{{title}}</title>
```

### Partials
To include the contents of another template file in a template file, we use the `{{partial template-name}}` tag where `template-name` is the name of a template file in the `partials/` folder (minus the `.html` extension).

For example, given a file called `header.html` in `partials/` like this:

```html
<!doctype html>

<html lang="en">
<head>
  <meta charset="utf-8">
  <link href="{{assets}}/css/bootstrap.min.css" rel="stylesheet">
</head>
```

We can include it in our `post.html` template file like this:

```html
{{partial header}}

<body>
  <p>Hello!</p>
</body>
```

### Iteration
Disco is deliberately logic-less. The only non-variable tag is the `{{foreach}} {{endeach}}` block. Tags and HTML enclosed within this block are run for each post in the current `context`. For example, if we assume that the current context has three pages then the following code:

```html
{{foreach}}
  <h2>{{title}}</h2>
  <p>Posted at {{date.hour}}:{{date.minute}}</p>
  <hr />
{{endeach}}
```

Would output the following HTML:

```html
<h2>My first post<h2/>
<p>Posted at 13:15<p/>
<hr />
<h2>My second post<h2/>
<p>Posted at 08:05<p/>
<hr />
<h2>My third post<h2/>
<p>Posted at 20:45<p/>
<hr />
```

The `{{foreach}} {{endeach}}` block only has meaning in list templates.

## <a id="the-context">The context</a>
Every template file is passed a `context`. There are two types of context that a template file may be passed: a `list context` and a `post context`. Each type of context has its own unique variables assigned to it by Strike3 and there are a number of base variables common to both types of context. Additionally, variables defined in a file's [frontmatter](#frontmatter) are also injected into the context.

Single posts and pages have just one context. However, the context within a list page changes when within an interation of a `{{foreach}} {{endeach}}` block. This is because a list page represents a collection of posts, each one having its own context.

For example, in a single post the tag `{{title}}` returns the title of the post. However in a list post, within a `{{foreach}} {{endeach}}` block the `{{title}}` tag returns the title of the post in the current iteration. Consider the following three Markdown files:

##### File structure:
```
content/review/Die Hard.md    // http://example.com/review/die-hard.html
content/review/Avatar.md      // http://example.com/review/avatar.html
content/review/Star Trek.md   // http://example.com/review/star-trek.html
```

##### Die Hard.md
```markdown
;;;
"title": "Die Hard (1988)"
;;;
## Yippee ki-yay! ##
```

##### Avatar.md
```markdown
;;;
"title": "Avatar (2009)"
;;;
## Open Pandora's box ##
```

##### Star Trek.md
```markdown
;;;
"title": "Star Trek (2009)"
;;;
## To boldly go where no one has gone before ##
```

When Strike3 renders the page `http://example.com/review/avatar.html` it will call the `post.html` template file for the theme. Let’s say the contents of that file is:

```html
<h2>{{title}}</h2>
```

The output will be:

```html
<h2>Avatar (2009)</h2>
```

If, however, Strike3 is rendering a list of the all the reviews at `http://example.com/review/index.html` it will call the `list.html` template file. Let’s say the contents of that file is:

```html
{{foreach}}
  <h2>{{title}}</h2>
  <hr />
{{endeach}}
```

The output will be:

```html
<h2>Die Hard (1988)</h2>
<hr />
<h2>Avatar (2009)</h2>
<hr />
<h2>Star Trek (2009)</h2>
<hr />
```

## <a id="variables"></a>Variables
As mentioned in the [context section](#context), Strike3 makes available a number of variables to template files through their `context`. The following variables are available for use in template files within a theme.

### Site variables
The value of any variable in the site’s `config.json` file can be retrieved from any template file with the tag `{{site.variable-name}}`, this includes user-defined variables. This is the prefered method to set global data values.

For example, to get the base URL of the entire site from within a template file, simply use the tag `{{site.baseURL}}`.

### All context variables
The following is a list of the variables available to both post and list contexts (`page.html`, `post.html` and `list.html` template files). In the case of post contexts, all may be overridden in the [frontmatter](#frontmatter). Remember, these are all accessed by enclosing in double curly braces, e.g.`{{variable name}}`.

- `{{assets}}`: The public URL to the current theme's `assets/` folder
- `{{content}}`: The content of the context's file
- `{{date}}`: The date of the content in SQL format
- `{{date.second}}`: The second component of the content’s date (two digits)
- `{{date.minute}}`: The minute component of the content’s date (two digits)
- `{{date.hour}}`: The hour component of the content’s date (two digits)
- `{{date.day}}`: The day component of the content’s date (two digits)
- `{{date.month}}`: The month component of the content’s date (two digits)
- `{{date.longMonth}}`: The month component of the content’s date (e.g. January)
- `{{date.shortMonth}}`: The month component of the content’s date (e.g. Jan)
- `{{date.year}}`: The year component of the content’s date (four digits)
- `{{feedURL}}`: The URL to the site's RSS feed (if enabled in the site's [configuration](#config))
- `{{navigation}}`: A HTML unordered list of the site contents
- `{{permalink}}`: The permalink URL to the content
- `{{readingTime}}`: Estimated reading time for the content (e.g. “3 min read”)
- `{{storage}}`: The public URL to the `storage/` folder
- `{{summary}}`: A summary of the content (first 55 words)
- `{{tags}}`: Unordered HTML list of the content's tags
- `{{title}}`: The title of the content
- `{{wordCount}}`: The number of words in the content

### List context variables
List pages are automatically created by Strike3 at the root of the site as `http://example.com/index.html` (unless a static homepage is specified) and at the root of every section (e.g. `http://example.com/review/index.html`) and are rendered by `list.html` template files. The following is a list of variables accessible from `list.html` template files.

- `{{nextPage}}`: The URL to the next page in a paginated list of posts
- `{{prevPage}}`: The URL to the previous page in a paginated list of posts

### Archive variables
- `{{archives.months}}`: HTML list of your site’s content by month (e.g. Jan)
- `{{archives.longMonths}}`: HTML list of your site’s content by month (e.g. January)
- `{{archives.url}}`: The URL to your site’s archive listing page (e.g. `http://example.com/archive/`)

### Helper variables
- `{{helper.day}}`: The day component of the content's date (two digits)
- `{{helper.longMonth}}`: The month component of the content’s date (e.g. January)
- `{{helper.shortMonth}}`: The month component of the content’s date (e.g. Jan)
- `{{helper.month}}`: The month component of the content’s date (two digits)
- `{{helper.year}}`: The year component of the content’s date (four digits)

### Strike3 variables
- `{{strike3.generator}}`: Meta tag for the version of Strike3 that built the site. I’d be very grateful if you would include it in all theme headers so I can track the usage and popularity of Strike3 as a tool. Example output: `<meta name="generator" content="Strike3 0.5.0" />`
- `{{strike3.version}}`: Strike3's version number

## <a id="single-templates">Single templates</a>
Single content is the term for posts and pages. For every Markdown file in the `content/` folder (except the homepage), Strike3 will render it using either a `page.html` or `post.html` file from the currently active theme. Which template file is used is decided with this algorithm:

- Is the file `content/index.md`? If so then it’s a static homepage so render it with `layouts/home.html`
- Is the Markdown file in the root of `content/`? If yes then use `layouts/post.html`
- Is the Markdown file named `index.md` **and** the only file in a subfolder of `content/`?. If yes, it's a page so render with `layouts/page.html`
- Is the Markdown file in a section? If yes then use the `post.html` file for that section. For example, for the Markdown file `content/review/Die Hard.md` Strike3 will look first for `layouts/review/post.html` and use it. If that doesn’t exist then Strike3 will render the content with the default `layouts/post.html` file.

### Example post.html template file

```html
{{partial header}}

<div class="row">
  <div class="col-12">
    <article class="single">
      <div class="post-meta">
        <h2 class="post-title">{{title}}</h2>
        <p class="post-date">{{date.longMonth}} {{date.day}}, {{date.year}}</p>
        {{tags}}
      </div>
      <div class="post-content">
        {{content}}
      </div><!--/.post-content-->
    </article><!--/.single-->
  </div><!--/.col-12-->
</div><!--/.row-->
</main>
</div><!--/.container-->
</div><!--/#wrap data-sticky-wrap-->

{{partial footer}}
```

## <a id="list-templates">List templates</a>
A list template is used to render multiple pieces of content in a single HTML file. Essentially, it's used to generate all `index.html` pages for the site (although optionally a different template can be used to render a static homepage).

For example, suppose I want a standard blog where the index page for the site (let’s say `http://example.com/`) lists all my blog posts in a paginated fashion. I also want a review section, separate from my blog that’ll store my movie reviews. I want that to have a listing too. I will structure my content as follows:

```
content/
- Post 1.md
- Post 2.md
- Post 3.md
- Post 4.md
- review/
--- Review 1.md
--- Review 2.md
--- Review 3.md
```

This will lead to the site structure below:

```
http://example.com/index.html             // auto-generated
http://example.com/post-1.html
http://example.com/post-2.html
http://example.com/post-3.html
http://example.com/post-4.html
http://example.com/review/index.html      // auto-generated
http://example.com/review/review-1.html
http://example.com/review/review-2.html
http://example.com/review/review-3.html
```

To render the main site index page (`http://example.com/index.html`), Strike3 will use the default `layouts/list.html` template file. To render the listing for the reviews, Strike3 will first try to use `layouts/review/list.html`. If that file doesn’t exist then Strike3 will default to `layouts/list.html`. This allows themes to style the listing of sections differently.

### Example list.html template file
The example `list.html` template file below is used to generate the listing of posts on my [personal blog](http://garrypettet.com/blog):

```html
{{partial header}}

  <div class="row">
    <div class="col-12">
      {{foreach}}
        <article class="list">
          <h3 class="post-title">
            <a href="http://aoife.io/docs/list-templates.html">{{title}}</a>
            <span class="separator"> · </span>{{date.longMonth}} {{date.day}}, {{date.year}}
          </h3>
        </article>
      {{endeach}}
    </div><!--/.col-12-->
  </div><!--/.row-->
  <div class="row">
    <div class="col-12">
      <div class="list-navigation">
        <a class="prev-page" href="{{prevPage}}">← Previous</a>
        <a class="next-page" href="{{nextPage}}">Next →</a>
      </div><!--/.list-navigation-->
    </div><!--/.col-12-->
  </div><!--/.row-->
</main>
</div><!--/.container data-sticky-wrap-->

{{partial footer}}
```

## <a id="homepage">Homepage</a>
Believe it or not, the inability of a, shall remain nameless, dynamic website generator to create a static homepage was the “straw that broke the camel’s back” and drove me to write my own site generator in the first place.

A static homepage is the site’s landing page (i.e. the main `index.html` file) that is rendered differently from all the other site pages. Creating one is super easy with Strike3. Put the content you want on your homepage in a Markdown file named `index.md` in the root of the site (i.e. `content/index.md`) and style it with the template file `layouts/home.html`. Easy peasy.

## <a id="tags">Tags</a>
Strike3 supports the tagging of posts. A post can be given assigned any number of tags (or none at all) within its [frontmatter](#frontmatter). To assign a tag or tags to a post simply add them in a JSON array called `tags` within the frontmatter:

```markdown
;;;
"tags": ["review", "sci-fi"]
;;;
```

### Getting a post's tags
Themes have easy access to a post's tags with the `{{tags}}` variable. Calling `{{tags}}` will output an unordered HTML list of the tags like so:

```html
<ul class="tags">
	<li><a href="/tag/review">review</a></li>
	<li><a href="/tag/sci-fi">sci-fi</a></li>
</ul>
```

### Listing content by tag
The posts tagged with a particular tag can be found at `public/tag/tag-name/index.html`. So in the above example would could view all posts tagged "sci-fi" by visiting `public/tag/sci-fi/index.html`.

## <a id="archives">Archives</a>
Strike3 will automatically add archives for your content. To disable this functionality you must set the `archives` variable in `config.json` to `false`.

When archives are enabled, Strike3 will create a top-level section in the built site at `archive/`. A page will be created at the root of this section (`archive/index.html`) for you to style how you wish with the `layouts/archive.html` template file.

Additionally, sub-folders will be created beneath `archive/` for each year and month that posts occur. For example, the following content:

```
content
- Post 1.md     // publish date: Oct 1st 2016
- Post 2.md     // publish date: Sep 10th 2016
- Post 3.md     // publish date: Jan 22nd 2016
- Post 4.md     // publish date: Mar 4th 2015
- Post 5.md     // publish date: Feb 8th 2015
```

Would result in an archive as follows:

```
http://example.com/archive/2016/index.html      // lists all 2016 posts
http://example.com/archive/2016/10/index.html   // lists October 2016 posts
http://example.com/archive/2016/9/index.html    // lists September 2016 posts
http://example.com/archive/2016/1/index.html    // lists January 2016 posts
http://example.com/archive/2015/index.html      // lists all 2015 posts
http://example.com/archive/2015/3/index.html    // lists March 2015 posts
http://example.com/archive/2015/2/index.html    // lists February 2015 posts
```

These listing pages are styled with the `layouts/archives.html` template file (note archive**s** not archive).

See the [variables](#variables) section for more information on archive-specific template tags.

It’s worth noting that generating archives is computationally expensive. If you don’t need them then set the `archives` variable in `config.json` file to `false`.

## <a id="navigation">Navigation</a>
Strike3 provides a simple way to include site navigation in your themes. Using the `{{navigation}}` tag within any template file will output an unordered
HTML list of all the sections and sub-sections of your site with permalinks to their roots. For example, given the following content:

```
content/
- about/
- post/
- review/
```

The `{{navigation}}` tag would generate the following HTML:

```html
<ul class="site-nav">
  <li><a href="http://example.com/about">about</a></li>
  <li><a href="http://example.com/post">post</a></li>
  <li><a href="http://example.com/review">review</a></li>
</ul>
```

## <a id="pagination">Pagination</a>
Strike3 has full support for pagination. Whether or not pagination is required for a particular section depends on the `postsPerPage` variable in the site’s `config.json` file. For instance, suppose we have a blog with the following structure:

```
content
- Post 1.md
- Post 2.md
- Post 3.md
- Post 4.md
- Post 5.md
- Post 6.md
```

Strike3 will automatically create an index list page (because we have not specified a [static homepage](#homepage)) at `/public/index.html` using the rendering information in the `list.html` template file of the current theme.

If we leave `postsPerPage` at the default value (`10`) then Strike3 will not need to paginate the index because we only have 6 posts. If however we change `postsPerPage` to `3` then Strike3 will not only create `public/index.html` (which will list the first three posts: `Post 1.md`, `Post 2.md` and `Post 3.md`) but it will also create a second page at `public/page/2/index.html` (which will list the last three posts: `Post 4.md`, `Post 5.md` and `Post 6.md`).

Strike3 provides convenient tags to output the URLs of the previous and next pages. These tags are `{{nextPage}}` and `{{prevPage}}`. These tags are only valid in `list.html` and `archives.html` template files.

### Example usage
Here’s how I use these tags in my personal blog, which is built with Strike3:

```html
<div class="list-navigation">
  <a class="prev-page" href="{{prevPage}}">← Previous</a>
  <a class="next-page" href="{{nextPage}}">Next →</a>
</div><!--/.list-navigation-->
```

Which would render something like this (assuming we’re on page 2 of the list):

```html
<div class="list-navigation">
  <a class="prev-page" href="http://example.com/index.html">← Previous</a>
  <a class="next-page" href="http://example.com/page/3/index.html">Next →</a>
</div><!--/.list-navigation-->
```

## <a id="rss">RSS</a>
Strike3 can optionally generate a RSS feed for your site if the `rss` variable is set to `true` within the site’s `config.json` file. The feed adheres to the RSS 2.0 specification.

The feed will be saved to `public/rss.xml`. You can access the link to it from within a template file with the `{{feedURL}}` tag.

It’s worth noting that feed XML files can grow quite large. If you don’t want to provide a feed for your site then make sure you set the `rss` variable to `false` to increase build speed and reduce the size of the site to upload. It's `false` by default.

[die hard review]: http://www.empireonline.com/movies/die-hard/review/
[xojo]: https://xojo.com
[cmark]: https://github.com/commonmark/cmark
[md5]: https://www.fourmilab.ch/md5/
[mac-release]: http://example.com
[win-release]: http://example.com
[atom]: https://atom.io
[homebrew]: https://brew.sh