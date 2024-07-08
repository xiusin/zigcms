package mgr

import (
	"context"
	"time"

	"github.com/chromedp/cdproto/cdp"
	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"
	"github.com/kataras/golog"
)

// https://www.yujn.cn/?action=interface&id=310
//  https://api.yujn.cn/api/shouxie.php?text= 手写文字
// http://api.yujn.cn/api/xiangyin.php? 家乡话文本

type Creator struct {
	*HeadlessCtx
	_cookies []string
}

func (hctx *Creator) Run() {
	defer hctx.Done()
	actX, aCancel := chromedp.NewExecAllocator(hctx.ctx, hctx.Opts()...)
	ctx, cancel := chromedp.NewContext(actX)
	defer aCancel()
	defer cancel()

	cookies := `_tea_utm_cache_2906=undefined; bd_ticket_guard_client_web_domain=2; passport_csrf_token=6fbd3441c531a1f6c3d31c1297814e3c; passport_csrf_token_default=6fbd3441c531a1f6c3d31c1297814e3c; s_v_web_id=verify_lyb43i6t_RpwsQDzQ_uXDk_4Y93_9pkt_WidLNMIkbWnb; d_ticket=7b752f198e07388f66f2399dc20991e339fdd; passport_assist_user=Cjwp9dIRNm8U9lh_vRBfHVPaIdLYL9DFQ1K9VtZuluvHBFPNdxyaEnCzsPAtQQZ_0zAfAbJ68TrZgoNrUgcaSgo8dMYVRGBblb_HvfUZTL8LD1e91dCOnFQl5Dhyagdma17IlvOEz52QbHtIxmSO2qrkCwnL8CPk5tGBu1ftEOiA1g0Yia_WVCABIgEDEbV-_A%3D%3D; n_mh=9MHUz1EyAE_s2YCwU0x7_H8eH2feUZ7-NNBEWzBK4BU; sso_uid_tt=b187180717cc4fb89208daffdf48b2b8; sso_uid_tt_ss=b187180717cc4fb89208daffdf48b2b8; toutiao_sso_user=749122bf4a0e95de675c94d8a1ddd45f; toutiao_sso_user_ss=749122bf4a0e95de675c94d8a1ddd45f; sid_ucp_sso_v1=1.0.0-KDExNzkwOGEyZGYwOWFkN2M5MmJkMThmNzQ2Y2MyZjA0NWU4M2IyMTMKHwjc3obb-AEQ2c6otAYY2hYgDDCN5ODMBTgGQPQHSAYaAmxxIiA3NDkxMjJiZjRhMGU5NWRlNjc1Yzk0ZDhhMWRkZDQ1Zg; ssid_ucp_sso_v1=1.0.0-KDExNzkwOGEyZGYwOWFkN2M5MmJkMThmNzQ2Y2MyZjA0NWU4M2IyMTMKHwjc3obb-AEQ2c6otAYY2hYgDDCN5ODMBTgGQPQHSAYaAmxxIiA3NDkxMjJiZjRhMGU5NWRlNjc1Yzk0ZDhhMWRkZDQ1Zg; odin_tt=e115c7383091cb326b80c8cc6625531be5ef3490b07200acead0713e679015241bdf5e02195b3de78da1135cab7f697d; passport_auth_status=abbfeb31a5cdb30b86920dffde0fb527%2C; passport_auth_status_ss=abbfeb31a5cdb30b86920dffde0fb527%2C; uid_tt=61670f6c03ab1c37f72242455184ec9f; uid_tt_ss=61670f6c03ab1c37f72242455184ec9f; sid_tt=6f1ada7a84152c5c7accd4888ca56d5d; sessionid=6f1ada7a84152c5c7accd4888ca56d5d; sessionid_ss=6f1ada7a84152c5c7accd4888ca56d5d; csrf_session_id=86eaa858f22fdfd8b0f966f17b2bcd2d; oc_login_type=LOGIN_PERSON; _bd_ticket_crypt_doamin=2; _bd_ticket_crypt_cookie=2b7e43399d9dcce3b3e2dcfe69314471; __security_server_data_status=1; sid_guard=6f1ada7a84152c5c7accd4888ca56d5d%7C1720330082%7C5183994%7CThu%2C+05-Sep-2024+05%3A27%3A56+GMT; sid_ucp_v1=1.0.0-KDI1Y2VmZDY5ZTUzM2EzOWRkNjIyMTFhOGZlOTJmOTNmYmM2OTZjNzcKGQjc3obb-AEQ4s6otAYY2hYgDDgGQPQHSAQaAmxmIiA2ZjFhZGE3YTg0MTUyYzVjN2FjY2Q0ODg4Y2E1NmQ1ZA; ssid_ucp_v1=1.0.0-KDI1Y2VmZDY5ZTUzM2EzOWRkNjIyMTFhOGZlOTJmOTNmYmM2OTZjNzcKGQjc3obb-AEQ4s6otAYY2hYgDDgGQPQHSAQaAmxmIiA2ZjFhZGE3YTg0MTUyYzVjN2FjY2Q0ODg4Y2E1NmQ1ZA; ttwid=1%7CsYWUUVLtNo1CuT0puCZfiZqLoVCH6s5XXpXOj2FPB2Q%7C1720330093%7C387b271e359c6673b65d41a95c2a858736d76de02ca1247dfb8b74daa36b41bd; bd_ticket_guard_client_data=eyJiZC10aWNrZXQtZ3VhcmQtdmVyc2lvbiI6MiwiYmQtdGlja2V0LWd1YXJkLWl0ZXJhdGlvbi12ZXJzaW9uIjoxLCJiZC10aWNrZXQtZ3VhcmQtcmVlLXB1YmxpYy1rZXkiOiJCQ1BQaEYyNlNKTEV0YkpreDlhZXpiOCtIdXR1aWRubVc3bHFRbVcxWWFaSVNsSFVNaEgyUndvelltK002bE1sMENmdkhzdHBWRnRkTkNvcm9taTdRbmc9IiwiYmQtdGlja2V0LWd1YXJkLXdlYi12ZXJzaW9uIjoxfQ%3D%3D; passport_fe_beating_status=true; msToken=jb4F9AqmkzortpZUDZRKcHrFSB4n3RSBW9nFomRZf_XMoNlDIMLvq6mnAgtTDPyi9g-ZUbDgB3SHvKKUzXdffHfCFFGq0xh5aOXUb0XTgHwCOan7Yy1rONzMwpU=; tt_scid=wSonqxoru7nasVCEy78litfqZJB8tREreZlkRtyn.z.vfwka923KNezPOzghQ3nY3e9f`
	hctx._cookies = hctx.ParseCookie(cookies)

	time.Sleep(time.Second * 5)
	filepath := []string{}

	// 下载视频

	

	tasks := chromedp.Tasks{
		chromedp.ActionFunc(func(ctx context.Context) error {
			if len(hctx._cookies) > 0 {
				page.AddScriptToEvaluateOnNewDocument(CleanWebDriver).Do(ctx)
				expr := cdp.TimeSinceEpoch(time.Now().Add(180 * 24 * time.Hour))
				for i := 0; i < len(hctx._cookies); i += 2 {
					err := network.SetCookie(hctx._cookies[i], hctx._cookies[i+1]).
						WithExpires(&expr).WithDomain(".douyin.com").
						WithSameSite(network.CookieSameSiteNone).WithSecure(true).Do(ctx)
					if err != nil {
						return err
					}
				}
			}
			return nil
		}),
		page.SetInterceptFileChooserDialog(true),
		page.SetAdBlockingEnabled(true),
		chromedp.Navigate(hctx.GetUrl()),
		chromedp.WaitReady(hctx.UploadInput(), chromedp.ByQuery),
		chromedp.SetUploadFiles(hctx.UploadInput(), filepath, chromedp.ByQuery),

		// 等待编辑内容组件
		chromedp.WaitVisible(".editor-comp-publish", chromedp.ByQuery),
		chromedp.Sleep(time.Second * 2),
		chromedp.SendKeys(".editor-comp-publish", "完美的瞬间", chromedp.ByQuery),

		// 标签列表list--AaGTY
		chromedp.WaitVisible(".list--AaGTY div:nth-child(1)", chromedp.ByQuery),
		chromedp.Click(".list--AaGTY div:nth-child(1)", chromedp.ByQuery),
		chromedp.Click(".list--AaGTY div:nth-child(3)", chromedp.ByQuery),
		chromedp.Click(".list--AaGTY div:nth-child(5)", chromedp.ByQuery),

		// 等待封面选择框出现
		chromedp.WaitVisible(".recommendDisplay--RleAd .recommendCover--JprtV img", chromedp.ByQuery),
		chromedp.Sleep(time.Second * 3),
		chromedp.Click(".recommendDisplay--RleAd .recommendCover--JprtV:nth-child(1) img", chromedp.ByQuery),
	}
	if err := chromedp.Run(ctx, tasks); err != nil {
		golog.Error(err)
		return
	}

	<-hctx.quit
}

func (hctx *Creator) event(ctx context.Context, landFace string) {
	for {
		select {
		case <-hctx.ticker.C:

		case <-ctx.Done():
			return
		}
	}
}

func (hctx *Creator) GetUrl() string {
	return "https://creator.douyin.com/creator-micro/content/upload"
}

func (hctx *Creator) UploadInput() string {
	return ".upload-btn-input--1NeEX"
}

// https://creator.douyin.com/creator-micro/content/publish-media/image-text?enter_from=publish_page&media_type=image&type=new图片下一步
