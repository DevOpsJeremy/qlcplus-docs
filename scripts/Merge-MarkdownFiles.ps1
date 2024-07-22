[CmdletBinding()]
param ()

function Remove-Metadata {
    Param (
        [string]$Content
    )
    # Correctly remove YAML metadata from markdown content
    $cleanContent = $Content -replace '^---[\s\S]*?---', ''

    # Find and replace relative image paths with absolute paths
    $pattern = '!\[(?:.*?)\]\((?:\.\.?\/)?.*?(?<filename>[^\/]*\.(png|jpg|svg|webp|webm|jpeg|gif))\s*(?:".*?")?\)'

    # Split the Markdown content, increment all headings by one, replace relative image paths with 'image/<filename>', and join the content back together
    $cleanContent -split "`n" -replace "^#", '##' -replace $pattern, '![](images/${filename})' -join "`n"
}

function Get-MarkdownFiles {
    Param (
        [string]$Path
    )
    Write-Verbose "Getting all markdown files from the $path directory..."
    # If the directory doesn't exist, throw a warning and exit
    if (-not (Test-Path $Path -PathType Container)) {
        Write-Warning "Directory not found: $directory"
        return
    }
    # Get the list of folders in the directory (feed is excluded as it's a stub for RSS)
    $folders = Get-ChildItem -Path $Path -Directory -Exclude feed
    $markdownFiles = @()

    # Iterate over each folder
    foreach ($folder in $folders) {
        $markdownFiles += Get-ChildItem -Path ($folder.FullName + "\chapter.v4.md")
        $markdownFiles += Get-ChildItem -Path ($folder.FullName) -Recurse -File | Where-Object { $_.Name -match "default\.v4\.md|docs\.md" } | Sort-Object FullName
    }

    foreach ($file in $markdownFiles) {
        $content = Get-Content $file.FullName -Raw
        $cleanContent = Remove-Metadata $content
        if(-not [string]::IsNullOrWhiteSpace($cleanContent)) {
            [PSCustomObject]@{
                Path    = $file.FullName
                # Replace generic chapter headings with chapter title
                Content = $cleanContent -replace '####\sChapter \d+', "# $(Format-ChapterName $file.Directory.Name)"
            }
        } else {
            Write-Verbose "No content after cleaning metadata for: $($file.FullName)"
        }
    }
}

function Merge-MarkdownFiles {
    Param (
        [Array] $MarkdownFiles, 
        [string] $OutputPath,
        [string] $directoryPath 
    )
    #Write combined markdown
    $MarkdownFiles.Content -join "`n`n" | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Verbose "Combined markdown written to $OutputPath"
}

function Format-ChapterName {
    param (
        [string]$inputString
    )

    # Check if the input string matches the pattern
    if ($inputString -match '^(?<number>\d+)\.(?<chapter>[a-zA-Z]+(?:-[a-zA-Z]+)*)$') {
        return "{0}. {1}" -f $Matches.number, (Get-Culture).TextInfo.ToTitleCase(($Matches.chapter -replace '-', ' '))
    }
}

function Copy-ImagesToDirectory {
    param (
        [string]$sourceDirectory,
        [string]$destinationDirectory
    )
    Write-Verbose "Copying images..."
    # Clear the destination directory if it exists
    if (Test-Path $destinationDirectory) {
        Remove-Item -Path $destinationDirectory -Recurse -Force
    }

    # Create the destination directory
    New-Item -ItemType Directory -Path $destinationDirectory | Out-Null

    # Define an array of image file extensions
    $imageExtensions = @('*.webp', '*.webm', '*.jpg', '*.jpeg', '*.png', '*.svg')

    # Get all image files recursively from the source directory
    Get-ChildItem -Path $sourceDirectory -Include $imageExtensions -File -Recurse | Copy-Item -Destination $destinationDirectory
}


$directoryPath  = "./pages/"                                            # Path To Grav Documentation
$imageDir       = "./.github/workflows/bin/images/"                     # Path to where images should go
$outputFile     = "./.github/workflows/bin/combined_documentation.md"   # Path to where you want your damn markdown ;)


# Move all image files into ./images so they can be found
Copy-ImagesToDirectory -sourceDirectory $directoryPath -destinationDirectory $imageDir

# Process and combine markdown files
$markdownFiles = Get-MarkdownFiles -Path $directoryPath
Merge-MarkdownFiles -MarkdownFiles $markdownFiles -OutputPath $outputFile -directoryPath $directoryPath
