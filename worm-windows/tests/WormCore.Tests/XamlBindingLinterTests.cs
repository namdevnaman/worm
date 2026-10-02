using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Xunit;

namespace WormCore.Tests;

/// <summary>
/// Guards against XAML bindings that compile cleanly but throw the moment the item
/// template is applied.
///
/// The concrete failure this exists for: CleanPage bound WormCheckBox.IsChecked to
/// CategoryRow.TriState with Mode=TwoWay. TriState is a computed get-only property,
/// so WPF raised "A TwoWay or OneWayToSource binding cannot work on the read-only
/// property" from inside StyleHelper.ApplyTemplateContent - a runtime crash that
/// `dotnet build` cannot see, and that the launch smoke test only catches by luck
/// if it happens to populate the list.
///
/// WormUI targets net9.0-windows, so its types cannot be reflected on a non-Windows
/// build agent. The properties are therefore checked against the C# sources, which
/// is what actually decides whether a binding can write back.
/// </summary>
public sealed class XamlBindingLinterTests
{
    /// <summary>
    /// Control properties whose default binding mode is TwoWay, so a Binding with no
    /// explicit Mode on these still writes back to the source.
    /// </summary>
    private static readonly HashSet<string> TwoWayByDefault = new(StringComparer.Ordinal)
    {
        "CheckBox.IsChecked",
        "ToggleButton.IsChecked",
        "RadioButton.IsChecked",
        "TextBox.Text",
        "ComboBox.Text",
        "ListBox.SelectedItem",
        "ComboBox.SelectedItem",
        "ComboBox.SelectedValue",
        "Slider.Value",
        "WormCheckBox.IsChecked",
        "DataGridCheckBoxColumn.IsChecked"
    };

    [Fact]
    public void EveryTwoWayBindingResolvesToAWritableProperty()
    {
        var root = FindRepoRoot();
        var uiDir = Path.Combine(root, "worm-windows", "src", "WormUI");

        var sources = ReadModelSources(uiDir);
        var problems = new List<string>();

        foreach (var xaml in Directory.GetFiles(uiDir, "*.xaml"))
        {
            foreach (var binding in ParseBindings(xaml))
            {
                if (!binding.IsTwoWay) continue;
                if (binding.Path.Contains('.')) continue; // sub-paths are out of scope

                if (!IsWritable(sources, binding.Path))
                {
                    problems.Add(
                        $"{Path.GetFileName(xaml)} binds \"{binding.Path}\" two-way but no " +
                        $"public writable property of that name exists in WormUI");
                }
            }
        }

        Assert.True(
            problems.Count == 0,
            "Two-way bindings must target a settable property:\n  " +
            string.Join("\n  ", problems));
    }

    [Fact]
    public void BindingsOnlyReferencePropertiesThatExist()
    {
        var root = FindRepoRoot();
        var uiDir = Path.Combine(root, "worm-windows", "src", "WormUI");

        var sources = ReadModelSources(uiDir);
        var problems = new List<string>();

        foreach (var xaml in Directory.GetFiles(uiDir, "*.xaml"))
        {
            foreach (var binding in ParseBindings(xaml))
            {
                if (binding.Path.Contains('.')) continue;
                if (IsWritable(sources, binding.Path)) continue;
                if (ExistsAsReadOnly(sources, binding.Path)) continue;

                problems.Add(
                    $"{Path.GetFileName(xaml)} binds \"{binding.Path}\" but WormUI declares " +
                    "no such property");
            }
        }

        Assert.True(
            problems.Count == 0,
            "Bindings must reference a real property:\n  " + string.Join("\n  ", problems));
    }

    // ------------------------------------------------------------------ helpers

    private readonly record struct Binding(string Path, bool IsTwoWay);

    private static IEnumerable<Binding> ParseBindings(string xamlPath)
    {
        var lines = File.ReadAllLines(xamlPath);
        var openElement = "";

        foreach (var raw in lines)
        {
            var line = raw.Trim();

            // Track which element owns the attributes on the following lines.
            var open = Regex.Match(line, @"^<(?<type>[\w:.]+)\b(?<rest>[^>]*?)(?<end>/?>)");
            if (open.Success && !line.StartsWith("</"))
            {
                openElement = open.Groups["type"].Value;
            }

            foreach (Match m in Regex.Matches(line, @"(?<attr>[\w:.]+)=""\{Binding\s+(?<body>[^}]+)\}"""))
            {
                var body = m.Groups["body"].Value;
                var segments = body.Split(',').Select(s => s.Trim()).ToList();

                var path = segments
                    .FirstOrDefault(s => s.StartsWith("Path=", StringComparison.OrdinalIgnoreCase))?
                    .Substring("Path=".Length)
                ?? segments.FirstOrDefault(s => !s.Contains('=')) ?? "";

                var explicitMode = segments
                    .FirstOrDefault(s => s.StartsWith("Mode=", StringComparison.OrdinalIgnoreCase))?
                    .Substring("Mode=".Length);

                bool twoWay = explicitMode != null
                    ? string.Equals(explicitMode, "TwoWay", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(explicitMode, "OneWayToSource", StringComparison.OrdinalIgnoreCase)
                    : TwoWayByDefault.Contains($"{openElement}.{m.Groups["attr"].Value}");

                if (path.Length > 0) yield return new Binding(path, twoWay);
            }

            // A tag that closed on this line no longer owns later attributes.
            if (line.EndsWith(">", StringComparison.Ordinal) && line.Contains("=\"{Binding") is false)
            {
                // keep openElement; attributes may follow on the next line
            }
        }
    }

    /// <summary>
    /// Public property declarations across both projects, with whether each has a
    /// setter. WormCore is included because most DataContext types are the scan and
    /// analyser models it owns, so scanning only WormUI reports them as missing.
    /// Expression-bodied declarations (get =&gt; ...) are read-only.
    /// </summary>
    private static Dictionary<string, bool> ReadModelSources(string uiDir)
    {
        var found = new Dictionary<string, bool>(StringComparer.Ordinal);
        var coreDir = Path.Combine(Directory.GetParent(uiDir)!.FullName, "WormCore");
        var roots = Directory.Exists(coreDir) ? new[] { uiDir, coreDir } : new[] { uiDir };

        foreach (var file in SourceFiles(roots))
        {
            var text = File.ReadAllText(file);

            // Comments would otherwise hide a "get =>" that looks like a setter.
            text = Regex.Replace(text, @"//.*?$", "", RegexOptions.Multiline);
            text = Regex.Replace(text, @"/\*.*?\*/", "", RegexOptions.Singleline);

            // Positional record parameters become public get-only properties, and
            // several DiskPage bindings target exactly those (FolderSize.Path,
            // LargeFile.Age). They have no `public ... Name {` declaration to match.
            foreach (var name in PositionalRecordMembers(text))
                found.TryAdd(name, false);

            foreach (Match m in Regex.Matches(
                         text,
                         @"public\s+(?:required\s+|static\s+|virtual\s+|override\s+)*[\w?\[\]<>,.]+\s+(?<name>\w+)\s*(?<body>=>|\{)"))
            {
                var name = m.Groups["name"].Value;
                var expressionBodied = m.Groups["body"].Value == "=>";

                bool writable;
                if (expressionBodied)
                {
                    writable = false;
                }
                else
                {
                    // Walk the braces to see whether a set accessor appears.
                    var depth = 0;
                    var end = m.Index;
                    for (var i = m.Index + m.Groups["body"].Value.Length - 1;
                         i < text.Length && i < m.Index + 4000; i++)
                    {
                        if (text[i] == '{') depth++;
                        else if (text[i] == '}')
                        {
                            depth--;
                            if (depth == 0) { end = i; break; }
                        }
                    }

                    var bodyText = text.Substring(m.Index, Math.Min(end - m.Index + 1, 4000));
                    writable = Regex.IsMatch(bodyText, @"\bset\b\s*(\{|\;|=>)");
                }

                // A name declared both ways anywhere is treated as writable only if
                // every declaration is writable, which is what this catches.
                found[name] = found.TryGetValue(name, out var existing)
                    ? existing && writable
                    : writable;
            }
        }

        return found;
    }

    /// <summary>
    /// C# sources under the given roots, skipping bin and obj directories
    /// entirely.
    ///
    /// They are pruned at the directory level rather than filtered afterwards:
    /// bin/obj under src is deep, duplicated per RID and framework, and walking
    /// into it is both pointless and the one part of this test that is sensitive
    /// to how long the checkout path happens to be on the current OS.
    /// </summary>
    private static IEnumerable<string> SourceFiles(IEnumerable<string> roots)
    {
        foreach (var root in roots)
        {
            if (!Directory.Exists(root)) continue;

            var pending = new Stack<string>();
            pending.Push(root);

            while (pending.Count > 0)
            {
                var dir = pending.Pop();

                string[] files;
                try { files = Directory.GetFiles(dir, "*.cs"); }
                catch (IOException) { continue; }
                catch (UnauthorizedAccessException) { continue; }

                foreach (var file in files) yield return file;

                string[] children;
                try { children = Directory.GetDirectories(dir); }
                catch (IOException) { continue; }
                catch (UnauthorizedAccessException) { continue; }

                foreach (var child in children)
                {
                    var name = Path.GetFileName(child);
                    if (name == "obj" || name == "bin") continue;
                    pending.Push(child);
                }
            }
        }
    }

    /// <summary>
    /// Parameter names of positional records, which the compiler turns into
    /// get-only public properties.
    /// </summary>
    private static IEnumerable<string> PositionalRecordMembers(string text)
    {
        foreach (Match m in Regex.Matches(text, @"\brecord\s+\w+(?:<[^>]*>)?\s*\("))
        {
            var start = m.Index + m.Length;
            var depth = 1;
            var i = start;

            while (i < text.Length && depth > 0)
            {
                if (text[i] == '(') depth++;
                else if (text[i] == ')') depth--;
                i++;
            }

            var parameterList = text[start..(i - 1)];
            var depth2 = 0;
            var current = new System.Text.StringBuilder();

            foreach (var c in parameterList)
            {
                if (c == '(' || c == '<' || c == '[') depth2++;
                else if (c == ')' || c == '>' || c == ']') depth2--;

                if (c == ',' && depth2 == 0)
                {
                    var param = Yield(current.ToString());
                    current.Clear();
                    if (param != null) yield return param;
                }
                else current.Append(c);
            }

            var last = Yield(current.ToString());
            if (last != null) yield return last;
        }

        static string? Yield(string parameter)
        {
            var text = parameter.Split('=')[0].Trim();
            if (text.Length == 0) return null;

            var match = Regex.Match(text, @"(?<name>\w+)\s*(\?)?\s*(\[.*)?$");
            return match.Success ? match.Groups["name"].Value : null;
        }
    }

    private static bool IsWritable(Dictionary<string, bool> sources, string name)
        => sources.TryGetValue(name, out var writable) && writable;

    private static bool ExistsAsReadOnly(Dictionary<string, bool> sources, string name)
        => sources.ContainsKey(name);

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);

        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "worm-windows", "src", "WormUI")))
                return dir.FullName;

            dir = dir.Parent;
        }

        throw new InvalidOperationException(
            "Could not locate the repository root from " + AppContext.BaseDirectory);
    }
}