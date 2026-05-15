using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace LanguaWin;

public partial class BubbleWindow : Window
{
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x20;
    private const int WS_EX_LAYERED = 0x80000;
    private const int WS_EX_NOACTIVATE = 0x08000000;

    private System.Threading.Timer? _hideTimer;

    public BubbleWindow()
    {
        InitializeComponent();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        // 设为点击穿透 + 不获取焦点
        var hwnd = new WindowInteropHelper(this).Handle;
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_NOACTIVATE);
    }

    /// <summary>在屏幕坐标 (x, y) 上方显示气泡，autohide 毫秒后自动隐藏</summary>
    public void ShowAt(double x, double y, string pinyin, int autoHideMs = 2500)
    {
        PinyinText.Text = pinyin;

        // 先 layout 获取实际尺寸
        Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Arrange(new Rect(DesiredSize));
        UpdateLayout();

        double w = ActualWidth > 0 ? ActualWidth : DesiredSize.Width;
        double h = ActualHeight > 0 ? ActualHeight : DesiredSize.Height;

        // 气泡居中于光标上方
        Left = x - w / 2;
        Top  = y - h - 12;

        // 防止超出屏幕左边/右边
        var screen = SystemParameters.WorkArea;
        if (Left < screen.Left) Left = screen.Left + 4;
        if (Left + w > screen.Right) Left = screen.Right - w - 4;
        if (Top < screen.Top) Top = y + 16;

        if (!IsVisible) Show();
        Opacity = 1;

        _hideTimer?.Dispose();
        _hideTimer = new System.Threading.Timer(_ =>
            Dispatcher.Invoke(() => FadeOut()), null, autoHideMs, Timeout.Infinite);
    }

    public void HideNow()
    {
        _hideTimer?.Dispose();
        Hide();
    }

    private void FadeOut()
    {
        var anim = new System.Windows.Media.Animation.DoubleAnimation(
            0, TimeSpan.FromMilliseconds(200));
        anim.Completed += (_, _) => Hide();
        BeginAnimation(OpacityProperty, anim);
    }

    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr h, int idx, int val);
}
