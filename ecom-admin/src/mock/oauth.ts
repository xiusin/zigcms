/**
 * OAuth 第三方登录 Mock 数据
 */
import Mock from 'mockjs';
import { success, pageSuccess } from './data';

// 生成随机用户ID
const generateProviderUserId = (provider: string) => {
  return `${provider}_${Math.random().toString(36).substring(2, 11)}`;
};

// OAuth Mock 数据配置
const oauthMock = [
  // 获取授权 URL
  {
    url: /\/api\/oauth\/authorize/,
    method: 'get',
    response: ({ query }: any) => {
      const { provider } = query;
      const redirectUriMap: Record<string, string> = {
        feishu: 'http://localhost:5173/oauth/callback/feishu',
        github: 'http://localhost:5173/oauth/callback/github',
      };
      return success({
        url: `http://mock.oauth.local/authorize?provider=${provider}&redirect_uri=${redirectUriMap[provider] || ''}`,
      });
    },
  },
  // 处理 OAuth 回调
  {
    url: /\/api\/oauth\/callback/,
    method: 'post',
    response: ({ body }: any) => {
      const { provider, code } = body || {};
      
      // 模拟不同提供商的返回数据
      if (provider === 'feishu') {
        return success({
          access_token: `feishu_mock_token_${Date.now()}`,
          refresh_token: `feishu_mock_refresh_${Date.now()}`,
          expires_in: 7200,
          user: {
            id: generateProviderUserId('feishu'),
            username: `feishu_user_${Math.floor(Math.random() * 1000)}`,
            nickname: Mock.Random.cname(),
            email: `${Mock.Random.word(6)}@feishu.cn`,
            avatar_url: `https://i.pravatar.cc/150?u=${Math.random()}`,
          },
          raw_info: {
            open_id: generateProviderUserId('feishu'),
            union_id: `union_${generateProviderUserId('feishu')}`,
          },
        });
      } else if (provider === 'github') {
        return success({
          access_token: `github_mock_token_${Date.now()}`,
          refresh_token: `github_mock_refresh_${Date.now()}`,
          expires_in: 7200,
          user: {
            id: generateProviderUserId('github'),
            username: `github_${Math.random().toString(36).substring(2, 8)}`,
            nickname: Mock.Random.cname(),
            email: `${Mock.Random.word(6)}@github.com`,
            avatar_url: `https://i.pravatar.cc/150?u=${Math.random()}`,
          },
          raw_info: {
            github_id: Math.floor(Math.random() * 1000000),
            node_id: `MDQ6VXNlcj${Math.floor(Math.random() * 1000000)}`,
          },
        });
      }
      
      return success({
        access_token: `mock_token_${Date.now()}`,
        expires_in: 7200,
        user: {
          id: generateProviderUserId('default'),
          username: `user_${Math.floor(Math.random() * 1000)}`,
          nickname: Mock.Random.cname(),
        },
      });
    },
  },
  // 绑定 OAuth 账户
  {
    url: /\/api\/oauth\/bind/,
    method: 'post',
    response: () => {
      return success({
        need_bind: false,
        user: {
          id: Math.floor(Math.random() * 10000),
          username: Mock.Random.word(6, 12),
          nickname: Mock.Random.cname(),
          avatar: `https://i.pravatar.cc/150?u=${Math.random()}`,
        },
        bind_info: {
          provider: 'feishu',
          provider_user_id: generateProviderUserId('feishu'),
          bind_time: Mock.Random.datetime(),
        },
      });
    },
  },
  // 解绑 OAuth 账户
  {
    url: /\/api\/oauth\/unbind/,
    method: 'delete',
    response: () => {
      return success(null, '解绑成功');
    },
  },
  // 获取绑定列表
  {
    url: /\/api\/oauth\/bind\/list/,
    method: 'get',
    response: () => {
      return success([
        {
          provider: 'feishu',
          provider_user_id: generateProviderUserId('feishu'),
          bind_time: Mock.Random.datetime(),
          nickname: Mock.Random.cname(),
          avatar_url: `https://i.pravatar.cc/150?u=feishu`,
        },
      ]);
    },
  },
];

export default oauthMock;
