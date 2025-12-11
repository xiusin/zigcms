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

// 部门相关 DTO
pub const department = struct {
    pub const Create = @import("department_create.dto.zig").DepartmentCreateDto;
    pub const Update = @import("department_update.dto.zig").DepartmentUpdateDto;
    pub const Response = @import("department_response.dto.zig").DepartmentResponseDto;
};

// 员工相关 DTO
pub const employee = struct {
    pub const Create = @import("employee_create.dto.zig").EmployeeCreateDto;
    pub const Update = @import("employee_update.dto.zig").EmployeeUpdateDto;
    pub const Response = @import("employee_response.dto.zig").EmployeeResponseDto;
};

// 职位相关 DTO
pub const position = struct {
    pub const Create = @import("position_create.dto.zig").PositionCreateDto;
    pub const Update = @import("position_update.dto.zig").PositionUpdateDto;
    pub const Response = @import("position_response.dto.zig").PositionResponseDto;
};

// 角色相关 DTO
pub const role = struct {
    pub const Create = @import("role_create.dto.zig").RoleCreateDto;
    pub const Update = @import("role_update.dto.zig").RoleUpdateDto;
    pub const Response = @import("role_response.dto.zig").RoleResponseDto;
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
