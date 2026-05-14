/**
 * 中文分词 + 拼音标注模块
 * 使用最大正向匹配（Maximum Forward Matching）算法
 * 结合词典优先匹配，保证多音字读音准确
 */

const Segmenter = (() => {
  // 最大匹配长度（词典中最长词的字符数）
  const MAX_WORD_LEN = 6;

  /**
   * 对一段文本进行分词，返回 [{word, pinyin:[...]}] 数组
   * @param {string} text - 输入文本
   * @returns {Array<{word: string, pinyin: string[]}>}
   */
  function segment(text) {
    const result = [];
    let i = 0;
    while (i < text.length) {
      const ch = text[i];
      // 非中文字符，直接逐字输出
      if (!isChinese(ch)) {
        result.push({ word: ch, pinyin: [] });
        i++;
        continue;
      }
      // 尝试最大正向匹配
      let matched = false;
      for (let len = Math.min(MAX_WORD_LEN, text.length - i); len >= 1; len--) {
        const word = text.slice(i, i + len);
        if (WORD_DICT[word]) {
          result.push({ word, pinyin: WORD_DICT[word] });
          i += len;
          matched = true;
          break;
        }
      }
      // 未匹配到词典词，使用单字拼音
      if (!matched) {
        result.push({ word: ch, pinyin: CHAR_DICT[ch] ? [CHAR_DICT[ch]] : [] });
        i++;
      }
    }
    return result;
  }

  /**
   * 给定一段文本和目标字符在文本中的偏移量，返回该字符的上下文拼音
   * @param {string} text - 包含目标字符的上下文文本
   * @param {number} charOffset - 目标字符在 text 中的索引
   * @returns {string} 拼音（如 "zhōng"），未找到返回 ""
   */
  function getPinyinAt(text, charOffset) {
    const tokens = segment(text);
    let pos = 0;
    for (const token of tokens) {
      if (charOffset >= pos && charOffset < pos + token.word.length) {
        const idxInWord = charOffset - pos;
        const py = token.pinyin[idxInWord];
        return py || CHAR_DICT[token.word[idxInWord]] || "";
      }
      pos += token.word.length;
    }
    return CHAR_DICT[text[charOffset]] || "";
  }

  function isChinese(ch) {
    const code = ch.charCodeAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) ||
           (code >= 0x3400 && code <= 0x4DBF) ||
           (code >= 0x20000 && code <= 0x2A6DF);
  }

  return { segment, getPinyinAt, isChinese };
})();
