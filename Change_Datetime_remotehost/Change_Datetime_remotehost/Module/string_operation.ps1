#-----------------------------------#
# This script is the module for string operation.
#-----------------------------------#

function removeExtension {
# -------------- #
# 拡張子を除外したファイル名、パスを返す
# 
# Param1 file: ファイル名かフルパスで
# -------------- #
    param(
        [string]
        $file
    )
    $start_idx = $file.LastIndexOf(".")
    $rm_charsnum = $file.Length - $start_idx
    $noext_file = $file.Remove($start_idx, $rm_charsnum)
    $noext_file
}

function replaceStringInTextFile {
# ----------------- #
# テキストファイルの文字列を置換する
# Param1 filepath: 対象ファイルのパス
# Param2 regexp: 検索する文字列 正規表現表記可能
# Param3 replacement: 置換する文字列
# ----------------- #
    param(
        [string]
        $filepath,
        [string]
        $regexp,
        [string]
        $replacement
    )
    $outputfile = "$filepath.replace"
    $file_contents = Get-Content $filepath -Encoding UTF8
    foreach($line in $file_contents) {
        $line -creplace $regexp, $replacement | Out-File -Append $outputfile -Encoding utf8
        # if($line -match $regexp) {
        #     $line -creplace $regexp, $replacement | Out-File -Append $outputfile -Encoding utf8
        #} else {
        #     マッチしなかった場合の処理
        #}
    }
    $new_filename = removeExtension -file $outputfile
    $new_filename = Split-Path -Leaf $new_filename
    # remove file before replacement.
    Remove-Item -Path $filepath
    # Rename file after replacement.
    Rename-Item -Path $outputfile -NewName $new_filename
}
