$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$images = @()
foreach ($size in @(16,24,32,48,64,128,256)) {
  $bmp = New-Object System.Drawing.Bitmap($size,$size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.ScaleTransform($size / 256.0, $size / 256.0)
  $navy = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#142E46'))
  $gold = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#E8C477'))
  $teal = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#087F75'))
  $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $g.FillEllipse($navy,4,4,248,248)
  $roof = [System.Drawing.Point[]]@([System.Drawing.Point]::new(35,83),[System.Drawing.Point]::new(115,36),[System.Drawing.Point]::new(195,83))
  $g.FillPolygon($gold,$roof)
  $g.FillRectangle($white,44,91,142,12)
  foreach ($x in @(53,94,135,176)) { $g.FillRectangle($white,$x,110,12,59) }
  $g.FillRectangle($gold,39,175,152,13)
  $g.FillEllipse($teal,145,142,94,94)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White,13)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLines($pen,[System.Drawing.Point[]]@([System.Drawing.Point]::new(166,188),[System.Drawing.Point]::new(187,209),[System.Drawing.Point]::new(218,174)))
  $stream = New-Object System.IO.MemoryStream
  $bmp.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
  $images += @{size=$size;bytes=$stream.ToArray()}
  $stream.Dispose(); $pen.Dispose(); $g.Dispose(); $bmp.Dispose()
  $navy.Dispose(); $gold.Dispose(); $teal.Dispose(); $white.Dispose()
}
$path = Join-Path $PWD 'windows/runner/resources/app_icon.ico'
$writer = New-Object System.IO.BinaryWriter([System.IO.File]::Create($path))
try {
  $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$images.Count)
  $offset = 6 + 16 * $images.Count
  foreach ($img in $images) {
    $dim = if ($img.size -eq 256) { 0 } else { $img.size }
    $writer.Write([byte]$dim); $writer.Write([byte]$dim)
    $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32)
    $writer.Write([uint32]$img.bytes.Length); $writer.Write([uint32]$offset)
    $offset += $img.bytes.Length
  }
  foreach ($img in $images) { $writer.Write([byte[]]$img.bytes) }
} finally { $writer.Dispose() }
