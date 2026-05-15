using System.Diagnostics;
using System.Runtime.InteropServices;

namespace LanguaWin.Core;

/// <summary>
/// 全局低级鼠标钩子，鼠标静止 200ms 后触发 OnIdle，鼠标松开触发 OnMouseUp。
/// </summary>
public sealed class MouseHook : IDisposable
{
    private const int WH_MOUSE_LL = 14;
    private const int WM_MOUSEMOVE = 0x0200;
    private const int WM_LBUTTONUP = 0x0202;

    public event EventHandler<POINT>? OnIdle;
    public event EventHandler<POINT>? OnMouseUp;

    private IntPtr _hookId = IntPtr.Zero;
    private readonly LowLevelMouseProc _proc;
    private System.Threading.Timer? _idleTimer;
    private POINT _lastPoint;
    private bool _disposed;

    public MouseHook()
    {
        _proc = HookCallback;
    }

    public void Start()
    {
        using var cur = Process.GetCurrentProcess();
        using var mod = cur.MainModule!;
        _hookId = SetWindowsHookEx(WH_MOUSE_LL, _proc, GetModuleHandle(mod.ModuleName), 0);
    }

    public void Stop()
    {
        _idleTimer?.Dispose();
        if (_hookId != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_hookId);
            _hookId = IntPtr.Zero;
        }
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var s = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
            if (wParam == WM_MOUSEMOVE)
            {
                _lastPoint = s.pt;
                _idleTimer?.Dispose();
                _idleTimer = new System.Threading.Timer(_ =>
                {
                    var pt = _lastPoint;
                    OnIdle?.Invoke(this, pt);
                }, null, 200, Timeout.Infinite);
            }
            else if (wParam == WM_LBUTTONUP)
            {
                _idleTimer?.Dispose();
                var pt = s.pt;
                Task.Delay(80).ContinueWith(_ => OnMouseUp?.Invoke(this, pt));
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
    }

    // ── P/Invoke ──────────────────────────────────────────────────────────────

    private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSLLHOOKSTRUCT
    {
        public POINT pt;
        public uint mouseData, flags, time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int id, LowLevelMouseProc cb, IntPtr hMod, uint tid);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr id);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr id, int n, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string? name);
}
