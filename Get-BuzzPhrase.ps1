function Get-BuzzPhrase {
    $Page = invoke-webrequest -uri https://www.atrixnet.com/bs-generator.html
    $(foreach ($WordType in @('adverbs', 'verbs', 'adjectives', 'nouns')) {
        ([regex]::match(($Page.AllElements)[1].outerHTML, "var $WordType = new Array \(([^\)]+)\)") -replace "var $WordType = new Array \(|\)" -split ',' -replace '''' -replace "`n").Trim() | Get-Random
    }) -join ' ' 
}
