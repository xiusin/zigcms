package mgr

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/kataras/golog"

	"github.com/chromedp/chromedp"
)

var ErrScanDaRen = errors.New("需要扫达人二维码")
var ErrScanNoRole = errors.New("抖店还未开通")
var ErrScanBuyInNoAuth = errors.New("无百应电商权限")

type HeadlessCtx struct {
	sync.Mutex
	ctx          context.Context
	cancel       context.CancelFunc
	done         bool
	Id           string
	quit         chan struct{}
	expired      time.Time
	tmpDir       string
	requestId    network.RequestID
	cookies      string
	canGetCookie bool
	ticker       *time.Ticker
	mgr          *CtxMgr
	qrCodeTime   time.Time
	qrcodeData   string
	scanned      bool
}

// IsExpired 是否过期,方式一些进程一直处于未关闭状态
func (hctx *HeadlessCtx) IsExpired() bool {
	return time.Now().After(hctx.expired)
}

func (hctx *HeadlessCtx) IsScanned() bool {
	return hctx.scanned
}

// Done 结束事件
func (hctx *HeadlessCtx) Done() {
	defer delete(hctx.mgr.ctxs, hctx.Id)
	defer func() {
		os.RemoveAll(hctx.tmpDir)
		os.Remove(fmt.Sprintf("snapshots/%s.jpg", hctx.Id))
	}()
	defer hctx.ticker.Stop()

	hctx.cancel()
	hctx.done = true
}

// Quit 退出事件轮询阻塞
func (hctx *HeadlessCtx) Quit() {
	hctx.Lock()
	defer hctx.Unlock()

	if !hctx.done {
		hctx.done = true
		close(hctx.quit)
	}
}

// GetId 获取CtxID
func (hctx *HeadlessCtx) GetId() string {
	return hctx.Id
}

func (hctx *HeadlessCtx) GetNodeCnt(ctx context.Context, sel string) int {
	var res = -1
	chromedp.Run(ctx, chromedp.Evaluate(`document.querySelectorAll("`+sel+`").length`, &res))
	return res
}

func (hctx *HeadlessCtx) Opts() []chromedp.ExecAllocatorOption {
	hctx.tmpDir, _ = os.MkdirTemp("tmp", "*")
	opts := append(pubOpts[:], chromedp.UserDataDir(hctx.tmpDir))
	if runtime.GOOS == "darwin" {
		opts = append(opts, chromedp.ExecPath("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"))
	}
	return opts
}

// HijackingRequest 劫持请求信息
// uri:string 需要劫持的uri
// quit:func 退出的附加条件
func (hctx *HeadlessCtx) HijackingRequest(ctx context.Context, uri string, quit func() bool) {
	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if !hctx.canGetCookie {
			return
		}
		switch ev := ev.(type) {
		case *network.EventRequestWillBeSent:
			if strings.Contains(ev.Request.URL, uri) {
				hctx.requestId = ev.RequestID
			}
		case *network.EventRequestWillBeSentExtraInfo:
			if ev.RequestID == hctx.requestId {
				if cookie := ev.Headers["cookie"]; cookie != nil {
					hctx.cookies = cookie.(string)
					if quit == nil || quit() {
						hctx.Quit()
					}
				}
			}
		}
	})
}

// CurrentUrl 获取浏览器当前地址
func (hctx *HeadlessCtx) CurrentUrl(ctx context.Context) string {
	var currentUrl string
	chromedp.Run(ctx, chromedp.Location(&currentUrl))
	return currentUrl
}

func (hctx *HeadlessCtx) SavePic(photo *string) {
	hctx.qrcodeData = *photo
	hctx.qrCodeTime = time.Now() // qrcode更换日期
}

// SaveClick 保存图片且启动过期刷新事件等待, 刷新过期二维码
func (hctx *HeadlessCtx) SaveClick(ctx context.Context, qrcode *string, clickSels ...string) {
	hctx.SavePic(qrcode)
	if len(clickSels) > 0 {
		go func(ctx context.Context) {
			chromedp.Run(ctx, chromedp.Click(clickSels[0], chromedp.ByQuery))
		}(ctx)
	}
}

func (hctx *HeadlessCtx) GetQrcode(prevQrcodeTime int64) map[string]any {
	data := map[string]any{
		"time":    uint64(hctx.qrCodeTime.UnixNano()),
		"scanned": hctx.IsScanned(),
	}
	if prevQrcodeTime != hctx.qrCodeTime.UnixNano() {
		data["data"] = hctx.qrcodeData
	}
	return data
}

func (hctx *HeadlessCtx) ParseCookie(c string) []string {
	cookieArr := strings.Split(c, ";")
	var mapCookies = map[string]string{}
	for _, cookie := range cookieArr {
		pairs := strings.Split(strings.TrimSpace(cookie), "=")
		if len(pairs) == 2 {
			mapCookies[pairs[0]] = pairs[1]
		}
	}
	var cookies []string
	for k, v := range mapCookies {
		cookies = append(cookies, k, v)
	}
	return cookies
}

func (hctx *HeadlessCtx) WaitSel() string {
	return ".web-login-scan-code__content__qrcode-wrapper__qrcode"
}

func (hctx *HeadlessCtx) GetInnerText(ctx context.Context, sel string) string {
	var content string
	chromedp.Run(ctx, chromedp.Evaluate(`document.querySelector("`+sel+`").innerText`, &content))
	return content
}

func (hctx *HeadlessCtx) GetBtnSel(ctx context.Context, btn string, prefixSel string) string {
	cnt := hctx.GetNodeCnt(ctx, prefixSel)
	for i := 0; i < cnt; i++ {
		sel := prefixSel + `:nth-child(` + fmt.Sprintf("%d", i+1) + `)`
		if strings.Contains(hctx.GetInnerText(ctx, sel), btn) {
			return sel
		}
	}
	return ""
}

func (hctx *HeadlessCtx) getUrlParam(ctx context.Context, param string) string {
	timers, vv, currentUrl := 100, "", ""
	for vv == "" {
		time.Sleep(time.Millisecond * 100)
		_ = chromedp.Run(ctx, chromedp.Location(&currentUrl))
		urlInfo, _ := url.Parse(currentUrl)
		vv = urlInfo.Query().Get(param)
		timers--
		if timers == 0 {
			break
		}
	}

	if vv == "" {
		golog.Debug("无法获取"+param, currentUrl)
	}
	return vv
}

func (hctx *HeadlessCtx) GetSnapshot(ctx context.Context, tip string) {
	if runtime.GOOS == "darwin" {
		return
	}
	defer golog.Debug(tip + "截取快照图片完成")
	var buf []byte
	chromedp.Run(ctx, chromedp.FullScreenshot(&buf, 80))
	os.WriteFile(fmt.Sprintf("snapshots/%s.jpg", hctx.Id), buf, 0o644)
}
