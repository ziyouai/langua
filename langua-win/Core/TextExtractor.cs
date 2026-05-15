using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Automation;

namespace LanguaWin.Core;

/// <summary>
/// 从光标位置或选区提取中文文本。
/// 策略 1：UI Automation TextPattern（标准控件）
/// 策略 2：模拟 Ctrl+C，读取剪贴板（微信等自定义视图兜底）
/// </summary>
public class TextExtractor
{
    private readonly PinyinEngine _pinyin;

    public TextExtractor(PinyinEngine pinyin)
    {
        _pinyin = pinyin;
    }

    /// <summary>提取鼠标位置下的单字</summary>
    public string? CharAtPoint(MouseHook.POINT pt)
    {
        try
        {
            var winPt = new Point(pt.X, pt.Y);
            var el = AutomationElement.FromPoint(winPt);
            if (el == null) return null;

            if (!el.TryGetCurrentPattern(TextPattern.Pattern, out var obj)) return null;
            var tp = (TextPattern)obj;
            var range = tp.RangeFromPoint(winPt);
            range.ExpandToEnclosingUnit(TextUnit.Character);
            var text = range.GetText(2).Trim();

            return PinyinEngine.ContainsCjk(text) ? text : null;
        }
        catch { return null; }
    }

    /// <summary>提取选中文本（先 AX，再剪贴板兜底）</summary>
    public async Task<string?> SelectedTextAsync(MouseHook.POINT pt)
    {
        // 策略 1：UI Automation 读选区
        try
        {
            var winPt = new Point(pt.X, pt.Y);
            var el = AutomationElement.FromPoint(winPt);
            if (el != null && el.TryGetCurrentPattern(TextPattern.Pattern, out var obj))
            {
                var tp = (TextPattern)obj;
                var sel = tp.GetSelection();
                if (sel.Length > 0)
                {
                    var text = sel[0].GetText(-1).Trim();
                    if (PinyinEngine.ContainsCjk(text)) return text;
                }
            }
        }
        catch { }

        // 策略 2：剪贴板兜底（需在 STA 线程执行）
        return await Task.Run(() => Application.Current.Dispatcher.Invoke(() => TextViaClipboard()));
    }

    private string? TextViaClipboard()
    {
        string? oldText = null;
        try { oldText = Clipboard.GetText(); } catch { }

        // 模拟 Ctrl+C
        var hwnd = GetForegroundWindow();
        if (hwnd != IntPtr.Zero)
            PostMessage(hwnd, 0x0100, (IntPtr)0x43, MakeCtrlDown()); // WM_KEYDOWN C

        SendCtrlC();

        System.Threading.Thread.Sleep(80);

        string? newText = null;
        try { newText = Clipboard.GetText(); } catch { }

        if (newText == null || newText == oldText || !PinyinEngine.ContainsCjk(newText))
            return null;

        // 延迟还原旧内容
        var captured = oldText;
        Task.Delay(350).ContinueWith(_ =>
            Application.Current.Dispatcher.Invoke(() =>
            {
                try { if (captured != null) Clipboard.SetText(captured); else Clipboard.Clear(); }
                catch { }
            }));

        return newText;
    }

    private static void SendCtrlC()
    {
        var inputs = new INPUT[4];

        inputs[0].type = 1; // KEYBOARD
        inputs[0].ki.wVk = 0x11; // VK_CONTROL
        inputs[0].ki.dwFlags = 0;

        inputs[1].type = 1;
        inputs[1].ki.wVk = 0x43; // C
        inputs[1].ki.dwFlags = 0;

        inputs[2].type = 1;
        inputs[2].ki.wVk = 0x43;
        inputs[2].ki.dwFlags = 2; // KEYEVENTF_KEYUP

        inputs[3].type = 1;
        inputs[3].ki.wVk = 0x11;
        inputs[3].ki.dwFlags = 2;

        SendInput(4, inputs, Marshal.SizeOf<INPUT>());
    }

    // ── P/Invoke ──────────────────────────────────────────────────────────────

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUT_UNION { [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT { public uint type; public INPUT_UNION ki; }

    private static IntPtr MakeCtrlDown() => (IntPtr)0x20000000;

    [DllImport("user32.dll")] private static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
