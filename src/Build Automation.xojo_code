#tag BuildAutomation
			Begin BuildStepList Linux
				Begin BuildProjectStep Build
				End
			End
			Begin BuildStepList Mac OS X
				Begin BuildProjectStep Build
				End
				Begin CopyFilesBuildStep CopyFilesMac
					AppliesTo = 0
					Destination = 0
					Subdirectory = 
					FolderItem = Li4vLi4vcmVzb3VyY2VzL3BhbmRvYy9tYWNPUy9wYW5kb2M=
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2JvaWxlcnBsYXRlLzQwNC5odG1s
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RhdGFiYXNlX3NjaGVtYS5zcWw=
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RlZmF1bHQlMjB0aGVtZS9wcmltYXJ5Lw==
				End
				Begin IDEScriptBuildStep PostBuildMac , AppliesTo = 2
					dim name as String = "strike3"
					dim major as String = PropertyValue("App.MajorVersion")
					dim minor as String = PropertyValue("App.MinorVersion")
					dim bug as String = PropertyValue("App.BugVersion")
					dim source as String = CurrentBuildLocation()
					dim destination as String = "/Users/garry/Desktop"
					dim result as String
					
					result = DoShellCommand("/usr/local/bin/publisher -n " + name + " -m " + major + " -x " + minor + " -b " + bug + _
					" -p macos" + " -s " + source + " -d " + destination + " --colour-off")
					
					Print(result)
				End
			End
			Begin BuildStepList Windows
				Begin BuildProjectStep Build
				End
				Begin CopyFilesBuildStep CopyFilesWin
					AppliesTo = 0
					Destination = 0
					Subdirectory = 
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2JvaWxlcnBsYXRlLzQwNC5odG1s
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RhdGFiYXNlX3NjaGVtYS5zcWw=
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RlZmF1bHQlMjB0aGVtZS9wcmltYXJ5Lw==
					FolderItem = Li4vLi4vcmVzb3VyY2VzL3BhbmRvYy93aW4vcGFuZG9jLmV4ZQ==
				End
				Begin IDEScriptBuildStep PostBuildWin , AppliesTo = 2
					dim name as String = "strike3"
					dim major as String = PropertyValue("App.MajorVersion")
					dim minor as String = PropertyValue("App.MinorVersion")
					dim bug as String = PropertyValue("App.BugVersion")
					dim source as String = CurrentBuildLocation()
					dim destination as String = "/Users/garry/Desktop"
					dim result as String
					
					result = DoShellCommand("/usr/local/bin/publisher -n " + name + " -m " + major + " -x " + minor + " -b " + bug + _
					" -p win64" + " -s " + source + " -d " + destination + " --colour-off")
					
					Print(result)
				End
			End
#tag EndBuildAutomation
