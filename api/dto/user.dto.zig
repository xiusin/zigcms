/// 用户注册数据传输对象
pub const Register = struct {
    /// 用户名（必填）
    username: []const u8,
    /// 密码（必填）
    password: []const u8,
    
    /// 验证注册数据有效性
    pub fn validate(self: @This()) !void {
        if (self.username.len == 0) return error.UsernameRequired;
        if (self.username.len < 3) return error.UsernameTooShort;
        if (self.username.len > 20) return error.UsernameTooLong;
        if (self.password.len == 0) return error.PasswordRequired;
        if (self.password.len < 6) return error.PasswordTooShort;
    }
};

/// 用户登录数据传输对象
pub const Login = struct {
    /// 用户名（必填）
    username: []const u8,
    /// 密码（必填）
    password: []const u8,
    
    /// 验证登录数据有效性
    pub fn validate(self: @This()) !void {
        if (self.username.len == 0) return error.UsernameRequired;
        if (self.password.len == 0) return error.PasswordRequired;
    }
};
