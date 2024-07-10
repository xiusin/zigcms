package main

import "core:bytes"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:strings"
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
	fmt.println("api_url =", API_URL)
	t_strings()
}

t_strings :: proc() {
	str := `{"name": "xiusin", "age": 2, "active": false, "friends": ["zhangsan", "lisi"], "score": 92.19992838}`
	p: Person
	_ = json.unmarshal(str_to_bytes(str), &p)
	p.score = math.round_f64(p.score * 100) / 100

	p.address = strings.concatenate({"中国", "河南", "郑州", "黄河路"})
	assert(p.address == "中国河南郑州黄河路") // TODO 打印有问题,转为了unicode码了

	builder := strings.builder_from_bytes(str_to_bytes("this is a bytes"))
	strings.builder_grow(&builder, 1024)
	strings.write_string(&builder, ". we are the champions.")

	defer strings.builder_destroy(&builder)

	// 如何打印


}

// str_to_bytes 字符串转换为字节切片
str_to_bytes :: proc(str: string) -> []u8 {
	return transmute([]u8)str
}
