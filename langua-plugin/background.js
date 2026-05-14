function drawIcon(size) {
  const canvas = new OffscreenCanvas(size, size);
  const ctx = canvas.getContext('2d');

  // 渐变圆形背景
  const grad = ctx.createLinearGradient(0, 0, size, size);
  grad.addColorStop(0, '#1a1a2e');
  grad.addColorStop(1, '#0f3460');
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.arc(size/2, size/2, size/2, 0, Math.PI * 2);
  ctx.fill();

  // 白色"文"
  ctx.fillStyle = '#ffffff';
  ctx.font = `bold ${Math.round(size * 0.52)}px "PingFang SC", sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('文', size/2, size/2);

  return ctx.getImageData(0, 0, size, size);
}

chrome.runtime.onInstalled.addListener(setIcon);
chrome.runtime.onStartup.addListener(setIcon);

function setIcon() {
  chrome.action.setIcon({
    imageData: {
      16:  drawIcon(16),
      24:  drawIcon(24),
      32:  drawIcon(32),
      48:  drawIcon(48),
      128: drawIcon(128),
    }
  });
}
