$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:8000/")
$listener.Prefixes.Add("http://localhost:8000/")
$listener.Start()

Write-Host "Serving $root at http://localhost:8000/"

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
  ".png" = "image/png"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".gif" = "image/gif"
  ".svg" = "image/svg+xml"
  ".ico" = "image/x-icon"
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $requestPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))

    if ([string]::IsNullOrWhiteSpace($requestPath)) {
      $requestPath = "index.html"
    }

    $fullPath = Join-Path $root $requestPath
    $resolvedPath = [System.IO.Path]::GetFullPath($fullPath)

    if (-not $resolvedPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
      $context.Response.StatusCode = 403
      $context.Response.Close()
      continue
    }

    if (-not [System.IO.File]::Exists($resolvedPath)) {
      $context.Response.StatusCode = 404
      $context.Response.Close()
      continue
    }

    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
    $context.Response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }

    $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
  }
}
finally {
  $listener.Stop()
}
