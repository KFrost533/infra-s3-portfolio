param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $TerraformArguments
)

$ErrorActionPreference = 'Stop'
$logWriter = $null
$stream = $null
$result = 1
$logDirectory = Join-Path $PSScriptRoot 'log'
$logName = '{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N')
$logPath = Join-Path $logDirectory $logName

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw 'PowerShell 7 or later is required.'
    }
    if ($null -eq $TerraformArguments) {
        $TerraformArguments = @()
    }

    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

public static class TerraformLogRunner
{
    public static int Run(string executable, string[] arguments, StreamWriter log)
    {
        var start = new ProcessStartInfo(executable) {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var argument in arguments) start.ArgumentList.Add(argument);
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Terraform could not be started.");
        var sync = new object();
        Exception logError = null;
        async Task Copy(StreamReader input, TextWriter output)
        {
            var buffer = new char[1024];
            int count;
            while ((count = await input.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                lock (sync)
                {
                    output.Write(buffer, 0, count);
                    output.Flush();
                    if (logError == null)
                    {
                        try { log.Write(buffer, 0, count); log.Flush(); }
                        catch (Exception error) { logError = error; }
                    }
                }
            }
        }
        Task.WhenAll(Copy(process.StandardOutput, Console.Out), Copy(process.StandardError, Console.Error)).GetAwaiter().GetResult();
        process.WaitForExit();
        if (logError != null) throw new IOException("Could not write the complete Terraform log.", logError);
        return process.ExitCode;
    }
}
'@
    $terraform = Get-Command terraform -CommandType Application -ErrorAction Stop | Select-Object -First 1
    New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
    $stream = [System.IO.File]::Open($logPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $logWriter = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
    $logWriter.AutoFlush = $true
    Write-Host "Terraform output log: $logPath"
    $result = [TerraformLogRunner]::Run($terraform.Source, $TerraformArguments, $logWriter)
}
catch {
    [Console]::Error.WriteLine("Terraform logging or execution failed: $($_.Exception.Message)")
    $result = 1
}
finally {
    if ($null -ne $logWriter) {
        try {
            $logWriter.Dispose()
        }
        catch {
            [Console]::Error.WriteLine("Failed to finish the Terraform log: $($_.Exception.Message)")
            $result = 1
        }
    }
    elseif ($null -ne $stream) {
        $stream.Dispose()
    }
}

exit $result
