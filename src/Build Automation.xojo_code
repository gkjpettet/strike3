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
					Destination = 1
					Subdirectory = 
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RhdGFiYXNlX3NjaGVtYS5zcWw=
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2JvaWxlcnBsYXRlLzQwNC5odG1s
					FolderItem = Li4vLi4vcmVzb3VyY2VzL3BhbmRvYy9tYWNPUy9wYW5kb2M=
				End
			End
			Begin BuildStepList Windows
				Begin BuildProjectStep Build
				End
				Begin CopyFilesBuildStep CopyFilesWin
					AppliesTo = 0
					Destination = 1
					Subdirectory = 
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2RhdGFiYXNlX3NjaGVtYS5zcWw=
					FolderItem = Li4vLi4vcmVzb3VyY2VzL2JvaWxlcnBsYXRlLzQwNC5odG1s
					FolderItem = Li4vLi4vcmVzb3VyY2VzL3BhbmRvYy93aW4vcGFuZG9jLmV4ZQ==
				End
			End
#tag EndBuildAutomation
