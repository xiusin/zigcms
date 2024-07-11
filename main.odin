package main

import "core:bytes"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync/chan"
import "core:time"
import "core:unicode/utf8"

API_URL :: "https://webhook.site/4022e8ae-c3ae-4f2f-a85f-b3d891a71593"

Person :: struct {
	name:    string,
	age:     int,
	active:  bool,
	score:   f64,
	address: string,
	friends: []string,
}


main :: proc() {
	t_time()
	t_strings()
}


t_time :: proc() {
	fmt.println("=========== time  S =============")
	now := time.now()
	fmt.println("time.unix =", time.time_to_unix(now))
	time.accurate_sleep(time.Second * 2)
	fmt.println("time.unix =", time.time_to_unix(time.time_add(now, time.Second * 2)))
    
    // 缺少时区数据
	y, m, d := time.date(now)
	h, i, s := time.clock(now)

	fmt.printf("当前时间 = %d-%d-%d %d:%d:%d\n", y, m, d, h, i, s)

	fmt.println("=========== time  E =============\n\n\n")
}

t_strings :: proc() {
	fmt.println("=========== strings  S =============")
	str := `{"name": "xiusin", "age": 2, "active": false, "friends": ["zhangsan", "lisi"], "score": 92.19992838}`
	p: Person
	_ = json.unmarshal(str_to_bytes(str), &p)
	p.score = math.round_f64(p.score * 100) / 100

	p.address = strings.concatenate({"中国", "河南", "郑州", "黄河路"})
	assert(p.address == "中国河南郑州黄河路") // TODO 打印有问题,转为了unicode码了

	fmt.println(&p)
	byts := str_to_bytes("this is a bytes")

	// bytes: [10]byte // 有点像zig 先初始化一个容器
	// builder := strings.builder_from_bytes(bytes[:])

	// 初始化动态容器
	builder := strings.builder_make()
	strings.write_string(&builder, "we are the champions.")

	defer strings.builder_destroy(&builder)
	fmt.println(
		"builder.to_string =",
		strings.to_string(builder),
		" len=",
		len(strings.to_string(builder)),
	)

	strings.builder_grow(&builder, 1024)
	strings.write_string(&builder, " growed append!")

	fmt.println(strings.to_string(builder))

	fmt.println("strings.to_pascal_case =", strings.to_pascal_case("hello world"))

	fmt.println("=========== strings  E =============")
}

// str_to_bytes 字符串转换为字节切片
str_to_bytes :: proc(str: string) -> []byte {
	return transmute([]byte)str
}
