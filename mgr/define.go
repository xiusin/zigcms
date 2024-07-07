package mgr

import "context"

type PlatformInf interface {
	Run()
	event(context.Context, string)
	GetUrl() string
	Done()
	Quit()
	IsExpired() bool
	WaitSel() string
	GetId() string
	IsScanned() bool
	GetQrcode(int64) map[string]any
}

type QrcodeResp struct {
	Data    QrcodeEvent `json:"data"`
	Message string      `json:"message"`
}

type QrcodeEvent struct {
	Captcha     string `json:"captcha"`
	DescUrl     string `json:"desc_url"`
	Description string `json:"description"`
	ErrorCode   int    `json:"error_code"`
	Status      string `json:"status"`
}

type EosUserInfoResp struct {
	AccountId      string `json:"account_id"`
	AvatarUrl      string `json:"avatar_url"`
	Username       string `json:"username"`
	SecUid         string `json:"sec_uid"`
	DouyinUniqueId string `json:"douyin_unique_id"`
	MerchantType   int    `json:"merchant_type"`
	StatusCode     int    `json:"status_code"`
	StatusMsg      string `json:"status_msg"`
	Platform       string `json:"platform"`
}

type QrConnectResp struct {
	Data struct {
		Status string `json:"status"`
	} `json:"data"`
	Description string `json:"description"`
	ErrorCode   int    `json:"error_code"`
	Message     string `json:"message"`
}

type ShopInfo struct {
	Id                             string      `json:"id,omitempty"`
	ShopName                       string      `json:"shop_name,omitempty"`
	UserName                       string      `json:"user_name,omitempty"`
	Mobile                         string      `json:"mobile,omitempty"`
	Status                         int         `json:"status,omitempty"`
	CreateTime                     int         `json:"create_time,omitempty"`
	UpdateTime                     string      `json:"update_time,omitempty"`
	Agent                          string      `json:"agent,omitempty"`
	UserType                       int         `json:"user_type,omitempty"`
	Address                        string      `json:"address,omitempty"`
	ToutiaoId                      string      `json:"toutiao_id,omitempty"`
	CollectTel                     string      `json:"collect_tel,omitempty"`
	CollectTelSure                 string      `json:"collect_tel_sure,omitempty"`
	OperateStatus                  int         `json:"operate_status,omitempty"`
	StopReason                     string      `json:"stop_reason,omitempty"`
	Wechat                         string      `json:"wechat,omitempty"`
	ModifyStatus                   int         `json:"modify_status,omitempty"`
	ShopChargeName                 string      `json:"shop_charge_name,omitempty"`
	MobileCharge                   string      `json:"mobile_charge,omitempty"`
	MobileChargeSec                string      `json:"mobile_charge_sec,omitempty"`
	IsProxy                        int         `json:"is_proxy,omitempty"`
	ProxyId                        int         `json:"proxy_id,omitempty"`
	PayType                        int         `json:"pay_type,omitempty"`
	AdBizStatus                    int         `json:"ad_biz_status,omitempty"`
	MediaBizStatus                 int         `json:"media_biz_status,omitempty"`
	ShopBizStatus                  int         `json:"shop_biz_status,omitempty"`
	BizType                        int         `json:"biz_type,omitempty"`
	ShopLogo                       string      `json:"shop_logo,omitempty"`
	Qq                             string      `json:"qq,omitempty"`
	Email                          string      `json:"email,omitempty"`
	ToutiaohaoId                   string      `json:"toutiaohao_id,omitempty"`
	IsPledgeCash                   int         `json:"is_pledge_cash,omitempty"`
	PledgeCash                     int         `json:"pledge_cash,omitempty"`
	NeedPledgeCash                 int         `json:"need_pledge_cash,omitempty"`
	ShowResetStatus                int         `json:"show_reset_status,omitempty"`
	TotalReduce                    int         `json:"total_reduce,omitempty"`
	RosterName                     string      `json:"roster_name,omitempty"`
	PledgeCashRefundStatus         int         `json:"pledge_cash_refund_status,omitempty"`
	PledgeCashRefundCheckMsg       string      `json:"pledge_cash_refund_check_msg,omitempty"`
	RefundAccountInfo              string      `json:"refund_account_info,omitempty"`
	CompanyPartner                 int         `json:"company_partner,omitempty"`
	EmailCharge                    string      `json:"email_charge,omitempty"`
	ContractStatus                 int         `json:"contract_status,omitempty"`
	ContractArchiveDate            string      `json:"contract_archive_date,omitempty"`
	RegisterAgreement              int         `json:"register_agreement,omitempty"`
	VType                          int         `json:"v_type,omitempty"`
	CertifyStatus                  int         `json:"certify_status,omitempty"`
	CertifyStatusNote              string      `json:"certify_status_note,omitempty"`
	CosRatio                       int         `json:"cos_ratio,omitempty"`
	LoginResource                  string      `json:"login_resource,omitempty"`
	ProbationEndTime               int         `json:"probation_end_time,omitempty"`
	ShopType                       int         `json:"shop_type,omitempty"`
	DownloadCheckPhone             string      `json:"download_check_phone,omitempty"`
	LegalCellphone                 string      `json:"legal_cellphone,omitempty"`
	Token                          string      `json:"token,omitempty"`
	NeedSignContract               int         `json:"need_sign_contract,omitempty"`
	ToutiaoType                    string      `json:"toutiao_type,omitempty"`
	OceanLogin                     string      `json:"ocean_login,omitempty"`
	SutuiWhite                     int         `json:"sutui_white,omitempty"`
	ContractRegStatus              int         `json:"contract_reg_status,omitempty"`
	ContractUpgradeVTypeStatus     int         `json:"contract_upgrade_v_type_status,omitempty"`
	AgreeStatus                    int         `json:"agree_status,omitempty"`
	MarketContractStatus           int         `json:"market_contract_status,omitempty"`
	ContractUrl                    string      `json:"contract_url,omitempty"`
	CrossBorderContractUrl         string      `json:"cross_border_contract_url,omitempty"`
	MarketContractUrl              string      `json:"market_contract_url,omitempty"`
	PayMethods                     int         `json:"pay_methods,omitempty"`
	OnlinePayMethods               int         `json:"online_pay_methods,omitempty"`
	IsAllianceWhiteList            int         `json:"is_alliance_white_list,omitempty"`
	IsCs                           int         `json:"is_cs,omitempty"`
	CertifyCreditCardTime          string      `json:"certify_credit_card_time,omitempty"`
	BizValidDateExpire             int         `json:"biz_valid_date_expire,omitempty"`
	QuitStatus                     int         `json:"quit_status,omitempty"`
	OriginQuitStatus               int         `json:"origin_quit_status,omitempty"`
	IsSupportShop                  int         `json:"is_support_shop,omitempty"`
	SupportBizType                 int         `json:"support_biz_type,omitempty"`
	BusTypeToutiaohao              int         `json:"bus_type_toutiaohao,omitempty"`
	IsOpenAd                       int         `json:"is_open_ad,omitempty"`
	CloseSite                      int         `json:"close_site,omitempty"`
	CloseSiteNote                  string      `json:"close_site_note,omitempty"`
	StoreType                      int         `json:"store_type,omitempty"`
	StoreMode                      int         `json:"store_mode,omitempty"`
	AuthStatus                     int         `json:"auth_status,omitempty"`
	StoreStatus                    int         `json:"store_status,omitempty"`
	MainShopName                   string      `json:"main_shop_name,omitempty"`
	SubToutiaoId                   string      `json:"sub_toutiao_id,omitempty"`
	SubUserName                    string      `json:"sub_user_name,omitempty"`
	SubUserEmail                   string      `json:"sub_user_email,omitempty"`
	SubUserBindType                int         `json:"sub_user_bind_type,omitempty"`
	Intelligent                    int         `json:"intelligent,omitempty"`
	AccountType                    int         `json:"account_type,omitempty"`
	IsSubmitForbidden              bool        `json:"is_submit_forbidden,omitempty"`
	ForbidSubmitTips               interface{} `json:"forbid_submit_tips,omitempty"`
	ShopInfoStatus                 int         `json:"shop_info_status,omitempty"`
	EnterpriseStatus               int         `json:"enterprise_status,omitempty"`
	PledgeCashOperationRecordCount int         `json:"pledge_cash_operation_record_count,omitempty"`
	IsShowReceive                  bool        `json:"is_show_receive,omitempty"`
	ShopTag                        []string    `json:"shop_tag,omitempty"`
	LimitOrderReviewTime           int         `json:"limit_order_review_time,omitempty"`
	IsCrossBorder                  bool        `json:"is_cross_border,omitempty"`
	ImUnReplyNum                   int         `json:"im_un_reply_num,omitempty"`
	ShopDesc                       string      `json:"shop_desc,omitempty"`
	SecShopId                      string      `json:"sec_shop_id,omitempty"`
	IsHainanTaxfree                int         `json:"is_hainan_taxfree,omitempty"`
	QualificationIsExpired         int         `json:"qualification_is_expired,omitempty"`
	IsBic                          int         `json:"is_bic,omitempty"`
	ProShop                        int         `json:"pro_shop,omitempty"`
	IsSelfOperating                int         `json:"is_self_operating,omitempty"`
	IsDaren                        int         `json:"is_daren,omitempty"`
	IsDarenShop                    int         `json:"is_daren_shop,omitempty"`
	IsJingPai                      int         `json:"is_jing_pai,omitempty"`
	IsMarvelBid                    int         `json:"is_marvel_bid,omitempty"`
	IsMarvelNoBid                  int         `json:"is_marvel_no_bid,omitempty"`
	IsAppleStore                   int         `json:"is_apple_store,omitempty"`
	IsMarketHour                   int         `json:"is_market_hour,omitempty"`
	IsMarketDay                    int         `json:"is_market_day,omitempty"`
	IsSubManager                   bool        `json:"is_sub_manager,omitempty"`
	LoginDomainType                int         `json:"login_domain_type,omitempty"`
}

type ShopInfoResp struct {
	Data  ShopInfo `json:"data"`
	Page  int      `json:"page"`
	Size  int      `json:"size"`
	Total int      `json:"total"`
}

type BoundUser struct {
	AwemeId   string `json:"aweme_id"`
	Name      string `json:"name"`
	Avatar    string `json:"avatar"`
	AccountId string `json:"account_id"`
}

type CheckInsuranceResp struct {
	Data struct {
		Login struct {
			SessionId string `json:"SessionId"`
			BaseResp  struct {
				StatusMessage string `json:"StatusMessage"`
				StatusCode    int    `json:"StatusCode"`
			} `json:"BaseResp"`
		} `json:"Login"`
	} `json:"data"`
}

type listBoundUserIDsResp struct {
	StatusCode int    `json:"status_code"`
	Message    string `json:"message"`
	Data       struct {
		Pagination struct {
			Page      int    `json:"page"`
			PageSize  int    `json:"pageSize"`
			TotalNum  string `json:"totalNum"`
			TotalPage int    `json:"totalPage"`
		} `json:"pagination"`
		BindUserInfos []struct {
			HasShopPermission bool `json:"hasShopPermission"`
			AwemeUserInfo     struct {
				Id          string `json:"id"`
				ShortId     string `json:"shortId"`
				Name        string `json:"name"`
				SmallAvatar struct {
					ImageMode int      `json:"imageMode"`
					Uri       string   `json:"uri"`
					UrlList   []string `json:"urlList"`
				} `json:"smallAvatar"`
				UniqueId string `json:"uniqueId"`
				ShowId   string `json:"showId"`
			} `json:"awemeUserInfo"`
			AuthTypes       []int `json:"authTypes"`
			HighestAuthType int   `json:"highestAuthType"`
			AnchorLimitInfo struct {
				IsAnchorLivePermissionLimit bool `json:"isAnchorLivePermissionLimit"`
			} `json:"anchorLimitInfo"`
			UserInfo struct {
				Id          string `json:"id"`
				ShortId     string `json:"shortId"`
				Name        string `json:"name"`
				SmallAvatar struct {
					ImageMode int      `json:"imageMode"`
					Uri       string   `json:"uri"`
					UrlList   []string `json:"urlList"`
				} `json:"smallAvatar"`
				UniqueId string `json:"uniqueId"`
				ShowId   string `json:"showId"`
			} `json:"userInfo"`
			BindTypes []int `json:"bindTypes"`
		} `json:"bindUserInfos"`
	} `json:"data"`
}
