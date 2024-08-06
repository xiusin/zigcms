struct MyStruct {
    x: i32,
    y: f32,
    z: bool,
}

fn structToTuple(myStruct: MyStruct) ([3]type(myStruct.x)) {
    return [3]type(myStruct.x){myStruct.x, myStruct.y, myStruct.z};
}

const myStruct = MyStruct{.x = 10,.y = 3.14,.z = true };
const myTuple = structToTuple(myStruct);

// 打印 myTuple 中的值
std.debug.print("myTuple 中的值: {d}, {f}, {}\n",.{myTuple[0], myTuple[1], myTuple[2]});