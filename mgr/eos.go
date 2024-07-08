package mgr

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/chromedp/cdproto/cdp"
	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"
	"golang.org/x/exp/slog"
)

type Eos struct {
	*HeadlessCtx

	userInfoRequestId network.RequestID
	userInfo          *EosUserInfoResp
}

func (hctx *Eos) Run() {
	defer hctx.Done()
	actX, aCancel := chromedp.NewExecAllocator(hctx.ctx, hctx.Opts()...)
	ctx, cancel := chromedp.NewContext(actX)
	defer aCancel()
	defer cancel()

	if err := chromedp.Run(ctx, chromedp.Tasks{
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, err := page.AddScriptToEvaluateOnNewDocument(CleanWebDriver).Do(ctx)
			return err
		}),
		chromedp.EmulateViewport(1280, 800),
		chromedp.Navigate(hctx.GetUrl()),
		chromedp.WaitReady(hctx.WaitSel(), chromedp.ByQuery),
	}); err != nil {
		slog.Error("初始化浏览器失败", slog.Any("平台", "Eos"))
		return
	}

	chromedp.ListenTarget(ctx, func(ev interface{}) {
		switch ev := ev.(type) {
		case *network.EventLoadingFinished:
			if hctx.userInfoRequestId == ev.RequestID {
				go func() {
					c := chromedp.FromContext(ctx)
					body, _ := network.GetResponseBody(ev.RequestID).Do(cdp.WithExecutor(ctx, c.Target))

					var resp EosUserInfoResp
					_ = json.Unmarshal(body, &resp)
					hctx.userInfo = &resp
				}()
			}

		case *network.EventRequestWillBeSent:
			if strings.Contains(ev.Request.URL, "/user/info/v") {
				hctx.userInfoRequestId = ev.RequestID
			}
		}
	})

	hctx.HijackingRequest(ctx, "/data/life/live/status/", func() bool {
		return hctx.userInfo != nil
	})
	go hctx.event(ctx, "/livesite/live/current")
	<-hctx.quit

	hctx.mgr.Lock()
	hctx.mgr.Datas[hctx.Id] = hctx.userInfo
	hctx.mgr.Cookies[hctx.Id] = hctx.cookies
	hctx.mgr.Unlock()
}

// 事件轮询 landFace 落地页特征
func (hctx *Eos) event(ctx context.Context, landFace string) {
	var qrcode = ""
	times := 0
	for {
		select {
		case <-hctx.ticker.C:
			times++
			if times%5 == 0 {
				hctx.GetSnapshot(ctx, "抖音")
			}

			url := hctx.CurrentUrl(ctx)
			if strings.Contains(url, landFace) {
				hctx.canGetCookie = true // 标志可以获取cookie信息
			} else if strings.Contains(url, "/livesite/live/home") {
				slog.Debug("从首页跳转到直播间页面")
				chromedp.Run(ctx, chromedp.Navigate("https://eos.douyin.com/livesite/live/current"))
			} else if strings.Contains(url, "login") { // 防止中间页面
				darenNodeCnt := hctx.GetNodeCnt(ctx, ".src-pages-login-modules-Introductory-index-module__grouponCommerce__ezlqi")
				if darenNodeCnt > 0 {
					hctx.mgr.Lock()
					hctx.mgr.Errs[hctx.Id] = ErrScanDaRen
					hctx.mgr.Unlock()
					hctx.Quit()
					return
				} else if hctx.GetNodeCnt(ctx, hctx.WaitSel()) > 0 {
					var attrs = map[string]string{}
					hctx.scanned = hctx.GetNodeCnt(ctx, ".web-login-scan-code__content__qrcode-wrapper__mask__toast__text") > 0

					chromedp.Run(ctx, chromedp.Attributes(hctx.WaitSel(), &attrs, chromedp.ByQuery))
					if attrs["src"] != qrcode {
						qrcode = attrs["src"]
						hctx.SaveClick(ctx, &qrcode, ".refresh")
					}
				}
			}
		case <-ctx.Done():
			return
		}
	}
}

func (hctx *Eos) GetUrl() string {
	return "https://eos.douyin.com/livesite/login"
}

func (hctx *Eos) WaitSel() string {
	return ".web-login-scan-code__content__qrcode-wrapper__qrcode"
}
