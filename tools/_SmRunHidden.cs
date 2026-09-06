// Launches a console program with no window at all.
//
// Task Scheduler offers no way to suppress the console for a task that must run
// in the interactive session, and "powershell.exe -WindowStyle Hidden" still
// flashes: Windows creates the console before PowerShell can hide it. Compiling
// this as /target:winexe puts it in the GUI subsystem, so no console is ever
// allocated for the launcher, and CREATE_NO_WINDOW keeps the child from getting
// one either.
//
// Usage: SmRunHidden.exe <executable> [arguments...]
// The child's exit code is passed through so Task Scheduler still reports it.
using System;
using System.Diagnostics;

internal static class SmRunHidden
{
    private const int ExitNoTarget = 2;
    private const int ExitNotStarted = 3;
    private const int ExitLaunchFailed = 4;

    private static int Main()
    {
        // Parse the raw command line rather than string[] args: the target's own
        // quoting has to survive intact, and args[] has already consumed a level
        // of escaping.
        string rest = StripFirstToken(Environment.CommandLine);
        if (rest.Length == 0) { return ExitNoTarget; }

        string target = ReadFirstToken(rest);
        string targetArgs = StripFirstToken(rest);
        if (target.Length == 0) { return ExitNoTarget; }

        ProcessStartInfo psi = new ProcessStartInfo(target, targetArgs);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;

        try
        {
            using (Process child = Process.Start(psi))
            {
                if (child == null) { return ExitNotStarted; }
                child.WaitForExit();
                return child.ExitCode;
            }
        }
        catch
        {
            return ExitLaunchFailed;
        }
    }

    // Index just past the first token, skipping leading whitespace. A token that
    // opens with a quote runs to its closing quote so paths with spaces survive.
    private static int FindTokenEnd(string text, out int start)
    {
        int i = 0;
        while (i < text.Length && (text[i] == ' ' || text[i] == '\t')) { i++; }
        start = i;
        if (i >= text.Length) { return i; }

        if (text[i] == '"')
        {
            i++;
            while (i < text.Length && text[i] != '"') { i++; }
            if (i < text.Length) { i++; }
        }
        else
        {
            while (i < text.Length && text[i] != ' ' && text[i] != '\t') { i++; }
        }
        return i;
    }

    private static string ReadFirstToken(string text)
    {
        int start;
        int end = FindTokenEnd(text, out start);
        return text.Substring(start, end - start).Trim('"');
    }

    private static string StripFirstToken(string text)
    {
        int start;
        int end = FindTokenEnd(text, out start);
        return text.Substring(end).TrimStart(' ', '\t');
    }
}
