package main

import (
	"context"
	"math/rand"
	"time"

	"github.com/xiusin/webdriver/mgr"
)

type Resp struct {
	Code        int    `json:"code"`
	Msg         string `json:"msg"`
	HideMessage bool   `json:"hide_message"`
	Err         string `json:"err"`
	Data        any    `json:"data"`
}

func init() {
	time.Local = time.FixedZone("CST", 8*3600)
	rand.New(rand.NewSource(time.Now().UnixNano()))
}

func main() {
	ch := make(chan struct{})

	ctxMgr := mgr.NewCtxMgr(context.Background())
	defer ctxMgr.CloseAll()
	go ctxMgr.GC()
	ctxMgr.GetHeadlessCtx(mgr.StartReq{Platform: "creator"})
	<-ch
}
