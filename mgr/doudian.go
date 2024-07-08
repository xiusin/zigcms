package mgr

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/chromedp/cdproto/page"
	"golang.org/x/exp/slog"

	"github.com/chromedp/cdproto/cdp"
	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/target"
	"github.com/chromedp/chromedp"
)

type Doudian struct {
	*HeadlessCtx

	Type     string
	QcId     string
	ShopName string

	QcCookie string
	LpCookie string

	AnchorIds   []BoundUser
	Aavid       string
	NoInsurance bool // 没有保险权限
	HasLp       bool
	HasQc       bool
	CheckedQcLp bool

	ShopInfo *ShopInfo

	NextCh    chan struct{}
	CheckUri  string
	targetID  network.RequestID
	uriMap    map[string]network.RequestID
	_cookies  []string
	QcEnd     bool
	fxgCookie string // 抖店主页cookie, 仅实物抖店获取信息
}

func (hctx *Doudian) Run() {
	defer close(hctx.NextCh)
	defer hctx.Done()

	begin := time.Now()
	defer func() {
		slog.Info("抖店扫码流程耗时", time.Since(begin).String())
	}()

	hctx.uriMap = map[string]network.RequestID{
		"/api/cgi/insurance-bms/fintech_ecom_bms/":    "",
		"/ad/ecom/marketing/api/v1/user/user_info_v2": "",
		"/common/index/index":                         "",
	}

	if hctx.IsDoudianType() {
		hctx.CheckUri = "/check_qrconnect/"
	} else {
		hctx.CheckUri = "/oauth/check_qrcode"
	}

	//_cookies := "passport_csrf_token=1501a279595ed96eef54cd8c8aed851e; passport_csrf_token_default=1501a279595ed96eef54cd8c8aed851e; uidpasaddaehruigqreajf=0; Hm_lvt_b6520b076191ab4b36812da4c90f7a5e=1679463151,1680142620,1681181365; fxg_guest_session=eyJhbGciOiJIUzI1NiIsInR5cCI6InR5cCJ9.eyJndWVzdF9pZCI6IkNnc0lBUkR6SEJnQklBRW9BUkkrQ2p4aFNKK1IyMjRTTkhRNlJJTncvbE44WWxZUnFjREFvQUFBbXlFWjhQRk1yM1ZvK3ZiZUxtVzhuVnc0ZGNsNGF1R3c3SGU5bFpaV1BOTmtOdjBhQUE9PSIsImlhdCI6MTY4MTE4MTY5NSwibmJmIjoxNjgxMTgxNjk1LCJleHAiOjE2ODI0Nzc2OTV9.2afe4234d5f19e1a44ed90d257b79f9766ebfdb3de1064b9ce1ef77e17c07bfc; MONITOR_WEB_ID=7408dd7a-2602-44a4-8406-cd91f0d5e3dc; Hm_lpvt_b6520b076191ab4b36812da4c90f7a5e=1681181722; ttwid=1|T0SEZCTl0VnAQlOQLZkcQmSH8DeG2QvmUqU0P6YBCvk|1681181722|55efbde462a80f54955a33de33dd44d2a9c07d076b2ce7c87b3527d91dd8231b; n_mh=XsqhirTJi-lPpkBRjec_WuRXFV8_HJvODi466WfUqGg; sso_uid_tt=d1038eeac6d9697969971c07d21df546; sso_uid_tt_ss=d1038eeac6d9697969971c07d21df546; toutiao_sso_user=d116652703e1864b28b88a9afbe0feef; toutiao_sso_user_ss=d116652703e1864b28b88a9afbe0feef; sid_ucp_sso_v1=1.0.0-KDFiYWY5ODU3NTNkNjdlMzIyNjk1ZTVlNjVjZjhiMDgyMzQxMmI0YjIKHwiLwtCUtI3dBxCimNOhBhiwISAMMI_V0JUGOAZA9AcaAmxmIiBkMTE2NjUyNzAzZTE4NjRiMjhiODhhOWFmYmUwZmVlZg; ssid_ucp_sso_v1=1.0.0-KDFiYWY5ODU3NTNkNjdlMzIyNjk1ZTVlNjVjZjhiMDgyMzQxMmI0YjIKHwiLwtCUtI3dBxCimNOhBhiwISAMMI_V0JUGOAZA9AcaAmxmIiBkMTE2NjUyNzAzZTE4NjRiMjhiODhhOWFmYmUwZmVlZg; odin_tt=84c72c671b8fe61f61c29f0e6fee99acdfee4f889312a38245bda41bd98653e65e1219746ccb5029b4b8c0afbb9dc6dd33af713a5ea19f135adc478de67b45b0; passport_auth_status=369b0d96dcd005acfb9f32bef505a4e8,; passport_auth_status_ss=369b0d96dcd005acfb9f32bef505a4e8,; uid_tt=30e149c97b946e862d4293c6a37440f2; uid_tt_ss=30e149c97b946e862d4293c6a37440f2; sid_tt=bec22f08c386728e457cc466116eaf35; sessionid=bec22f08c386728e457cc466116eaf35; sessionid_ss=bec22f08c386728e457cc466116eaf35; csrf_session_id=e0a8549189239223a7adbe49abc9a677; ucas_sso_c0=CkEKBTEuMC4wELeIjNilg7OaZBjmJiCfr-CmwIziAyiwITCLwtCUtI3dB0CkmNOhBkikzI-kBlCfvKbi9vPKv2NYbxIUCrL4_p9gxXXAMgolrDl72nSjciY; ucas_sso_c0_ss=CkEKBTEuMC4wELeIjNilg7OaZBjmJiCfr-CmwIziAyiwITCLwtCUtI3dB0CkmNOhBkikzI-kBlCfvKbi9vPKv2NYbxIUCrL4_p9gxXXAMgolrDl72nSjciY; ucas_c0=CkEKBTEuMC4wEKKIg-LngrOaZBjmJiCfr-CmwIziAyiwITCLwtCUtI3dB0CkmNOhBkikzI-kBlCfvKbi9vPKv2NYbxIUak8QVHLz_8vUgkrHbWZRBYL6Lbk; ucas_c0_ss=CkEKBTEuMC4wEKKIg-LngrOaZBjmJiCfr-CmwIziAyiwITCLwtCUtI3dB0CkmNOhBkikzI-kBlCfvKbi9vPKv2NYbxIUak8QVHLz_8vUgkrHbWZRBYL6Lbk; sid_guard=bec22f08c386728e457cc466116eaf35|1681181732|5184000|Sat,+10-Jun-2023+02:55:32+GMT; sid_ucp_v1=1.0.0-KDJhNWEzYjE5OGVjMjdiM2M5MmU5OTE4ZTBhN2M0OTc1ZjU4NGJkOTYKGQiLwtCUtI3dBxCkmNOhBhiwISAMOAZA9AcaAmxxIiBiZWMyMmYwOGMzODY3MjhlNDU3Y2M0NjYxMTZlYWYzNQ; ssid_ucp_v1=1.0.0-KDJhNWEzYjE5OGVjMjdiM2M5MmU5OTE4ZTBhN2M0OTc1ZjU4NGJkOTYKGQiLwtCUtI3dBxCkmNOhBhiwISAMOAZA9AcaAmxxIiBiZWMyMmYwOGMzODY3MjhlNDU3Y2M0NjYxMTZlYWYzNQ; store-region=cn-ha; store-region-src=uid; PHPSESSID=ec1743e4f75318021bea6954be749837; PHPSESSID_SS=ec1743e4f75318021bea6954be749837; need_choose_shop=0; x-jupiter-uuid=16811817330506568; login_info={\"for_im_reply\":\"ec1743e4f75318021bea6954be749837\"}; s_v_web_id=verify_lgbo770x_vana9nyN_4KFO_4bYX_9SrG_KTgitUf9rJyr; gf_part_357937=0; gf_part_333135=1; msToken=iWOISe2gBxMjorD-QODYzB4V0sFHsgUiyMWIwEnY2rfKtswlBS1fL9UFANe5AWU42bUl-8lWGTmArbZv4LBHxK6Hqp9tbyZ1upIF97aFYvkHLgGXDTbzmQ==; tt_scid=I5PQ6VoqIC9pUHbY-muRKt1RYsWESnR0Mfg42gYFhtLPBSi-r6KcGW7pjupmwA4Occ67; msToken=1hdv4X8sh2zMNPor3L5kmT0WKmbe2W00w44vB-hyNht4x6fKJN7E8eNekV4kW0TC0AJ1emHEFg21jsyfJvwoDdQVpeBx_WTp4UKJI97m1kqerDDyZ3YJvw=="
	//hctx._cookies = hctx.ParseCookie(_cookies)

	actX, aCancel := chromedp.NewExecAllocator(hctx.ctx, hctx.Opts()...)
	ctx, cancel := chromedp.NewContext(actX)
	defer aCancel()
	defer cancel()

	tasks := chromedp.Tasks{
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, err := page.AddScriptToEvaluateOnNewDocument(CleanWebDriver).Do(ctx)
			if err == nil && len(hctx._cookies) > 0 {
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
			return err
		}),

		chromedp.EmulateViewport(1280, 800),
		chromedp.Navigate(hctx.GetUrl()), // 连续两次跳转
		chromedp.Sleep(time.Second * 4),
		chromedp.Navigate(hctx.GetUrl()),
		chromedp.Evaluate(`try { document.querySelector("#DOUXIAOER_WRAPPER").remove(); } catch(e) {}`, nil),
	}

	if !hctx.IsDoudianType() {
		// 根据类型确定是否要
		tasks = append(tasks,
			chromedp.Click(".login_types .type:nth-child(1)", chromedp.ByQuery),
		)
	} else {
		tasks = append(tasks,
			chromedp.Click(".login-switcher--cell", chromedp.ByQuery),
		)
	}

	if len(hctx._cookies) == 0 {
		tasks = append(tasks, chromedp.WaitReady(hctx.WaitSel(), chromedp.ByQuery))
	}

	if err := chromedp.Run(ctx, tasks); err != nil {
		slog.Error(err.Error())
		return
	}
	hctx.ScanEvent(ctx)

	chromedp.ListenTarget(ctx, func(ev interface{}) {
		switch ev := ev.(type) {
		case *network.EventRequestWillBeSent:
			for s := range hctx.uriMap {
				if strings.Contains(ev.Request.URL, s) {
					hctx.uriMap[s] = ev.RequestID
				}
			}
		case *network.EventLoadingFinished:
			api := "/api/cgi/insurance-bms/fintech_ecom_bms/"
			if ev.RequestID == hctx.uriMap[api] {
				go func() {
					c := chromedp.FromContext(ctx)
					body, _ := network.GetResponseBody(ev.RequestID).Do(cdp.WithExecutor(ctx, c.Target))
					var resp CheckInsuranceResp
					_ = json.Unmarshal(body, &resp)
					if resp.Data.Login.BaseResp.StatusMessage == "商家不存在" {
						hctx.NoInsurance = true // 不是保险后台商家
					}
				}()
				hctx.uriMap[api] = ""
			}
		case *network.EventRequestWillBeSentExtraInfo:
			for s, id := range hctx.uriMap {
				if ev.RequestID == id {
					if cookie := ev.Headers["cookie"]; cookie != nil {
						switch s {
						case "/api/cgi/insurance-bms/fintech_ecom_bms/":
							if !hctx.canGetCookie {
								return
							}
							if len(hctx.cookies) > 0 || !strings.Contains(cookie.(string), "SessionId") || !strings.Contains(cookie.(string), "PHPSESSID") {
								return
							}
							hctx.cookies = cookie.(string)
						case "/common/index/index":
							if len(hctx.fxgCookie) == 0 {
								hctx.fxgCookie = cookie.(string)
							}
						}
					}
				}
			}
		}
	})
	go hctx.event(ctx, "")
	<-hctx.quit
	hctx.mgr.Lock()

	if hctx.ShopInfo != nil {
		if hctx.NoInsurance {
			hctx.ShopInfo.ShopDesc = "business"
		} else {
			hctx.ShopInfo.ShopDesc = "insurance"
		}
	}

	if hctx.cookies == "" && hctx.NoInsurance {
		hctx.cookies = hctx.fxgCookie
	}

	if hctx.cookies == "" {
		hctx.cookies = "no_auth"
	}

	hctx.mgr.Datas[hctx.Id] = map[string]any{
		"qc_cookie":  hctx.QcCookie,
		"lp_cookie":  hctx.LpCookie,
		"shopinfo":   hctx.ShopInfo,
		"aavid":      hctx.Aavid,
		"anchor_ids": hctx.AnchorIds,
	}
	hctx.mgr.Cookies[hctx.Id] = hctx.cookies
	hctx.mgr.Unlock()
}

func (hctx *Doudian) GetUrl() string {
	return "https://insurance.jinritemai.com/"
}

func (hctx *Doudian) IsDoudianType() bool {
	return hctx.Type == "doudian"
}

func (hctx *Doudian) WaitSel() string {
	if hctx.IsDoudianType() {
		return ".account-center-qrcode-image-container"
	} else {
		return ".qr"
	}
}

func (hctx *Doudian) event(ctx context.Context, _ string) {
	var qrcode string
	var content string

	var cb = func(url string) {
		if strings.Contains(url, "open.douyin.com") && hctx.GetNodeCnt(ctx, hctx.WaitSel()) > 0 {
			var attrs map[string]string
			chromedp.Run(ctx, chromedp.Attributes(hctx.WaitSel(), &attrs, chromedp.ByQuery))
			if attrs["src"] != qrcode {
				qrcode = attrs["src"]
				hctx.SaveClick(ctx, &qrcode, ".qr-expired")
			}
		}
	}

	if hctx.IsDoudianType() {
		cb = func(url string) {
			if strings.Contains(url, "login") && hctx.GetNodeCnt(ctx, hctx.WaitSel()) > 0 {
				tCtx, cancel := context.WithTimeout(ctx, time.Millisecond*100)
				defer cancel()
				_ = chromedp.Run(tCtx, chromedp.InnerHTML(hctx.WaitSel(), &content, chromedp.ByQuery))
				if content == "" {
					return
				}
				if matchAll := regexp.MustCompile(`background-image: url\((.+?)\)`).FindAllString(content, -1); matchAll != nil {
					prefix, suffix := `background-image: url(&quot;`, `&quot;)`
					tmp := matchAll[0][len(prefix) : len(matchAll[0])-len(suffix)]
					if tmp != qrcode {
						qrcode = tmp
						hctx.SaveClick(ctx, &qrcode, ".account-center-code-expired-refresh")
					}
				}
			}
		}
	}
	hctx.handleEvent(ctx, cb)
}

func (hctx *Doudian) handleEvent(ctx context.Context, cb func(string)) {
	var times = 0
	for {
		select {
		case <-hctx.ticker.C:
			times++
			if times%5 == 0 {
				hctx.GetSnapshot(ctx, "抖店")
			}
			var currentUrl string
			_ = chromedp.Run(ctx, chromedp.Location(&currentUrl), chromedp.Evaluate("localStorage.setItem('$_GUIDE_PREFIX_homepage-guide', '1');", nil)) // 关闭引导手册
			slog.Info(currentUrl)
			if strings.Contains(currentUrl, "https://insurance.jinritemai.com/home") {
				hctx.scanned = true
				hctx.clickToBaoHuaXia(ctx)
			} else if strings.Contains(currentUrl, "baohuaxia") {
				if len(hctx.cookies) > 0 && hctx.ShopInfo == nil {
					_ = chromedp.Run(ctx, chromedp.Navigate("https://fxg.jinritemai.com/ffa/mshop/homepage/index"))
				}
				hctx.canGetCookie = true
				hctx.scanned = true
				if hctx.excitable() {
					hctx.Quit()
					return
				}
			} else if strings.Contains(currentUrl, "https://fxg.jinritemai.com") && !strings.Contains(currentUrl, "login") {
				hctx.handleFxg(ctx, currentUrl)
				hctx.scanned = true
				if hctx.excitable() {
					hctx.Quit()
					return
				}
			} else {
				cb(currentUrl)
			}
		case <-ctx.Done():
			return
		}
	}
}

func (hctx *Doudian) excitable() bool {
	if (hctx.NoInsurance || len(hctx.cookies) > 0) && hctx.ShopInfo != nil {
		if hctx.HasQc {
			return hctx.QcEnd // len(hctx.AnchorIds) > 0 && hctx.QcCookie != ""
		}
		return true
	}
	return false
}

func (hctx *Doudian) clickToBaoHuaXia(ctx context.Context) {
	if hctx.GetNodeCnt(ctx, ".pd-Group-Group-StyledGroup") > 0 {
		chromedp.Run(ctx, chromedp.Click(".pd-Group-Group-StyledGroup button:nth-child(4)", chromedp.ByQuery))
	}
}

// 处理抖店主页内容
func (hctx *Doudian) handleFxg(ctx context.Context, url string) {
	if strings.Contains(url, "/ffa/w/subaccount/apply") {
		_ = chromedp.Run(ctx, chromedp.Navigate("https://fxg.jinritemai.com/ffa/mshop/homepage/index"))
	}
	if (strings.Contains(url, "/ffa/mshop/homepage/index") || strings.Contains(url, "/ffa/morder/order/list") || strings.Contains(url, "/ffa/growth/newbie")) && hctx.ShopInfo == nil {
		hctx.scanned = true
		if !hctx.CheckedQcLp {
			var titleSel = "#fxg-pc-header"
			var content = ""
			chromedp.Run(ctx, chromedp.WaitReady(titleSel, chromedp.ByQuery), chromedp.Evaluate(`document.querySelector("`+titleSel+`").innerText`, &content))
			hctx.HasLp = strings.Contains(content, "电商罗盘") || strings.Contains(content, "电商数据")
			hctx.HasQc = strings.Contains(content, "巨量千川")
			hctx.CheckedQcLp = true
		}
		var keys []string
		var skeys []string
		_ = chromedp.Run(ctx, chromedp.Evaluate("Object.keys(localStorage)", &keys))
		_ = chromedp.Run(ctx, chromedp.Evaluate("Object.keys(sessionStorage)", &skeys))
		keys = append(keys, skeys...)
		for _, key := range keys {
			if (strings.HasPrefix(key, "API_CACHE_GET_") && strings.HasSuffix(key, ":/common/index/index")) || (strings.Contains(key, "initialUserInfo")) {
				var data string
				if strings.Contains(key, "initialUserInfo") {
					_ = chromedp.Run(ctx, chromedp.Evaluate("sessionStorage.getItem('"+key+"');", &data))
				} else {
					_ = chromedp.Run(ctx, chromedp.Evaluate("localStorage.getItem('"+key+"');", &data))
				}
				var resp ShopInfoResp
				_ = json.Unmarshal([]byte(data), &resp)
				hctx.ShopInfo = &resp.Data
			}
		}
		hctx.LP(ctx)
		hctx.QC(ctx)
		if hctx.ShopInfo != nil && len(hctx.cookies) == 0 {
			_ = chromedp.Run(ctx, chromedp.Navigate("https://insurance.jinritemai.com/home"))
		}
	} else if strings.Contains(url, "/ffa/gov/settle/choose-role") { // 选择入驻主体
		hctx.mgr.Lock()
		hctx.mgr.Errs[hctx.Id] = ErrScanNoRole
		hctx.mgr.Unlock()
		hctx.Quit()
		return
	}
}

// QC 处理千川逻辑
func (hctx *Doudian) QC(ctx context.Context) {
	if !hctx.HasQc || len(hctx.QcCookie) > 0 {
		return
	}
	defer func() {
		slog.Debug("千川信息获取完成", hctx.QcCookie)
	}()
	defer func() {
		hctx.QcEnd = true
	}()

	sel := hctx.GetBtnSel(ctx, "巨量千川", ".index_wrapper__2PBS2 > div")
	chromedp.Run(ctx, chromedp.Sleep(time.Second), chromedp.Click(sel, chromedp.ByQuery))
	hctx.Lock()
	info := hctx.GetTarget(ctx, "https://qianchuan.jinritemai.com/")
	if info == nil {
		hctx.Unlock()
		slog.Debug("没有获取到千川页签")
		return
	}

	pCtx, pCancel := context.WithTimeout(ctx, time.Second*60)
	qc, cancel := chromedp.NewContext(pCtx, chromedp.WithTargetID(info.TargetID))
	defer pCancel()
	defer cancel()
	hctx.Unlock()

	_ = chromedp.Run(qc, chromedp.Evaluate(`localStorage.setItem('__Garfish__promotion__quota-modal-v2', '{"closeTimes":1,"lastOpen":`+fmt.Sprintf("%d", time.Now().UnixMilli())+`}');`, nil))
	go func() {
		_ = chromedp.Run(qc, chromedp.Click(".bui-modal-dialog .close-btn", chromedp.ByQuery))
	}()

	go func() {
		var ticker = time.NewTicker(time.Second * 3)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				hctx.GetSnapshot(qc, "千川")
			case <-qc.Done():
				return
			}
		}
	}()

	if hctx.Aavid = hctx.getUrlParam(qc, "aavid"); len(hctx.Aavid) == 0 {
		slog.Debug("无法获取aavid")
		return
	}
	slog.Debug("获取aavid:", hctx.Aavid)
	dataReportUrl := "https://qianchuan.jinritemai.com/data-report/evaluation/today-live?aavid=" + hctx.Aavid
	chromedp.Run(qc, chromedp.Navigate(dataReportUrl), chromedp.WaitReady(".aweme-select-container"))
	hctx.GetAnchorIds(qc)
	go func() {
		times := 0
		ticker := time.NewTicker(time.Millisecond * 100)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if len(hctx.AnchorIds) > 0 && hctx.QcCookie != "" {
					slog.Debug("千川信息已完整,退出")
					cancel()
					return
				} else if times%30 == 0 {
					slog.Debug("等待千川信息完成", len(hctx.AnchorIds) > 0, hctx.QcCookie != "")
				}
				times++
			case <-qc.Done():
				return
			}
		}
	}()
	select {
	case <-ctx.Done():
		return
	case <-pCtx.Done():
		return
	case <-qc.Done():
		return
	}
}

func (hctx *Doudian) LP(ctx context.Context) {
	if !hctx.HasLp || len(hctx.LpCookie) > 0 {
		return
	}
	slog.Debug("进入获取罗盘cookie逻辑")
	defer func() {
		slog.Debug("获取罗盘cookie结束", hctx.LpCookie)
	}()

	sel := hctx.GetBtnSel(ctx, "电商罗盘", ".index_wrapper__2PBS2 > div")
	if sel == "" {
		sel = hctx.GetBtnSel(ctx, "电商数据", ".index_wrapper__2PBS2 > div")
	}
	chromedp.Run(ctx, chromedp.Click(sel, chromedp.ByQuery))
	hctx.Lock()
	info := hctx.GetTarget(ctx, "https://compass.jinritemai.com/shop") // 获取指定页签
	if info == nil {
		hctx.Unlock()
		return
	}
	pCtx, pCancel := context.WithTimeout(ctx, time.Second*20)
	lp, cancel := chromedp.NewContext(pCtx, chromedp.WithTargetID(info.TargetID))
	defer pCancel()
	defer cancel()
	hctx.Unlock()

	api := "/compass_api/shop/mall/homepage/realtime_core_data"
	chromedp.ListenTarget(lp, func(ev interface{}) {
		switch ev := ev.(type) {
		case *network.EventRequestWillBeSent:
			if strings.Contains(ev.Request.URL, api) {
				hctx.uriMap[api] = ev.RequestID
			}
		case *network.EventRequestWillBeSentExtraInfo:
			for s, id := range hctx.uriMap {
				if ev.RequestID == id && s == api {
					if cookie := ev.Headers["cookie"]; cookie != nil {
						hctx.LpCookie = cookie.(string)
						cancel()
					}
				}
			}
		}
	})

	go func() {
		for {
			if len(hctx.LpCookie) > 0 {
				return
			}
			chromedp.Run(lp, chromedp.Click(".leftIcon--bxeQ9", chromedp.ByQuery), chromedp.Sleep(time.Second)) // 持续点击刷新按钮
		}
	}()

	select {
	case <-ctx.Done():
		return
	case <-pCtx.Done():
		return
	case <-lp.Done():
		return
	}

}

// ScanEvent 监听扫码状态
func (hctx *Doudian) ScanEvent(ctx context.Context) {
	slog.Debug("注册扫码事件监听")
	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if len(hctx.CheckUri) == 0 {
			return
		}
		switch ev := ev.(type) {
		case *network.EventRequestWillBeSent:
			if strings.Contains(ev.Request.URL, hctx.CheckUri) && hctx.targetID == "" {
				hctx.targetID = ev.RequestID
			}
		case *network.EventLoadingFinished:
			if ev.RequestID == hctx.targetID {
				go func() {
					c := chromedp.FromContext(ctx)
					body, _ := network.GetResponseBody(ev.RequestID).Do(cdp.WithExecutor(ctx, c.Target))
					if hctx.Type == "douyin" {
						var resp QrcodeResp
						_ = json.Unmarshal(body, &resp)
						hctx.scanned = resp.Data.Status == "scanned"
					} else {
						var resp QrConnectResp
						_ = json.Unmarshal(body, &resp)
						switch resp.Data.Status {
						case "2":
							hctx.scanned = true
						default:
							hctx.scanned = false
						}
					}
					hctx.targetID = ""
				}()
			}
		}
	})
}

// GetAnchorIds 监听扫码状态
func (hctx *Doudian) GetAnchorIds(ctx context.Context) {
	api := "/ad/ecom/marketing/api/v1/todayLive/getListBoundUserIDs"
	var targetID network.RequestID

	go func() {
		chromedp.Run(ctx, chromedp.Click(".open-tooltip .footer a:nth-child(1)", chromedp.ByQuery))
	}()

	go func() {
		var ticker = time.NewTicker(time.Second * 2)
		defer ticker.Stop()
		fn := func() {
			slog.Debug("千川信息anchor_ids: ", len(hctx.AnchorIds), " cookie: ", len(hctx.QcCookie), " nodes:", hctx.GetNodeCnt(ctx, ".select-custom"))
			chromedp.Run(ctx, chromedp.WaitReady(".select-custom", chromedp.ByQuery), chromedp.Click(".select-custom", chromedp.ByQuery))
			slog.Debug("点击下拉框")
		}

		fn()
		for {
			select {
			case <-ticker.C:
				fn()
			case <-ctx.Done():
				return
			}
		}
	}()

	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if len(hctx.AnchorIds) > 0 {
			return
		}
		switch ev := ev.(type) {
		case *network.EventRequestWillBeSent:
			if strings.Contains(ev.Request.URL, api) && strings.Contains(ev.Request.URL, "page_size=10") {
				targetID = ev.RequestID
			}
		case *network.EventRequestWillBeSentExtraInfo:
			if ev.Headers[":path"] == nil {
				return
			}
			if strings.Contains(ev.Headers[":path"].(string), api) && len(hctx.QcCookie) == 0 {
				if cookie := ev.Headers["cookie"]; cookie != nil {
					slog.Debug("获取到千川cookie")
					hctx.QcCookie = cookie.(string)
				}
			}
		case *network.EventLoadingFinished:
			if ev.RequestID == targetID {
				go func() {
					slog.Debug("执行获取")
					c := chromedp.FromContext(ctx)
					body, _ := network.GetResponseBody(ev.RequestID).Do(cdp.WithExecutor(ctx, c.Target))
					var resp listBoundUserIDsResp
					slog.Debug("解析json", json.Unmarshal(body, &resp))

					for _, info := range resp.Data.BindUserInfos {
						avatar := ""
						if len(info.UserInfo.SmallAvatar.UrlList) > 0 {
							avatar = info.UserInfo.SmallAvatar.UrlList[0]
						}
						hctx.AnchorIds = append(hctx.AnchorIds, BoundUser{
							AwemeId:   info.UserInfo.UniqueId,
							Name:      info.UserInfo.Name,
							Avatar:    avatar,
							AccountId: info.UserInfo.Id,
						})
					}
				}()
			}
		}
	})
	slog.Debug("注册获取anchor_ids")
}

// GetTarget 获取指定路由的tab页签
func (hctx *Doudian) GetTarget(ctx context.Context, url string) *target.Info {
	ticker := time.NewTicker(time.Millisecond * 250)
	sCtx, cancel := context.WithTimeout(ctx, time.Second*10)
	defer ticker.Stop()
	defer cancel()
	for {
		select {
		case <-ticker.C:
			infos, _ := chromedp.Targets(ctx)
			for _, _info := range infos {
				if strings.Contains(_info.URL, url) {
					return _info
				}
			}
		case <-sCtx.Done():
			return nil
		}
	}
}
