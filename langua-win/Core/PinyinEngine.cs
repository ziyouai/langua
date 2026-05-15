using System.IO;
using System.Text.Json;

namespace LanguaWin.Core;

/// <summary>
/// 拼音查找引擎，使用 pinyin-ext.json（索引 = codepoint - 0x4E00）
/// </summary>
public class PinyinEngine
{
    private readonly string[] _data;

    public PinyinEngine()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Resources", "pinyin-ext.json");
        var json = File.ReadAllText(path);
        _data = JsonSerializer.Deserialize<string[]>(json) ?? [];
    }

    /// <summary>返回单字拼音，非 CJK 字符返回 null</summary>
    public string? GetPinyin(char c)
    {
        int idx = c - 0x4E00;
        if (idx >= 0 && idx < _data.Length)
        {
            var py = _data[idx];
            return string.IsNullOrEmpty(py) ? null : py;
        }
        // Extension A: 0x3400–0x4DBF
        idx = c - 0x3400;
        if (idx >= 0 && idx < 6592) return null; // 暂无数据，返回 null 而不崩溃
        return null;
    }

    /// <summary>返回字符串中所有汉字的拼音，空格分隔</summary>
    public string GetPinyinString(string text)
    {
        var parts = new List<string>();
        foreach (var c in text)
        {
            var py = GetPinyin(c);
            if (py != null) parts.Add(py);
        }
        return string.Join("  ", parts);
    }

    public static bool IsCjk(char c) =>
        (c >= '一' && c <= '鿿') ||
        (c >= '㐀' && c <= '䶿') ||
        (c >= '豈' && c <= '﫿');

    public static bool ContainsCjk(string text) =>
        text.Any(IsCjk);
}
