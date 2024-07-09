package mgr

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/chromedp/chromedp"
)

var pubOpts = chromedp.DefaultExecAllocatorOptions[:]

const CleanWebDriver = "Object.defineProperty(navigator, 'webdriver', { get: () => undefined });"

type StartReq struct {
	ClientId   string `form:"client_id" json:"client_id" url:"client_id" msgpack:"client_id"`
	QcId       string `form:"qc_id" json:"qc_id" url:"qc_id" msgpack:"qc_id"`
	ShopName   string `form:"shop_name" json:"shop_name" url:"shop_name" msgpack:"shop_name"` // 温致智能设备旗舰店
	Type       string `form:"type" json:"type" url:"type" msgpack:"type"`
	QrcodeTime int64  `form:"qrcode_time" json:"qrcode_time" url:"qrcode_time" msgpack:"qrcode_time"`
	Platform   string `form:"platform" json:"platform" url:"platform" msgpack:"platform"`
	Cookie     string `form:"cookie" json:"cookie" url:"cookie" msgpack:"cookie"`
}

func init() {
	pubOpts = append(pubOpts,
		chromedp.Flag("headless", false),
		chromedp.NoFirstRun,
		chromedp.NoDefaultBrowserCheck,
		chromedp.Flag("incognito", true),
		chromedp.Flag("disable-hang-monitor", true),
		chromedp.Flag("disable-ipc-flooding-protection", true),
		chromedp.Flag("disable-prompt-on-repost", true),
		chromedp.Flag("disable-renderer-backgrounding", true),
		chromedp.Flag("disable-sync", true),
		chromedp.Flag("disable-dev-shm-usage", true),
		chromedp.Flag("disable-web-security", false),
		chromedp.Flag("disable-extensions", true),
		chromedp.Flag("disable-blink-features", "AutomationControlled"),
		chromedp.Flag("enable-automation", false),
		chromedp.Flag("disable-infobars", true),
		chromedp.Flag("disable-notifications", true),
		chromedp.DisableGPU,
		// chromedp.NoSandbox,
		// chromedp.Flag("disable-setuid-sandbox", true),
		//chromedp.Flag("blink-settings", "imagesEnabled=false"),
	)
}

type CtxMgr struct {
	context.Context
	sync.Mutex
	ctxs    map[string]PlatformInf
	Errs    map[string]error
	Datas   map[string]any
	Cookies map[string]string
}

func NewCtxMgr(ctx context.Context) *CtxMgr {
	return &CtxMgr{
		Context: ctx,
		Errs:    map[string]error{},
		Datas:   map[string]any{},
		Cookies: map[string]string{},
		ctxs:    map[string]PlatformInf{},
	}
}

func (mgr *CtxMgr) Count() int {
	mgr.Lock()
	defer mgr.Unlock()

	return len(mgr.ctxs)
}

func (mgr *CtxMgr) Ids() []string {
	mgr.Lock()
	defer mgr.Unlock()
	var ids []string
	for s := range mgr.ctxs {
		ids = append(ids, s)
	}
	return ids
}

func (mgr *CtxMgr) Close(clientId string) {
	mgr.Lock()
	defer mgr.Unlock()
	if ctx, ok := mgr.ctxs[clientId]; ok {
		ctx.Done()
		ctx.Quit()
	}
}

func (mgr *CtxMgr) CloseAll() {
	for client_id := range mgr.ctxs {
		mgr.Close(client_id)
	}
}

func (mgr *CtxMgr) Exists(clientId string) bool {
	mgr.Lock()
	defer mgr.Unlock()

	if clientId == "" {
		return false
	}
	_, ok := mgr.ctxs[clientId]
	return ok
}

func (mgr *CtxMgr) GetHeadlessCtx(req StartReq) PlatformInf {
	mgr.Lock()
	defer mgr.Unlock()
	ctx, cancel := context.WithCancel(mgr.Context)

	if len(req.ClientId) == 0 {
		req.ClientId = fmt.Sprintf("%d", time.Now().UnixNano())
	}

	innerCtx := &HeadlessCtx{
		ctx:     ctx,
		cancel:  cancel,
		mgr:     mgr,
		Id:      req.ClientId,
		quit:    make(chan struct{}),
		expired: time.Now().Add(time.Minute * 5),
		ticker:  time.NewTicker(time.Second * 5),
	}

	var hctx PlatformInf
	if req.Platform == "creator" {
		hctx = &Creator{HeadlessCtx: innerCtx}
	} else {
		return nil
	}
	mgr.ctxs[req.ClientId] = hctx
	hctx.Run()

	return hctx
}

func (mgr *CtxMgr) GC() {
	ticker := time.NewTicker(time.Second * 5)
	for {
		select {
		case <-ticker.C:
			func() {
				mgr.Lock()
				defer mgr.Unlock()
				for _, hctx := range mgr.ctxs {
					if hctx.IsExpired() {
						hctx.Done()
					}
				}
			}()
		case <-mgr.Done():
			for _, hctx := range mgr.ctxs {
				hctx.Quit()
			}
			ticker.Stop()
			return
		}
	}

}

func (mgr *CtxMgr) Get(clientID string) (PlatformInf, error) {
	if mgr.Exists(clientID) {
		return mgr.ctxs[clientID], nil
	}

	return nil, errors.New("不存在该上下文,请重新打开弹窗")
}
