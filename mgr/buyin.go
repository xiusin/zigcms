package mgr

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/chromedp/cdproto/cdp"
	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
	"github.com/kataras/golog"
)

type Buyin struct {
	*HeadlessCtx
	_cookies []string
}

func (hctx *Buyin) Run() {
	defer hctx.Done()
	actX, aCancel := chromedp.NewExecAllocator(hctx.ctx, hctx.Opts()...)
	ctx, cancel := chromedp.NewContext(actX)
	defer aCancel()
	defer cancel()

	tasks := chromedp.Tasks{
		chromedp.ActionFunc(func(ctx context.Context) error {
			if len(hctx._cookies) > 0 {
				expr := cdp.TimeSinceEpoch(time.Now().Add(180 * 24 * time.Hour))
				for i := 0; i < len(hctx._cookies); i += 2 {
					err := network.SetCookie(hctx._cookies[i], hctx._cookies[i+1]).
						WithExpires(&expr).WithDomain(".jinritemai.com").
						WithSameSite(network.CookieSameSiteNone).WithSecure(true).Do(ctx)
					if err != nil {
						return err
					}
				}
			}
			return nil
		}),
		chromedp.Navigate(hctx.GetUrl()),
	}
	if err := chromedp.Run(ctx, tasks); err != nil {
		golog.Error(err)
		return
	}

	fmt.Println("exit")
	// go hctx.event(ctx, "/dashboard")
	<-hctx.quit
}

func (hctx *Buyin) triggerErr() {
	hctx.mgr.Lock()
	hctx.mgr.Errs[hctx.Id] = ErrScanBuyInNoAuth
	hctx.mgr.Unlock()
	hctx.Quit()
}

func (hctx *Buyin) event(ctx context.Context, landFace string) {
	var times = 0
	for {
		select {
		case <-hctx.ticker.C:
			times++
			_ = chromedp.Run(ctx, chromedp.Evaluate("localStorage.setItem('buyin-daren-home-new-user-modal-shown', '1');", nil)) // 关闭引导手册
			url := hctx.CurrentUrl(ctx)
			if times%5 == 0 {
				hctx.GetSnapshot(ctx, "百应")
			}

			if strings.Contains(url, "douyinec") {
				hctx.triggerErr()
				return
			}
			if !strings.Contains(url, "/live/control") && hctx.GetNodeCnt(ctx, ".daren-entry-desc") > 0 { // 百应面板
				var content = ""
				chromedp.Run(ctx, chromedp.Evaluate(`document.querySelector(".daren-entry-desc").innerText`, &content))
				if strings.Contains(content, "需要同时满足以下4个条件") { // 未开通巨量百应
					hctx.triggerErr()
					return
				}
			}
			if strings.Contains(url, "/live/control") {
				if !hctx.IsLiving(ctx) {
					continue
				}
				if hctx.GetNodeCnt(ctx, "#live-control-goods-list-container .index__goodsItem___38cLa") < 1 {
					continue
				}
				fmt.Println("点击", chromedp.Run(ctx, chromedp.Click("#live-control-goods-list-container .index__goodsItem___38cLa:nth-child(2) .index__goodsAction___1Pz3g > div:nth-child(5) > button", chromedp.ByQuery)))
			}

		case <-ctx.Done():
			return
		}
	}
}

func (hctx *Buyin) GetUrl() string {
	return "https://buyin.jinritemai.com/dashboard/live/control"
}

func (hctx *Buyin) IsLiving(ctx context.Context) bool {
	return strings.Contains(hctx.GetInnerText(ctx, ".index__liveIconContainer___10BaY .index__liveTag___3-ewu"), "直播中")
}
