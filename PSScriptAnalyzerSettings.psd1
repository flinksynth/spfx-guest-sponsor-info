@{
  ExcludeRules = @(
    # Admin and interactive setup scripts use Write-Host intentionally for
    # coloured terminal output. Write-Output does not support colours;
    # using it would require redirecting to the console host explicitly.
    'PSAvoidUsingWriteHost'
  )
}
