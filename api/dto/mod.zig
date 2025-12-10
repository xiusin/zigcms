// DTO 命名空间 - 按功能分组
const std = @import("std");

// 用户相关 DTO
pub const user = struct {
    pub const Login = @import("user_login.dto.zig").UserLoginDto;
    pub const Register = @import("user_register.dto.zig").UserRegisterDto;
    pub const Profile = @import("user_profile.dto.zig").UserProfileDto;
};

// 文件上传相关 DTO
pub const upload = struct {
    pub const UploadMeta = @import("upload_meta.dto.zig").UploadMetaDto;
    pub const Folder = @import("folder.dto.zig").FolderDto;
    pub const File = @import("file.dto.zig").FileDto;
};

// 设置相关 DTO
pub const setting = struct {
    pub const Save = @import("setting_save.dto.zig").SettingSaveDto;
    pub const Mail = @import("mail.dto.zig").MailDto;
};

// 字典相关 DTO
pub const dict = struct {
    pub const Create = @import("dict_create.dto.zig").DictCreateDto;
    pub const Update = @import("dict_update.dto.zig").DictUpdateDto;
    pub const Response = @import("dict_response.dto.zig").DictResponseDto;
};

// 公共 DTO
pub const common = struct {
    pub const Page = @import("page.dto.zig").PageDto;
    pub const Result = @import("result.dto.zig").ResultDto;
};

// 菜单相关 DTO
pub const menu = struct {
    pub const Save = @import("menu_save.dto.zig").MenuSaveDto;
    pub const Item = @import("menu_item.dto.zig").MenuItemDto;
};
