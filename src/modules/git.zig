const std = @import("std");
const sqlite = @import("sqlite");
const Allocator = std.mem.Allocator;

// UI参考: https://www.appinn.com/wp-content/uploads/2024/01/lizhi-star-order4.jpg

// api 接口对象模型
const User = struct { login: []u8, id: i32, node_id: []u8, avatar_url: []u8, gravatar_id: []u8, url: []u8, html_url: ?[]u8, followers_url: []u8, following_url: []u8, gists_url: []u8, starred_url: []u8, subscriptions_url: []u8, organizations_url: []u8, repos_url: []u8, events_url: []u8, received_events_url: []u8, type: []u8, site_admin: bool, name: []u8, company: ?[]u8, blog: []u8, location: ?[]u8, email: ?[]u8, hireable: ?[]u8, bio: ?[]u8, twitter_username: ?[]u8, public_repos: i32, public_gists: i32, followers: i32, following: i32, created_at: []u8, updated_at: []u8, private_gists: i32, total_private_repos: i32, owned_private_repos: i32, disk_usage: i32, collaborators: i32, two_factor_authentication: bool };
const FollowUser = struct { login: ?[]u8, id: i32, node_id: ?[]u8, avatar_url: ?[]u8, gravatar_id: ?[]u8, url: ?[]u8, html_url: ?[]u8, followers_url: ?[]u8, following_url: ?[]u8, gists_url: ?[]u8, starred_url: ?[]u8, subscriptions_url: ?[]u8, organizations_url: ?[]u8, repos_url: ?[]u8, events_url: ?[]u8, received_events_url: ?[]u8, type: ?[]u8, site_admin: bool };
const FailMessage = struct { message: ?[]u8, documentation_url: ?[]u8 };
const Repository = struct { id: i32, node_id: []u8, name: []u8, full_name: []u8, owner: ?Owner, private: bool, html_url: ?[]u8, description: ?[]u8, fork: bool, url: ?[]u8, archive_url: ?[]u8, assignees_url: ?[]u8, blobs_url: ?[]u8, branches_url: ?[]u8, collaborators_url: ?[]u8, comments_url: ?[]u8, commits_url: ?[]u8, compare_url: ?[]u8, contents_url: ?[]u8, contributors_url: ?[]u8, deployments_url: ?[]u8, downloads_url: ?[]u8, events_url: ?[]u8, forks_url: ?[]u8, git_commits_url: ?[]u8, git_refs_url: ?[]u8, git_tags_url: ?[]u8, git_url: ?[]u8, issue_comment_url: ?[]u8, issue_events_url: ?[]u8, issues_url: ?[]u8, keys_url: ?[]u8, labels_url: ?[]u8, languages_url: ?[]u8, merges_url: ?[]u8, milestones_url: ?[]u8, notifications_url: ?[]u8, pulls_url: ?[]u8, releases_url: ?[]u8, ssh_url: ?[]u8, stargazers_url: ?[]u8, statuses_url: ?[]u8, subscribers_url: ?[]u8, subscription_url: ?[]u8, tags_url: ?[]u8, teams_url: ?[]u8, trees_url: ?[]u8, clone_url: ?[]u8, mirror_url: ?[]u8, hooks_url: ?[]u8, svn_url: ?[]u8, homepage: ?[]u8, language: ?[]u8, forks_count: i32, stargazers_count: i32, watchers_count: i32, size: i32, default_branch: ?[]u8, open_issues_count: i32, is_template: bool, topics: ?[][]u8, has_issues: bool, has_projects: bool, has_wiki: bool, has_pages: bool, has_downloads: bool, archived: bool, disabled: bool, visibility: []u8, pushed_at: []u8, created_at: []u8, updated_at: []u8, permissions: ?Permissions, allow_rebase_merge: bool = false, template_repository: ?[]u8 = null, temp_clone_token: ?[]u8 = null, allow_squash_merge: bool = false, allow_auto_merge: bool = false, delete_branch_on_merge: bool = false, allow_merge_commit: bool = false, subscribers_count: i32 = 0, network_count: i32 = 0, forks: i32 = 0, open_issues: i32 = 0, watchers: i32 = 0 };
const Owner = struct { login: []u8, id: i32, node_id: []u8, avatar_url: []u8, gravatar_id: []u8, url: []u8, html_url: ?[]u8 = null, followers_url: []u8, following_url: []u8, gists_url: []u8, starred_url: []u8, subscriptions_url: []u8, organizations_url: []u8, repos_url: []u8, events_url: []u8, received_events_url: []u8, type: []u8, site_admin: bool };
const Permissions = struct { admin: bool, push: bool, pull: bool };
const License = struct { key: []u8 = "", name: []u8 = "", url: []u8 = "", spdx_id: []u8 = "", node_id: []u8 = "", html_url: []u8 = "" };
const Readme = struct { type: []u8, encoding: []u8, size: i32, name: []u8, path: []u8, content: []u8, sha: []u8, url: []u8, git_url: []u8, html_url: []u8, download_url: []u8, _links: ?struct { git: []u8, self: []u8, html: []u8 } };
const GTrendItem = struct { author: []u8, name: []u8, avatar: []u8, description: []u8, url: []u8, language: []u8, languageColor: []u8, stars: i32, forks: i32, currentPeriodStars: i32, builtBy: []struct { username: []u8, href: []u8, avatar: []u8 } };
const GetTokenResp = struct { access_token: []u8, token_type: []u8, scope: []u8 };

// sqlite 模型
const UserModel = struct { id: ?i32 = null, login: ?[]u8 = null, avatar: ?[]u8 = null, followers: ?i32 = null, following: ?i32 = null, git_token: ?[]const u8 = null };
const TagModel = struct { repository_id: ?i32 = null, author: ?[]u8 = null, name: ?[]u8 = null, language: ?[]u8 = null, tag: ?[]u8 = null };
const RepositoryModel = struct { id: ?i32 = null, name: ?[]u8 = null, full_name: ?[]u8 = null, author: ?[]u8 = null, avatar: ?[]u8 = null, login: ?[]u8 = null, description: ?[]u8 = null, forks_count: ?i32 = 0, stargazers_count: ?i32 = 0, watchers_count: ?i32 = 0, default_branch: ?[]u8 = null, open_issues_count: ?i32 = 0, language: ?[]u8 = null, url: ?[]u8 = null, readme: ?[]u8 = null, created_at: ?[]u8 = null, updated_at: ?[]u8 = null, pushed_at: ?[]u8 = null };
const LanguageCountModel = struct { language: []u8 = "", count: i32 = 0 };

// GitApi对象
pub const GitApi = struct {
    base_url: []const u8 = "https://api.github.com",
    token: []const u8 = undefined,
    allocator: Allocator,
    db: sqlite.Db,
    user: ?UserModel = null,
    last_error_message: ?[]const u8 = null,
    client_id: ?[]const u8 = null,
    client_secret: ?[]const u8 = null,

    pub fn init(allocator: Allocator, token: []const u8) !GitApi {
        const buf = try allocator.dupe(u8, token);

        var db = try sqlite.Db.init(.{
            .mode = sqlite.Db.Mode{ .File = "git.db" },
            .open_flags = .{ .write = true, .create = true },
            .threading_mode = .MultiThread,
        });

        // 判断users表是否存在
        var stmt = try db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?");
        defer stmt.deinit();

        var row = try stmt.one(usize, .{}, .{ .name = "users" });
        if (row == null) {
            try db.exec("CREATE TABLE users(id INTEGER PRIMARY KEY, login TEXT, avatar TEXT, followers INTEGER, following INTEGER, git_token TEXT)", .{}, .{});
        }
        stmt.reset();

        row = try stmt.one(usize, .{}, .{ .name = "repos" });
        if (row == null) {
            try db.exec("CREATE TABLE repos(id INTEGER PRIMARY KEY, name TEXT, full_name TEXT, author TEXT, login TEXT, avatar TEXT, description TEXT, forks_count INTEGER, stargazers_count INTEGER, watchers_count INTEGER, default_branch TEXT, open_issues_count INTEGER, language TEXT, url TEXT, readme TEXT, created_at TEXT, updated_at TEXT, pushed_at TEXT)", .{}, .{});
        }
        stmt.reset();

        row = try stmt.one(usize, .{}, .{ .name = "tags" });
        if (row == null) {
            try db.exec("CREATE TABLE tags(repository_id INTEGER, author TEXT, name TEXT, language TEXT, tag TEXT)", .{}, .{});
        }

        var git_api = GitApi{ .allocator = allocator, .token = buf, .db = db };
        try git_api._user();

        return git_api;
    }

    pub fn deinit(self: *GitApi) void {
        self.allocator.free(self.token);
        if (self.last_error_message) |_| {
            self.allocator.free(self.last_error_message.?);
        }
        self.db.deinit();
    }

    fn api(self: *GitApi, path: []const u8) []const u8 {
        return std.mem.concat(self.allocator, u8, &[_][]const u8{ self.base_url, path }) catch unreachable;
    }

    fn _user(self: *GitApi) !void {
        if (try self.db.oneAlloc(UserModel, self.allocator, "SELECT * FROM users where git_token = ?", .{}, .{ .git_token = self.token })) |model| {
            self.user = model;
            return;
        }
        var rest = try self.request("/user", .GET, null);
        defer rest.deinit();

        var user_info = try std.json.parseFromSlice(User, self.allocator, rest.body.?, .{ .ignore_unknown_fields = true });
        defer user_info.deinit();

        const model = UserModel{ .id = user_info.value.id, .login = try self.allocator.dupe(u8, user_info.value.login), .avatar = try self.allocator.dupe(u8, user_info.value.avatar_url), .git_token = self.token, .followers = user_info.value.followers, .following = user_info.value.following };
        self.db.exec("INSERT INTO users (id, login, avatar, followers, following, git_token) VALUES (?, ?, ?, ?, ?, ?)", .{}, model) catch |err| std.log.err("{any}\n", .{err});
        self.user = model;
    }

    /// 获取当前用户信息
    pub fn get_user(self: *GitApi) ?UserModel {
        return self.user;
    }

    pub fn list_starred_repos(self: *GitApi) ![]RepositoryModel {
        var stmt = try self.db.prepare("SELECT * FROM repos WHERE login = ?");
        defer stmt.deinit();
        const repos = try stmt.all(RepositoryModel, self.allocator, .{}, .{ .login = self.user.?.login });
        if (repos.len > 0) return repos;
        var page: usize = 1;
        var total_items: usize = 0;
        while (true) {
            const item_nums = try self.list_starred_repo_with_page(page);
            total_items += item_nums;
            if (item_nums == 0) break;
            page = page +| 1;
        }
        if (total_items == 0) return try self.allocator.alloc(RepositoryModel, 0);

        return self.list_starred_repos();
    }

    /// get_repo_readme_html 获取仓库的readme信息
    pub fn get_repo_readme_html(self: *GitApi, author: []const u8, resp: []const u8) ![]const u8 {
        const fullname = try std.mem.concat(self.allocator, u8, &[_][]const u8{ author, "/", resp });
        defer self.allocator.free(fullname);

        var select_stmt = try self.db.prepare("SELECT readme FROM repos WHERE full_name = ? LIMIT 1");
        defer select_stmt.deinit();
        var iter = try select_stmt.iterator([]const u8, .{ .full_name = fullname });
        while (try iter.nextAlloc(self.allocator, .{})) |reademe| {
            if (reademe.len > 0) {
                return reademe;
            }
            self.allocator.free(reademe);
        }

        const uri = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/readme", .{ author, resp });
        defer self.allocator.free(uri);
        var rest = try self.request(uri, .GET, null);
        defer rest.deinit();

        var readme = try std.json.parseFromSlice(Readme, self.allocator, rest.body.?, .{ .allocate = .alloc_always, .ignore_unknown_fields = true, .duplicate_field_behavior = .use_last });
        defer readme.deinit();

        var replaced_content = try self.allocator.alloc(u8, readme.value.content.len);
        readme.value.content = replaced_content[0 .. readme.value.content.len - std.mem.replace(u8, readme.value.content, "\n", "", replaced_content)];
        const len = try std.base64.standard.Decoder.calcSizeForSlice(readme.value.content);
        var buf: [409600]u8 = undefined;
        const decoded = buf[0..len];
        try std.base64.standard.Decoder.decode(decoded, readme.value.content);

        const stringify_txt = try std.json.stringifyAlloc(self.allocator, struct { text: []const u8 }{
            .text = decoded,
        }, .{});
        defer self.allocator.free(stringify_txt);

        var markdown_resp = try self.request("/markdown", .POST, stringify_txt);
        defer markdown_resp.deinit();

        try self.db.exec("UPDATE repos SET readme = ? WHERE login = ? AND full_name = ?", .{}, .{ markdown_resp.body.?, self.user.?.login, fullname });
        return try self.allocator.dupe(u8, markdown_resp.body.?);
    }

    pub fn get_languages_count(self: *GitApi) ![]LanguageCountModel {
        var stmt = try self.db.prepare("SELECT language, count(*) AS count FROM repos GROUP BY \"language\" order by COUNT(*) DESC");
        defer stmt.deinit();
        return stmt.all(LanguageCountModel, self.allocator, .{}, .{});
    }

    pub fn list_starred_repo_with_page(self: *GitApi, page: usize) !usize {
        const uri = try std.fmt.allocPrint(self.allocator, "/user/starred?pre_page=100&page={d}", .{page});
        defer self.allocator.free(uri);

        var rest = try self.request(uri, .GET, null);
        defer rest.deinit();
        var repos = try std.json.parseFromSlice([]Repository, self.allocator, rest.body.?, .{ .allocate = .alloc_always, .ignore_unknown_fields = true, .duplicate_field_behavior = .use_last });
        defer repos.deinit();

        for (repos.value) |repo| {
            const model = RepositoryModel{ .id = repo.id, .name = repo.name, .full_name = repo.full_name, .author = repo.owner.?.login, .avatar = repo.owner.?.avatar_url, .login = self.user.?.login, .description = repo.description, .forks_count = repo.forks_count, .stargazers_count = repo.stargazers_count, .watchers_count = repo.watchers_count, .default_branch = repo.default_branch, .open_issues_count = repo.open_issues_count, .language = repo.language, .url = repo.html_url, .readme = "", .created_at = repo.created_at, .updated_at = repo.updated_at, .pushed_at = repo.pushed_at };
            self.db.exec("INSERT INTO repos (id, name, full_name, author, avatar, login, description, forks_count, stargazers_count, watchers_count, default_branch, open_issues_count, language, url, readme, created_at, updated_at, pushed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", .{}, model) catch |err| std.log.err("{any}\n", .{err});
        }
        return repos.value.len;
    }

    fn request(self: *GitApi, path: []const u8, method: std.http.Method, body: ?[]const u8) !std.http.Client.FetchResult {
        var headers = std.http.Headers.init(self.allocator);
        defer headers.deinit();

        const authorization: []const u8 = std.mem.concat(self.allocator, u8, &[_][]const u8{ "Bearer ", self.token }) catch unreachable;
        defer self.allocator.free(authorization);

        try headers.append("Authorization", authorization);
        try headers.append("Accept", "application/vnd.github+json");
        try headers.append("X-GitHub-Api-Version", "2022-11-28");

        // const proxy = std.http.Client.Proxy{
        //     .headers = .{
        //         .allocator = self.allocator,
        //     },
        //     .allocator = self.allocator,
        //     .host = "localhost",
        //     .port = 7890,
        //     .protocol = .plain,
        // };

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        try std.http.Client.loadDefaultProxies(&client);

        var fullpath: []const u8 = undefined;
        if (!std.mem.startsWith(u8, path, "http")) {
            fullpath = self.api(path);
        } else {
            fullpath = try self.allocator.dupe(u8, path);
        }
        defer self.allocator.free(fullpath);

        var options = std.http.Client.FetchOptions{ .method = method, .location = .{ .url = fullpath }, .headers = headers };
        if (options.method == .POST and body != null) {
            options.payload = .{ .string = body.? };
        }

        const resp = try client.fetch(self.allocator, options);

        if (self.last_error_message) |message| {
            self.allocator.free(message);
            self.last_error_message = null;
        }

        if (resp.status != std.http.Status.ok and resp.status != std.http.Status.no_content) {
            if (resp.body) |body_| {
                const message = std.json.parseFromSlice(FailMessage, self.allocator, body_, .{ .ignore_unknown_fields = true }) catch |e| return e;
                self.last_error_message = message.value.message.?;
            } else {
                self.last_error_message = try std.fmt.allocPrint(self.allocator, "{s} response code is: {any}", .{ path, resp.status });
            }
            std.log.err("request {s} failed: {s}\n", .{ fullpath, self.last_error_message.? });
            return error.GitApiStatusError;
        }
        return resp;
    }

    /// get_trending_html 获取趋势html
    pub fn get_trending_html(self: *GitApi, lang: []const u8, since: []const u8) ![]const u8 {
        const url = try std.fmt.allocPrint(self.allocator, "https://github.com/trending/{s}?since={s}", .{ lang, since });
        defer self.allocator.free(url);

        var resp = try self.request(url, .GET, null);
        defer resp.deinit();
        return try self.allocator.dupe(u8, resp.body.?);
    }

    /// get_trending_api_leaky 通过第三方接口获取趋势榜单， 无需手动释放内存
    pub fn get_trending_api_leaky(self: *GitApi, lang: []const u8, since: []const u8) ![]GTrendItem {
        const url = try std.fmt.allocPrint(self.allocator, "https://gtrend.yapie.me/repositories?since={s}&language={s}", .{ since, lang });
        defer self.allocator.free(url);

        var resp = try self.request(url, .GET, null);
        defer resp.deinit();

        return try std.json.parseFromSliceLeaky(
            []GTrendItem,
            self.allocator,
            resp.body.?,
            .{
                .allocate = .alloc_always,
                .ignore_unknown_fields = true,
                .duplicate_field_behavior = .use_last,
            },
        );
    }

    // 根据内容解析趋势信息后再存储到数据库内 @ref get_trend_html
    pub fn set_trend_repos(self: *GitApi, date: []const u8, lang: []const u8, repos: []RepositoryModel) void {
        _ = self;
        _ = date;
        _ = lang;
        _ = repos;
        // for (repos) |repo| {
        //     // todo
        // }
    }

    /// star 添加仓库星标
    pub fn star(self: *GitApi, owner: []const u8, repo: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/user/starred/{s}/{s}", .{ owner, repo });
        var resp = try self.request(path, .PUT);
        resp.deinit();
    }

    /// unstar 取消仓库星标
    pub fn unstar(self: *GitApi, owner: []const u8, repo: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/user/starred/{s}/{s}", .{ owner, repo });
        var resp = try self.request(path, .DELETE);
        resp.deinit();
    }

    /// followers 获取关注我
    pub fn followers(self: *GitApi) ![]FollowUser {
        var page: usize = 1;
        var items = std.ArrayList(FollowUser).init(self.allocator);
        while (true) {
            const page_items = try self.follow_page(FollowUser, "followers", page);
            if (page_items.len == 0) break;
            try items.appendSlice(page_items);
            page = page +| 1;
        }
        return items.toOwnedSlice();
    }

    /// following 我关注的人
    pub fn following(self: *GitApi) ![]FollowUser {
        var page: usize = 1;
        var items = std.ArrayList(FollowUser).init(self.allocator);
        while (true) {
            const page_items = try self.follow_page(FollowUser, "following", page);
            if (page_items.len == 0) break;
            try items.appendSlice(page_items);
            page = page +| 1;
        }
        return items.toOwnedSlice();
    }

    /// follow_page 分页数据
    fn follow_page(self: *GitApi, comptime T: type, uri_: []const u8, page: usize) ![]T {
        const uri = try std.fmt.allocPrint(self.allocator, "/user/{s}?pre_page=100&page={d}", .{ uri_, page });
        defer self.allocator.free(uri);
        var rest = try self.request(uri, .GET, null);
        defer rest.deinit();
        const items = try std.json.parseFromSlice([]T, self.allocator, rest.body.?, .{ .allocate = .alloc_always, .ignore_unknown_fields = true, .duplicate_field_behavior = .use_last });
        var collection = std.ArrayList(T).init(self.allocator);
        for (items.value) |item| {
            try collection.append(item);
        }
        return collection.toOwnedSlice();
    }

    /// get_repository_by_id 根据Id获取仓库信息
    pub fn get_repository_by_id(self: *GitApi, repository_id: i32) !?RepositoryModel {
        var stmt = try self.db.prepare("SELECT * FROM repositories WHERE id = ?");
        defer stmt.deinit();

        return try stmt.one(RepositoryModel, .{}, .{ .id = repository_id });
    }

    /// add_tag 添加标签
    pub fn add_tag(self: *GitApi, repository_id: i32, author: []const u8, repo: []const u8, language: []const u8, tag: []const u8) !void {
        if (try self.get_repository_by_id(repository_id)) |_| {
            const tag_model: TagModel = .{ .repository_id = repository_id, .author = author, .name = repo, .language = language, .tag = tag };
            try self.db.exec("INSERT INTO tags(author, name, language, tag) VALUES(?, ?, ?, ?)", .{}, tag_model);
        }
    }

    /// delete_tag 删除标签
    pub fn delete_tag(self: *GitApi, repository_id: i32, tag: []const u8) !void {
        try self.db.exec("DELETE FROM tags WHERE repository_id = ? AND tag = ?", .{}, .{ repository_id, tag });
    }

    /// list_repo_by_tag 根据标签获取仓库列表
    pub fn list_repo_by_tag(self: GitApi, tag: []const u8) []RepositoryModel {
        var repos = std.ArrayList(RepositoryModel).init(self.allocator);

        var stmt = try self.db.prepare("SELECT repository_id FROM tags WHERE tag = ?");
        defer stmt.deinit();

        const repository_ids = try stmt.all(struct { repository_id: []const u8 }, self.allocator, .{}, .{tag});
        if (repository_ids.len == 0) return repos.toOwnedSlice();

        var repository_id_slice = std.ArrayList([]const u8).init(self.allocator);
        defer repository_id_slice.deinit();
        for (repository_ids) |value| {
            try repository_id_slice.append(value.repository_id);
        }

        const ids = try std.mem.join(self.allocator, ",", repository_id_slice.items);
        self.allocator.free(ids);

        var stmt_repos = try self.db.prepare("SELECT * FROM repos WHERE repo_id IN (" ++ ids ++ ")");
        defer stmt_repos.deinit();

        return try stmt_repos.all(RepositoryModel, self.allocator, .{}, .{});
    }

    /// follow 关注开发者
    pub fn follow(self: *GitApi, username: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/user/following/{s}", .{username});
        var resp = try self.request(path, .PUT);
        resp.deinit();
    }

    /// unfollow 取消关注开发者
    pub fn unfollow(self: *GitApi, username: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/user/following/{s}", .{username});
        var resp = try self.request(path, .DELETE);
        resp.deinit();
    }

    /// get_token_by_code 根据code获取token
    pub fn get_token_by_code(self: *GitApi, code: []const u8) ![]const u8 {
        const url = try std.fmt.allocPrint(self.allocator, "https://github.com/login/oauth/access_token", .{});
        defer self.allocator.free(url);

        var resp = try self.request(url, .POST, "client_id={s}&client_secret={s}&code={s}", .{
            self.client_id.?,
            self.client_secret.?,
            code,
        });
        defer resp.deinit();
    }
};
