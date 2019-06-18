<#
.SYNOPSIS
概要
ハイブリット暗号(公開鍵方式暗号+共通鍵暗号)を使用して、安全なファイル交換用の暗号化/復号化をします
公開鍵方式なので、復号パスワードを送る必要はありません

<CommonParameters> はサポートしていません

.DESCRIPTION
・暗号化(-Mode Encrypto)
    受信者の公開鍵を -PublicKeys で指定してファイルを暗号化します
    受信者以外は復号できないので、誤送によるリスクが大幅低減します
    送信者の秘密鍵で電子署名をします

・復号化(-Mode Decrypto)
    自分の秘密鍵を使って復号化します
    復号化する前に、送信者公開鍵を -PublicKeys で指定し電子署名を確認するので、なりすましや改ざんリスクが大幅に低減します

・鍵ペア作成(-Mode CreateKey)
    公開鍵と秘密鍵のセットを作成します
    作成した公開鍵は受信者に渡します
    受信者にも鍵ペアを作成してもらい、受信者の公開鍵も入手します
    公開鍵はキーコンテナを削除しない限り同じ公開鍵が出力されます

・秘密鍵の削除(-Mode RemoveKey)
    秘密鍵(キーコンテナ)を削除

・キーコンテナのエクスポート(-Mode Export)
    秘密鍵を格納したキーコンテナをエクスポート(バックアップ)します

・キーコンテナエクスポートテスト(-Mode Test)
    エクスポートファイルがパスワードで復号できるかをテストします

・キーコンテナのインポート(-Mode Import)
    エクスポートファイルからキーコンテナをインポート(リストア)します

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode CreateKey
鍵ペア作成

PS C:\PSCrypto> .\PSCrypto.ps1 -Mode RemoveKey
秘密鍵削除

スクリプトを置いた場所にサブフォルダ(PublicKeys)が作成され、公開鍵(ユーザー名_Publickey.xml)が出力される
-Outfile を指定すると公開鍵のフルパスが指定できる

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode Encrypto -PublicKeys .\PublicKey\UserName_Publickey.xml -Path C:\Data\SecretData.zip
暗号化

元ファイルと同一フォルダーに暗号化ファイル(.enc)が出力される
-Outfile を指定すると暗号化ファイルのフルパスが指定できる

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode Decrypto -PublicKeys .\PublicKey\UserName_Publickey.xml -Path C:\Data\SecretData.enc
復号化

暗号化ファイルと同一フォルダーに元ファイル名で復号化される
-Outfile を指定すると復号化ファイルのフルパスが指定できる

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode Export
エクスポート(バックアップ)

C:\Users\ユーザー名\Documents\PSCryptography\Export\PSCryptoExport.dat が出力される

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode Import
インポート(リストア)

C:\Users\ユーザー名\Documents\PSCryptography\Export\PSCryptoExport.dat からインポートする
エクスポートファイルが存在しない時は、スクリプトと同じフォルダにある PSCryptoExport.dat をセットしてからインポートする

.EXAMPLE
PS C:\PSCrypto> .\PSCrypto.ps1 -Mode Test
テスト

エクスポートしたキーコンテナが復号できるかテストする
C:\Users\ユーザー名\Documents\PSCryptography\Export\PSCryptoExport.dat をテストする
エクスポートファイルが存在しない時は、スクリプトと同じフォルダにある PSCryptoExport.dat をセットしてテストする

.PARAMETER Mode
操作モード
    鍵ペア作成: CreateKey
    秘密鍵削除: RemoveKey
    暗号化: Encrypto
    復号化: Decrypto
    Export: Export
    Import: Import
    Test: Test

.PARAMETER PublicKeys
公開鍵
    複数指定する場合はカンマで区切る

.PARAMETER Path
暗号/復号するファイル

.PARAMETER Outfile
出力ファイル(省略可)

<CommonParameters> はサポートしていません

.LINK
http://www.vwnet.jp/Windows/PowerShell/PublicKeyCrypto.htm
#>


##########################################################
# 暗号化、復号化、鍵生成、Export、Import
##########################################################
param(
	[string]$Path,			# 入力ファイル名
	[string[]]$PublicKeys,	# 公開鍵
	[ValidateSet("Decrypto", "Encrypto", "CreateKey", "RemoveKey", "Export", "Import", "Test")]
		[string]$Mode,		# モード
	[string]$Outfile		# 出力ファイル名
	)

# バージョン
$C_Vertion = "02"

# モード
$C_Mode_Decrypto = "Decrypto"	# 復号
$C_Mode_Encrypto = "Encrypto"	# 暗号
$C_Mode_CreateKey = "CreateKey"	# キー作成
$C_Mode_RemoveKey = "RemoveKey"	# キー削除
$C_Mode_Export = "Export"		# Export
$C_Mode_Test = "Test"			# Test
$C_Mode_Import = "Import"		# Import

# セッション鍵サイズ(bit)
$C_SessionKeyLength = 256

# キーコンテナ名
$C_ContainerName = "PowerShellEncrypto"

# 署名サイズ(bit)
$C_SignatureLength = 128

# ハッシュ値サイズ(bit)
$C_HashLength = 256

# 暗号化したSessionキーサイズ
$C_EncryptoSessionKeyLength = 128

# 拡張子
$C_Extension = "enc"

# 公開鍵出力場所
$C_PulicKeyLocation = Join-Path $PSScriptRoot "PublicKeys"

# 公開鍵のプレフィックス + 拡張子
$C_PublicKeyExtentPart = ".xml"
$C_PublicKeyExtent = "_PublicKey" + $C_PublicKeyExtentPart

# スクリプトフルパス
$C_ScriptFullFileName = $MyInvocation.MyCommand.Path

# スクリプトフォルダ
$C_ScriptDirectory = Split-Path $C_ScriptFullFileName -Parent

# ログインユーザー名
$UserName = $env:USERNAME
if( $UserName -eq $null ){
	$UserName = $env:USER
}

# キーコンテナ名 Export フォルダ
$TmpExportDirectory = Join-Path $C_ScriptDirectory "\Export"
$C_ExportDirectory = Join-Path $TmpExportDirectory $UserName

# キーコンテナ名 Export ファイル名
$C_ExportFileName = "PSCryptoExport.dat"

# キーコンテナ Export フルパス
$C_ExportFullFileName = Join-Path $C_ExportDirectory $C_ExportFileName


##################################################
# セッション鍵生成
##################################################
function CreateRandomKey( $KeyBitSize ){
	if( ($KeyBitSize % 8) -ne 0 ){
		echo "Key size Error"
		return $null
	}
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# バイト数にする
	$ByteSize = $KeyBitSize / 8

	# 入れ物作成
	$KeyBytes = New-Object byte[] $ByteSize

	# オブジェクト 作成
	$RNG = New-Object System.Security.Cryptography.RNGCryptoServiceProvider

	# 鍵サイズ分の乱数を生成
	$RNG.GetNonZeroBytes($KeyBytes)

	# オブジェクト削除
	$RNG.Dispose()

	return $KeyBytes
}

##################################################
# AES 暗号化
##################################################
function AESEncrypto($KeyByte, $PlainByte){
	$KeySize = 256
	$BlockSize = 128
	$Mode = "CBC"
	$Padding = "PKCS7"

	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# AES オブジェクトの生成
	$AES = New-Object System.Security.Cryptography.AesCryptoServiceProvider

	# 各値セット
	$AES.KeySize = $KeySize
	$AES.BlockSize = $BlockSize
	$AES.Mode = $Mode
	$AES.Padding = $Padding

	# IV 生成
	$AES.GenerateIV()

	# 生成した IV
	$IV = $AES.IV

	# 鍵セット
	$AES.Key = $KeyByte

	# 暗号化オブジェクト生成
	$Encryptor = $AES.CreateEncryptor()

	# 暗号化
	$EncryptoByte = $Encryptor.TransformFinalBlock($PlainByte, 0, $PlainByte.Length)

	# IV と暗号化した文字列を結合
	$DataByte = $IV + $EncryptoByte

	# オブジェクト削除
	$Encryptor.Dispose()
	$AES.Dispose()

	return $DataByte
}

##################################################
# AES 復号化
##################################################
function AESDecrypto($ByteKey, $ByteString){
	$KeySize = 256
	$BlockSize = 128
	$IVSize = $BlockSize / 8
	$Mode = "CBC"
	$Padding = "PKCS7"

	# IV を取り出す
	$IV = @()
	for( $i = 0; $i -lt $IVSize; $i++){
		$IV += $ByteString[$i]
	}

	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# オブジェクトの生成
	$AES = New-Object System.Security.Cryptography.AesCryptoServiceProvider

	# 各値セット
	$AES.KeySize = $KeySize
	$AES.BlockSize = $BlockSize
	$AES.Mode = $Mode
	$AES.Padding = $Padding

	# IV セット
	$AES.IV = $IV

	# 鍵セット
	$AES.Key = $ByteKey

	# 復号化オブジェクト生成
	$Decryptor = $AES.CreateDecryptor()

	try{
		# 復号化
		$DecryptoByte = $Decryptor.TransformFinalBlock($ByteString, $IVSize, $ByteString.Length - $IVSize)
	}
	catch{
		$DecryptoByte = $null
	}

	# オブジェクト削除
	$Decryptor.Dispose()
	$AES.Dispose()

	return $DecryptoByte
}

##################################################
# 公開鍵 暗号化
##################################################
function RSAEncrypto($PublicKey, $PlainByte){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# RSACryptoServiceProviderオブジェクト作成
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider

	# 公開鍵を指定
	$RSA.FromXmlString($PublicKey)

	# 暗号化
	$EncryptedByte = $RSA.Encrypt($PlainByte, $False)

	# オブジェクト削除
	$RSA.Dispose()

	return $EncryptedByte
}

#####################################################################
#  CSP キーコンテナに保存されている秘密鍵を使って文字列を復号化する
#####################################################################
function RSADecryptoCSP($ContainerName, $EncryptedByte){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成し秘密鍵を取り出す
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	try{
		# 復号
		$DecryptedData = $RSA.Decrypt($EncryptedByte, $False)
	}
	catch{
		$DecryptedData = $null
	}
	# オブジェクト削除
	$RSA.Dispose()

	return $DecryptedData
}

#####################################################################
# CSP キーコンテナに保存されている秘密鍵を使って署名を作る
#####################################################################
function RSASignatureCSP($ContainerName, $BaseByte){

	# SHA256 Hash 値を求める
	$HashBytes = GetSHA256Hash $BaseByte

	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成し秘密鍵を取り出す
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	# RSAPKCS1SignatureFormatterオブジェクト作成
	$Formatter = New-Object System.Security.Cryptography.RSAPKCS1SignatureFormatter($RSA)

	# ハッシュアルゴリズムを指定
	$Formatter.SetHashAlgorithm("SHA256")

	# 署名を作成
	$SignatureByte = $Formatter.CreateSignature($HashBytes)

	# オブジェクト削除
	$RSA.Dispose()

	return $SignatureByte
}

#####################################################################
# 公開鍵を使って署名を確認する
#####################################################################
function RSAVerifySignature($PublicKey, $SignatureByte, $BaseByte){

	# SHA256 Hash 値を求める
	$HashBytes = GetSHA256Hash $BaseByte

	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# RSACryptoServiceProviderオブジェクト作成
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider

	# 公開鍵をセット
	$RSA.FromXmlString($PublicKey)

	# RSAPKCS1SignatureDeformatterオブジェクト作成
	$Deformatter = New-Object System.Security.Cryptography.RSAPKCS1SignatureDeformatter($RSA)

	# ハッシュアルゴリズムを指定
	$Deformatter.SetHashAlgorithm("SHA256")

	# 署名を検証する
	$Result = $Deformatter.VerifySignature($HashBytes, $SignatureByte)

	# オブジェクト削除
	$RSA.Dispose()

	return $Result
}

##################################################
#  鍵を作成し CSP キーコンテナに保存
##################################################
function RSACreateKeyCSP($ContainerName){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成し秘密鍵を格納
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	# 公開鍵
	$PublicKey = $RSA.ToXmlString($False)

	# オブジェクト削除 (PS2 でサポートされていないのでコメントアウト)
	$RSA.Dispose()

	return $PublicKey
}

##################################################
# CSP キーコンテナのエクスポート
##################################################
function RSAExportCSP($ContainerName){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	# エクスポート
	$ByteData = $RSA.ExportCspBlob($True)

	# オブジェクト削除
	$RSA.Dispose()

	return $ByteData
}

##################################################
# CSP キーコンテナのインポート
##################################################
function RSAImportCSP($ContainerName, $ExpoprtByte){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	# インポート
	$RSA.ImportCspBlob($ExpoprtByte)

	# オブジェクト削除
	$RSA.Dispose()

	return
}

##################################################
# CSP キーコンテナ削除
##################################################
function RSARemoveCSP($ContainerName){
	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# CspParameters オブジェクト作成
	$CSPParam = New-Object System.Security.Cryptography.CspParameters

	# CSP キーコンテナ名
	$CSPParam.KeyContainerName = $ContainerName

	# RSACryptoServiceProviderオブジェクト作成
	$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider($CSPParam)

	# CSP キーコンテナ削除
	$RSA.PersistKeyInCsp = $False
	$RSA.Clear()

	# オブジェクト削除
	$RSA.Dispose()

	return
}

###########################################
# SHA256 ハッシュを求める
###########################################
function GetSHA256Hash($BaseByte){

	# アセンブリロード
	Add-Type -AssemblyName System.Security

	# SHA256 オブジェクトの生成
	$SHA = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider

	# SHA256 Hash 値を求める
	$HashBytes = $SHA.ComputeHash($BaseByte)

	# SHA256 オブジェクトの破棄
	$SHA.Dispose()

	return $HashBytes
}


#####################################################################
# 文字列をバイト配列にする
#####################################################################
function String2Byte( $String ){
	$Byte = [System.Text.Encoding]::UTF8.GetBytes($String)
	return $Byte
}

#####################################################################
# バイト配列を文字列にする
#####################################################################
function Byte2String( $Byte ){
	$String = [System.Text.Encoding]::UTF8.GetString($Byte)
	return $String
}

#####################################################################
# Base64 をバイト配列にする
#####################################################################
function Base642Byte( $Base64 ){
	$Byte = [System.Convert]::FromBase64String($Base64)
	return $Byte
}

#####################################################################
# バイト配列を Base64 にする
#####################################################################
function Byte2Base64( $Byte ){
	$Base64 = [System.Convert]::ToBase64String($Byte)
	return $Base64
}

#####################################################################
# 指定場所から指定バイト数取り出す
#####################################################################
function GetByteDate($Byte, $Start, $Length ){
	if( $Length -eq $null ){
		$DataSize = $Byte.Length
		$Length = $DataSize - $Start
	}

	$End = $Start + $Length

	$ReturnData = New-Object byte[] $Length

	$j = 0
	for($i = $Start; $i -lt $End; $i++){
		$ReturnData[$j] = $Byte[$i]
		$j++
	}

	return $ReturnData
}

#################################################
# セキュアストリングから平文にコンバートする
#################################################
function SecureString2PlainString($SecureString){
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
	$PlainString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)

	# $BSTRを削除
	[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

	return $PlainString
}

#####################################################################
# 公開鍵の存在確認
#####################################################################
function ExistTestPublicKey($PublicKey){
	# 公開鍵の存在確認
	if( -not ( Test-Path $PublicKey )){
		# 拡張子付加してみる
		$TmpPublicKey = $PublicKey + $C_PublicKeyExtentPart
		if( -not (Test-Path $TmpPublicKey )){
			# サフィックス追加してみる
			$TmpPublicKey = $PublicKey + $C_PublicKeyExtent
			if( -not (Test-Path $TmpPublicKey )){
				# default 格納場所確認
				$TmpPublicKey = Join-Path $C_PulicKeyLocation $PublicKey
				if( -not (Test-Path $TmpPublicKey )){
					# default に拡張子付加してみる
					$TmpPublicKey = Join-Path $C_PulicKeyLocation ($PublicKey + $C_PublicKeyExtentPart)
					if( -not (Test-Path $TmpPublicKey )){
						# default にサフィックス追加してみる
						$TmpPublicKey = Join-Path $C_PulicKeyLocation ($PublicKey + $C_PublicKeyExtent)
						if( -not (Test-Path $TmpPublicKey )){
							return $null
						}
					}
				}
			}
		}
		$PublicKey = $TmpPublicKey
	}
	return $PublicKey
}

#####################################################################
# 暗号化処理
#####################################################################
function Encrypto( [string[]]$PublicKeys, $Path, $Outfile ){

	# 必須チェック
	if( $PublicKeys.Count -eq 0 ){
		echo "-PublicKeys not set."
		exit
	}

	if( $Path -eq [string]$null ){
		echo "-Path not set."
		exit
	}

	# バージョン番号をバイト配列にする
	$VertionNameByte = String2Byte $C_Vertion

	# 公開鍵
	$PublicKeyXMLs = @()
	foreach( $PublicKey in $PublicKeys ){
		$PublicKey = ExistTestPublicKey $PublicKey
		if( $PublicKey -eq $null ){
			echo "Fail !! $PublicKey not found."
			exit
		}

		# 公開鍵を読む
		$PublicKeyXMLs += Get-Content $PublicKey
	}

	# 公開鍵の数
	$PublicKeyNumber = $PublicKeys.Length
	if( $PublicKeyNumber -ge 0xff ){
		echo "TThe number of public keys is greater than 255."
		exit
	}
	$PublicKeyNumberByte = New-Object byte[] 1
	$PublicKeyNumberByte[0] = [byte]$PublicKeyNumber

	# 対象ファイル存在確認
	if( -not (Test-Path $Path )){
		echo "Fail !! $Path not found."
		exit
	}

	# 平文ファイルをバイナリリードする
	$PlainFileDataByte = [System.IO.File]::ReadAllBytes($Path)

	# オリジナルファイル名
	$OriginalFileNameString = Split-Path $Path -Leaf

	# オリジナルファイル名をバイト配列にする
	$OriginalFileNameByte = String2Byte $OriginalFileNameString

	# ファイル名長
	$OriginalFileNameLength = $OriginalFileNameByte.Length
	if( $OriginalFileNameLength -ge 0xff ){
		echo "The size of the file names longer than 255 characters."
		exit
	}
	$OriginalFileNameLengthByte = New-Object byte[] 1
	$OriginalFileNameLengthByte[0] = [byte]$OriginalFileNameLength

	# 256 bit のセッション鍵生成
	$SessionKeyByte = CreateRandomKey $C_SessionKeyLength

	# セッション鍵を使い平文を AES256 で暗号化
	$EncryptoFileDataByte = AESEncrypto $SessionKeyByte $PlainFileDataByte

	$EncryptoSessionKeyByte = @()
	foreach( $PublicKeyXML in $PublicKeyXMLs ){
		# セッション鍵を RSA 公開鍵で暗号化
		$EncryptoSessionKeyByte += RSAEncrypto $PublicKeyXML $SessionKeyByte
	}

	# 各データー連結
	# $EncriptoDataByte = $OriginalFileNameLengthByte + $OriginalFileNameByte + $PublicKeyNumberByte + $EncryptoSessionKeyByte + $EncryptoFileDataByte
	$EncriptoDataByte = $VertionNameByte + `			# バージョン
					$OriginalFileNameLengthByte + `		# ファイル名長
					$OriginalFileNameByte + `			# ファイル名
					$PublicKeyNumberByte + `			# 公開鍵数
					$EncryptoSessionKeyByte + `			# 公開鍵暗号化セッション鍵
					$EncryptoFileDataByte				# IV + AES256暗号文


	# 署名を作る
	$SignatureByte = RSASignatureCSP $C_ContainerName $EncriptoDataByte

	# 署名する
	# $SignaturedEncriptoDataByte = $SignatureByte + $EncriptoDataByte
	$SignaturedEncriptoDataByte = $SignatureByte + `	# 署名
					$EncriptoDataByte					# データ

	# 出力ファイル名が未指定の場合はデフォルトの出力ファイル名にする
	if( $Outfile -eq [string]$null ){
		# Path
		$Parent = Split-Path $path -Parent

		#ファイル名
		$Leaf = Split-Path $path -Leaf

		# 拡張子抜きのファイル名
		$FileName = $Leaf.Split(".")
		$NonExtensionFileName = ""
		$Index = $FileName.Length
		for( $i = 0; $i -lt ($Index -1); $i++){
			$NonExtensionFileName += $FileName[$i]
			$NonExtensionFileName += "."
		}

		# 拡張子付る
		$EncriptoFileName = $NonExtensionFileName + $C_Extension

		# 出力ファイル名にする
		$Outfile = Join-Path $Parent $EncriptoFileName
	}

	try{
		# ファイルに出力する
		[System.IO.File]::WriteAllBytes($Outfile ,$SignaturedEncriptoDataByte)
	}
	catch{
		echo "Encrypto fail !! ： $Outfile"
		exit
	}

	echo "Encrypto $Outfile"
}

#####################################################################
# 復号化処理
#####################################################################
function Decrypto( [string[]]$PublicKeys, $Path, $Outfile ){

	# 必須チェック
	if( $Path -eq [string]$null ){
		echo "-Path not set."
		exit
	}

	# バージョン番号をバイト配列にする
	$VertionNameByte = String2Byte $C_Vertion

	if($PublicKeys.Count -ne 0 ){
		# 公開鍵の存在確認
		$PublicKey = $PublicKeys[0]
		$PublicKey = ExistTestPublicKey $PublicKey
		if( $PublicKey -eq $null ){
			echo "Fail !! $PublicKey not found."
			exit
		}

		# 公開鍵を読む
		$PublicKeyXML = Get-Content $PublicKey
	}

	# 対象ファイル存在確認
	if( -not (Test-Path $Path )){
		echo "Fail !! $Path not found."
		exit
	}

	# 署名済み暗号文を読む
	$SignaturedEncriptoDataBytes = [System.IO.File]::ReadAllBytes($Path)

	### データーを署名と署名以外/各パートに分解
	# 署名
	$SignatureByte = GetByteDate $SignaturedEncriptoDataBytes 0 $C_SignatureLength
	$IndexPoint = $C_SignatureLength

	# バージョン
	$VertionLength = $VertionNameByte.Length
	$VertionByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint $VertionLength
	$VertionByteString = Byte2String $VertionByte

	# バージョンチェック
	$VertionNum = $VertionByteString -as [int]
	if( $VertionNum -ge 2 ){
		# Ver. 2 以降
		$IndexPoint += $VertionLength
	}
	else{
		# Ver.1 互換
		# 署名済み暗号文を読む
		$SignaturedEncriptoDataBase64 = Get-Content $Path
		# 署名済み暗号文をバイト配列にする
		$SignaturedEncriptoDataBytes = Base642Byte $SignaturedEncriptoDataBase64
		# 署名
		$SignatureByte = GetByteDate $SignaturedEncriptoDataBytes 0 $C_SignatureLength
		$IndexPoint = $C_SignatureLength
	}

	# ファイル名長を格納している Index
	$OriginalFileNameLengthByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint 1
	$IndexPoint += 1
	$FileNameLength = $OriginalFileNameLengthByte[0]

	# ファイル名
	$OriginalFileNameByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint $FileNameLength
	$IndexPoint += $FileNameLength

	# セッション鍵の数
	$PublicKeyNumberByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint 1
	$IndexPoint += 1
	$PublicKeyNumber = $PublicKeyNumberByte[0]

	# 暗号化されたセッション鍵
	$EncryptoSessionKeysLength = $C_EncryptoSessionKeyLength * $PublicKeyNumber
	$EncryptoSessionKeysByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint $EncryptoSessionKeysLength
	$IndexPoint += $EncryptoSessionKeysLength

	# 暗号文
	$EncryptoFileDataByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint $null

	# 署名されたブロック
	$IndexPoint = $C_SignatureLength
	$SignatureBlockByte = GetByteDate $SignaturedEncriptoDataBytes $IndexPoint $null

	# 公開鍵で署名確認
	if( $PublicKeyXML -ne $null ){
		$Result = RSAVerifySignature $PublicKeyXML $SignatureByte $SignatureBlockByte
		if( $Result -ne $True ){
			echo "Signature fail !!"
			exit
		}
		else{
			echo "Signature OK"
		}
	}

	# セッション鍵を秘密鍵で復号
	$i = 0
	while($true){
		# セッション鍵を分解
		$IndexPoint = $C_EncryptoSessionKeyLength * $i
		$EncryptoSessionKeyByte = GetByteDate $EncryptoSessionKeysByte $IndexPoint $C_EncryptoSessionKeyLength

		$SessionKeyByte = RSADecryptoCSP $C_ContainerName $EncryptoSessionKeyByte

		# 復号出来たら抜ける
		if( $SessionKeyByte -ne $null ){
			break
		}

		$i++

		# 復号できなかった
		if( $i -ge $PublicKeyNumber){
			echo "Session Key decrypto fail"
			exit
		}
	}

	# 暗号文をセッション鍵で復号
	$PlainFileDataByte = AESDecrypto $SessionKeyByte $EncryptoFileDataByte
	if( $PlainFileDataByte -eq $null ){
		echo "Decrypto fail"
		exit
	}

	# ファイル名指定がなかったらオリジナルのファイル名を使う
	if( $Outfile -eq [string]$null ){
		# ファイル名を文字列にする
		$FileName =Byte2String $OriginalFileNameByte

		# 入力ファイルのパスと同じ場所に出力
		$Parent = Split-Path $path -Parent

		# パス組み立て
		$OutFile = Join-Path $Parent $FileName
	}

	# 平文ファイル出力
	try{
		[System.IO.File]::WriteAllBytes($Outfile, $PlainFileDataByte)
	}
	catch{
		echo "Decrypto fail !! ： $Outfile"
		exit
	}

	echo "Decrypto $Outfile"
}

#####################################################################
# 鍵ペア作成処理
#####################################################################
function CreateKeyPeers($Outfile){

	# ログインユーザー名取得
	$MyName = $env:USERNAME

	# 鍵ペア生成
	$PublicKey = RSACreateKeyCSP $C_ContainerName

	# 出力ファイル名が未指定の場合はデフォルトの出力ファイル名にする
	if( $Outfile -eq [string]$null ){
		# 出力フォルダがなければ作成
		if( -not (Test-Path $C_PulicKeyLocation)){
			md $C_PulicKeyLocation
		}

		#ファイル名
		$OutputFileName = $MyName + $C_PublicKeyExtent

		# 出力ファイル名にする
		$Outfile = Join-Path $C_PulicKeyLocation $OutputFileName
	}

	# 公開鍵出力
	Set-Content -Path $Outfile -Value $PublicKey

	echo "Public Key: $Outfile"

	# エクスプローラーで開く
	ii (Split-Path $Outfile -Parent)

}


#####################################################################
# Export ファイル名とディレクトリ名
#####################################################################
function ExportPathAndFileName($ExportDirectory){
	# エクスポート先のディレクトリとファイル名作成
	$Leaf = Split-Path -Leaf $ExportDirectory
	$Parent = Split-Path -Parent $ExportDirectory

	[array]$PartOfExt = $Leaf.Split(".")
	if( $PartOfExt.Count -eq 1 ){
		# ノーマル処理
		$ExportFullFileName = Join-Path $ExportDirectory $C_ExportFileName
	}
	else{
		# ファイル名が指定されているので、上位パスをエクスポート先ディレクトリにする
		$ExportDirectory = $Parent
		$ExportFullFileName = Join-Path $ExportDirectory $C_ExportFileName
	}

	return $ExportDirectory, $ExportFullFileName
}


#####################################################################
# Export処理
#####################################################################
function Export($ExportDirectory){

	$Return = ExportPathAndFileName $ExportDirectory

	$ExportDirectory = $Return[0]
	$ExportFullFileName = $Return[1]

	# パスワード入力
	$PasswordSecureString = Read-Host -Prompt "Input Password" -AsSecureString
	$PlainPasswordString = SecureString2PlainString $PasswordSecureString

	# パスワード再入力
	$ConfirmPasswordSecureString = Read-Host -Prompt "Confirm Password" -AsSecureString
	$PlainConfirmPasswordString = SecureString2PlainString $ConfirmPasswordSecureString

	if( $PlainPasswordString -ne $PlainConfirmPasswordString ){
		echo "Unmatch !!"
		exit
	}

	# パスワードをバイト列にする
	$PlainPasswordByte = String2Byte $PlainPasswordString

	# パスワードの SHA 256 ハッシュ値を求める
	$PasswordHashByte = GetSHA256Hash $PlainPasswordByte

	# キーコンテナを Export する
	$PlainExportByte = RSAExportCSP $C_ContainerName

	# エクスポートデーターを AES 256 で暗号化する
	$EncryptoExportByte = AESEncrypto $PasswordHashByte $PlainExportByte

	# Base64 にする
	$EncryptoExportBase64 = Byte2Base64 $EncryptoExportByte

	# エクスポートフォルダがなければ作成
	if( -not (Test-Path $ExportDirectory)){
		md $ExportDirectory
	}
	elseif(Test-Path $ExportFullFileName){
		# すでにエクスポートがあるので、上書き確認
		$Status = Read-Host -Prompt "Do you want to overwrite the export private key ? [Y/N]"
		if( $Status -ne "Y" ){
			echo "Export canceled."
			exit
		}
	}

	# エクスポート出力
	Set-Content -Path $ExportFullFileName -Value $EncryptoExportBase64

	echo "Export File: $ExportFullFileName"

	# エクスプローラーで開く
	ii $ExportDirectory

}

#####################################################################
# Export データー復号化
#####################################################################
function DecryptoExportData($ExportDirectory){

	$Return = ExportPathAndFileName $ExportDirectory

	$ExportDirectory = $Return[0]
	$ExportFullFileName = $Return[1]

	# エクスポートファイル存在確認
	if( -not (Test-Path $ExportFullFileName)){
		echo "Fail !! $ExportFullFileName not found."
		exit
	}

	# Export ファイルを読む
	$EncryptoExportBase64 = Get-Content $ExportFullFileName

	# バイト配列にする
	$EncryptoExportBytes = Base642Byte $EncryptoExportBase64

	# パスワード入力
	$PasswordSecureString = Read-Host -Prompt "Input Password" -AsSecureString
	$PlainPasswordString = SecureString2PlainString $PasswordSecureString

	# パスワードをバイト列にする
	$PlainPasswordByte = String2Byte $PlainPasswordString

	# パスワードの SHA 256 ハッシュ値を求める
	$PasswordHashByte = GetSHA256Hash $PlainPasswordByte

	# エクスポートデーターを AES 256 で復号化する
	$PlainExportByte = AESDecrypto $PasswordHashByte $EncryptoExportBytes
	if( $PlainExportByte -eq $null ){
		echo "Password unmatch"
		exit
	}

	return $PlainExportByte
}

#####################################################################
# Import処理
#####################################################################
function Import($PlainExportByte){

	# キーコンテナを削除する
	RSARemoveCSP $C_ContainerName

	# キーコンテナを Import する
	RSAImportCSP $C_ContainerName $PlainExportByte
}


#####################################################################
# Main
#####################################################################

# PS バージョンチェック
$PSVertion = $PSVersionTable.PSVersion.Major
if( $PSVertion -lt 3 ){
	echo "PowerShell Vertion 3 未満はサポートしていません"
	exit
}
elseif($PSVertion -eq 6){
	echo "PowerShell Vertion 6 は現状サポートしていません"
	exit
}

# 省略オプションの補完
if( $Mode -eq $null ){
	if( $Path -ne [string]$null ){
		#ファイル名
		$Leaf = Split-Path $Path -Leaf

		# ファイル名を分解
		$FileName = $Leaf.Split(".")

		# 拡張子
		$ExtensionName = $FileName[$FileName.Count -1]

		if( $ExtensionName -eq $C_Extension ){
			# 拡張子が暗号ファイル名だったら復号
			$Mode = $C_Mode_Decrypto
		}
		else{
			# それ以外は暗号
			$Mode = $C_Mode_Encrypto
		}
	}
}

Switch($Mode){
	# 復号化
	$C_Mode_Decrypto {
		Decrypto $PublicKeys $Path $Outfile
	}

	# 暗号化
	$C_Mode_Encrypto {
		Encrypto $PublicKeys $Path $Outfile
	}

	# 鍵作成
	$C_Mode_CreateKey {
		CreateKeyPeers $Outfile
	}

	# 鍵削除
	$C_Mode_RemoveKey {
		$Status = Read-Host -Prompt "Do you want to remove the private key ? [Y/N]"
		if( $Status -eq "Y" ){
			RSARemoveCSP $C_ContainerName
			echo "Remove complete"
		}
		else{
			echo "Not removed"
		}
	}

	# Export
	$C_Mode_Export {
		if( $Outfile -eq [string]$null ){
			# 無指定の場合は Default エクスポート先を使用
			$Outfile = $C_ExportDirectory
		}
		Export $Outfile
	}

	# Import
	$C_Mode_Import {
		if( $Path -eq [string]$null ){
			# 無指定の場合は Default エクスポート先を使用
			$Path = $C_ExportFullFileName
		}
		$PlainExportByte = DecryptoExportData $Path
		Import $PlainExportByte
		echo "Import complete"
	}

	# Test
	$C_Mode_Test {
		if( $Path -eq [string]$null ){
			# 無指定の場合は Default エクスポート先を使用
			$Path = $C_ExportFullFileName
		}
		$PlainExportByte = DecryptoExportData $Path
		echo "Test OK"
	}

	Default {
		Get-Help $C_ScriptFullFileName
	}
}
