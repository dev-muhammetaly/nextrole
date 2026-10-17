Add-Type -AssemblyName System.Drawing
$webRoot = Join-Path $PSScriptRoot '../web'
foreach ($size in @(32, 192, 512)) {
  $bitmap = New-Object System.Drawing.Bitmap($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = 'AntiAlias'
  $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#3563e9'))
  $pen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#eeeaf8'), ($size * 0.09))
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $a = [single]($size * 0.29); $b = [single]($size * 0.71)
  $graphics.DrawLine($pen, $a, $b, $b, $a)
  $graphics.DrawLine($pen, $a, $a, $b, $a)
  $graphics.DrawLine($pen, $b, $a, $b, $b)
  $target = if ($size -eq 32) { Join-Path $webRoot 'favicon.png' } else { Join-Path $webRoot "icons/Icon-$size.png" }
  $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
  if ($size -ne 32) { $bitmap.Save((Join-Path $webRoot "icons/Icon-maskable-$size.png"), [System.Drawing.Imaging.ImageFormat]::Png) }
  $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$bitmap = New-Object System.Drawing.Bitmap(1200, 630)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = 'AntiAlias'
$graphics.TextRenderingHint = 'AntiAliasGridFit'
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#3563e9'))
$cream = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#faf9f6'))
$lime = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#eeeaf8'))
$brandFont = New-Object System.Drawing.Font('Arial', 28, [System.Drawing.FontStyle]::Bold)
$titleFont = New-Object System.Drawing.Font('Arial', 64, [System.Drawing.FontStyle]::Bold)
$smallFont = New-Object System.Drawing.Font('Arial', 20)
$graphics.DrawString('nextrole.', $brandFont, $lime, 70, 55)
$graphics.DrawString("Find work that`nfeels like you.", $titleFont, $cream, 65, 175)
$graphics.DrawString('Explore possibilities. An internship portfolio demo.', $smallFont, $lime, 70, 520)
$bitmap.Save((Join-Path $webRoot 'social-card.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose(); $cream.Dispose(); $lime.Dispose(); $brandFont.Dispose(); $titleFont.Dispose(); $smallFont.Dispose()

