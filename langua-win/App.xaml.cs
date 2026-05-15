using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using LanguaWin.Core;

namespace LanguaWin;

public partial class App : System.Windows.Application
{
    private MouseHook? _mouseHook;
    private TextExtractor? _extractor;
    private PinyinEngine? _pinyin;
    private BubbleWindow? _bubble;
    private NotifyIcon? _tray;
    private bool _enabled = true;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _pinyin    = new PinyinEngine();
        _extractor = new TextExtractor(_pinyin);
        _bubble    = new BubbleWindow();
        _mouseHook = new MouseHook();

        _mouseHook.OnIdle    += OnMouseIdle;
        _mouseHook.OnMouseUp += OnMouseUp;
        _mouseHook.Start();

        SetupTray();
    }

    // ── 悬停拼音 ──────────────────────────────────────────────────────────────

    private void OnMouseIdle(object? sender, MouseHook.POINT pt)
    {
        if (!_enabled) return;
        var ch = _extractor!.CharAtPoint(pt);
        if (ch == null) return;

        var py = _pinyin!.GetPinyinString(ch);
        if (string.IsNullOrEmpty(py)) return;

        Dispatcher.Invoke(() => _bubble!.ShowAt(pt.X, pt.Y, py));
    }

    // ── 划词拼音 ──────────────────────────────────────────────────────────────

    private async void OnMouseUp(object? sender, MouseHook.POINT pt)
    {
        if (!_enabled) return;
        var text = await _extractor!.SelectedTextAsync(pt);
        if (text == null) return;

        var py = _pinyin!.GetPinyinString(text);
        if (string.IsNullOrEmpty(py)) return;

        Dispatcher.Invoke(() => _bubble!.ShowAt(pt.X, pt.Y, py, autoHideMs: 3500));
    }

    // ── 系统托盘 ──────────────────────────────────────────────────────────────

    private void SetupTray()
    {
        _tray = new NotifyIcon
        {
            Text    = "Langua — 悬停即见拼音",
            Visible = true,
        };

        // 内嵌生成简单图标（正式版替换为 Resources/icon.ico）
        _tray.Icon = BuildTrayIcon();

        var menu = new ContextMenuStrip();
        var toggleItem = new ToolStripMenuItem("✓  已启用") { Name = "toggle" };
        toggleItem.Click += (_, _) =>
        {
            _enabled = !_enabled;
            toggleItem.Text = _enabled ? "✓  已启用" : "   已暂停";
            if (!_enabled) Dispatcher.Invoke(() => _bubble?.HideNow());
        };

        var quitItem = new ToolStripMenuItem("退出 Langua");
        quitItem.Click += (_, _) =>
        {
            _tray.Visible = false;
            _mouseHook?.Stop();
            Shutdown();
        };

        menu.Items.Add(toggleItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(quitItem);
        _tray.ContextMenuStrip = menu;
    }

    private static Icon BuildTrayIcon()
    {
        // 临时：用系统信息图标，正式版替换为 icon.ico
        return SystemIcons.Information;
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _mouseHook?.Dispose();
        base.OnExit(e);
    }
}
