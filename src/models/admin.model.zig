// CREATE TABLE "zigcms"."admin" (
//     "id" int4 NOT NULL DEFAULT nextval('zigcms.untitled_table_235_id_seq'::regclass),
//     "user_name" varchar NOT NULL,
//     "password" varchar NOT NULL,
//     "created_at" timestamp,
//     PRIMARY KEY ("id")
// );

const std = @import("std");

pub const Admin = struct {
    id: i32,
    user_name: []const u8,
    password: []const u8,
    created_at: i64,
};
