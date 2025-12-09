const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

const signature = &[_][]const u8{
    "cache-control",
    "content-disposition",
    "content-encoding",
    "content-length",
    "content-md5",
    "content-type",
    "expires",
    "host",
    "if-match",
    "if-modified-since",
    "if-none-match",
    "if-unmodified-since",
    "origin",
    "range",
    "transfer-encoding",
    "pic-operations",
};

config: Config = undefined,
allocator: Allocator,

pub const Config = struct {
    bucket: []const u8,
    token: []const u8,
    access_key: []const u8,
    secret_key: []const u8,
    expire: ?u64 = null,
    signHost: bool = false,
};

pub fn init(allocator: Allocator, config: Config) Self {
    return .{
        .config = config,
        .allocator = allocator,
    };
}

pub fn deinit(_: *Self) void {
    // self.allocator.free(self.config);
}

//  RequestInterface $request, $expires = '+30 minutes'
fn createAuthorization(self: *Self, url: []const u8) !void {
    var sign_time = std.time.timestamp();
    if (self.config.expire == null) {
        sign_time += 30 * 60;
    } else {
        sign_time += self.config.expire.?;
    }

    const queries = try std.Uri.parse(url);
    if (queries.query) |query| {
        const iter = std.mem.split(u8, query.raw, "&");
        while (iter.next()) |item| {
            if (std.mem.indexOf(u8, item, u8)) |index| {
                std.log.debug("key = {s}, value = {s}", .{ item[0..index], item[index + 1 ..] });
            }
        }
    }

    // $urlParamListArray = [];
    // foreach ( explode( '&', $request->getUri()->getQuery() ) as $query ) {
    //     if (!empty($query)) {
    //         $tmpquery = explode( '=', $query );
    //         //为了保证CI的key中有=号的情况也能正常通过，ci在这层之前已经encode了，这里需要拆开重新encode，防止上方explode拆错
    //         $key = strtolower( rawurlencode(urldecode($tmpquery[0])) );
    //         if (count($tmpquery) >= 2) {
    //             $value = $tmpquery[1];
    //         } else {
    //             $value = "";
    //         }
    //         //host开关
    //         if (!$this->options['signHost'] && $key == 'host') {
    //             continue;
    //         }
    //         $urlParamListArray[$key] = $key. '='. $value;
    //     }
    // }
    // ksort($urlParamListArray);
    // $urlParamList = join(';', array_keys($urlParamListArray));
    // $httpParameters = join('&', array_values($urlParamListArray));

    // $headerListArray = [];
    // foreach ( $request->getHeaders() as $key => $value ) {
    //     $key = strtolower( urlencode( $key ) );
    //     $value = rawurlencode( $value[0] );
    //     if ( !$this->options['signHost'] && $key == 'host' ) {
    //         continue;
    //     }
    //     if ( $this->needCheckHeader( $key ) ) {
    //         $headerListArray[$key] = $key. '='. $value;
    //     }
    // }
    // ksort($headerListArray);
    // $headerList = join(';', array_keys($headerListArray));
    // $httpHeaders = join('&', array_values($headerListArray));
    // $httpString = strtolower( $request->getMethod() ) . "\n" . urldecode( $request->getUri()->getPath() ) . "\n" . $httpParameters.
    // "\n". $httpHeaders. "\n";
    // $sha1edHttpString = sha1( $httpString );
    // $stringToSign = "sha1\n$signTime\n$sha1edHttpString\n";
    // $signKey = hash_hmac( 'sha1', $signTime, trim($this->secretKey) );
    // $signature = hash_hmac( 'sha1', $stringToSign, $signKey );
    // $authorization = 'q-sign-algorithm=sha1&q-ak='. trim($this->accessKey) .
    // "&q-sign-time=$signTime&q-key-time=$signTime&q-header-list=$headerList&q-url-param-list=$urlParamList&" .
    // "q-signature=$signature";
    return;
}
