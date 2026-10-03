// ============================================================================
// bgpeer 覆写脚本，版本3.9 (Mihomo 系通用: Mihomo Party / ClashMi / Clash Verge Rev / FlClash)
// 用法: 在客户端"覆写"处粘贴链接导入,或复制导入，或做文件名称__复写.js 导入
//       ClashMi把链接添加到➜核心设置➜复写➜右上➕里面去，类型选js，然后选择这个复写。
// 入口约定: 客户端会调用 main(config), config 为订阅解析后的对象, 返回修改后的 config。

// ----------------------------- 可调参数 -----------------------------
const ICON = "https://gh-proxy.com/https://raw.githubusercontent.com/bgpeer/icons/main/color/";
const RULES = "https://gh-proxy.com/https://raw.githubusercontent.com/bgpeer/rules/main/";
const threshold = 2;        // 某国节点数 < 该值则不生成该组 (1=有就生成, 2=至少2个才显示)
const fixUSFlag = true;     // 🇺🇲(U+1F1FA U+1F1F2) -> 🇺🇸(U+1F1FA U+1F1F8)
const setDNS = true;        // DNS开关, 由本脚本提供
const setSniffer = true;    // 嗅探开关, 由本脚本提供
const setTun = true;        // tun开关, 由本脚本提供 (没 tun 抓不到流量=没网)
const setPanel = "local";   // 浏览器面板开关: false=关闭 | "local"=半开(仅本机127.0.0.1,默认) | "lan"=全开(0.0.0.0,局域网可连)
const PANEL_SECRET = "88888888"; // 面板密码: 可自行修改 | "random"=随机密码 | 端口：9092，一般会被软件覆盖端口=9090
const otherGroup = true;         // 把未归入任何国家组的节点收进「🎲其他随机」(仅在确有漏网节点时生成)
const FETCH_VIA = "fallback";    // 规则集下载通道: ""=DIRECT直连; "fallback"=DIRECT优先,连不上自动切代理; "Dick Service"=强制走代理。path 缓存始终保留
const setClientOpts = true; // 入站端口/局域网/认证等客户端私有项。移动端若与 FlClash/ClashMi 自身设置冲突(典型: GUI连不上内核)就设 false
const TUN_STACK = "mixed";  // TUN栈: mixed=均衡(默认,手机推荐) | system=最快但挑环境 | gvisor=最稳最兼容(UDP不通时用)
const SMUX_FILL = true;     // 给 ss/vmess/vless/trojan(非Vision、未自带)补 smux h2mux。注意: 服务端没开mux会连不上, 节点连不上就设 false
const ADBLOCK = true;       // 广告规则集是否加载开关，true=加载，false=不加载，Clashmi在iOS端内存吃紧时设 false 就会少加载18万行规则
const CHAIN = true;        // 🔗链式代理开关: true=显示🔗链式策略 | false=隐藏🔗链式策略
// 协议白名单(将来有新协议要纳入, 只需在这里加协议名; 不在名单的一律不碰, 保持订阅原样)
const FP_OK   = ["vless", "vmess", "trojan"];        // 吃 uTLS 指纹(client-fingerprint)的协议
const SMUX_OK = ["ss", "vmess", "vless", "trojan"];  // 支持 smux 多路复用的协议

// 机场订阅 (proxy-providers)。节点由订阅或机场提供, 经各组 include-all 自动并入, 无需改组。
const useProviders = true;           // 常开稳定: 没填/占位的槽位自动跳过, 且与软件已有 provider 合并
const PROVIDER_URLS = {              // 机场名: 链接。前缀 ¹²³… 按顺序自动加, 加多少个都行; 保留两边引号
  "机场1": "#机场订阅",   // 添加更多机场链接，此处链接节点不会被收集到动态国家随机分组，原因：有软件壁垒
  "机场2": "#机场订阅",
  "机场3": "#机场订阅",
};
const PROVIDER_PROXY = "📥订阅下载"; // 拉机场订阅的通道: 默认 DIRECT优先, 直连不通自动切Dick Service。也可直接填 "DIRECT" 或 "Dick Service"

// 单节点分享链接添加(非机场订阅链接)，支持: vless:// vmess:// ss:// trojan:// hysteria2://(hy2://) tuic:// anytls:// socks://(socks5://) http://(https://)
// 想进某国家组, 名称里要带旗子/关键词(自定义名写 🇺🇸 或保留链接原本的 #🇺🇸xxx); 不带的进 🎲其他随机。
const useLinks = true;     // 关掉就完全不解析; LINKS 为空时本就是空操作
const LINK_TAG = "📌";     // 单链接节点名前缀, 用来和机场订阅的 ¹²³ 区分。效果: 📌¹洛杉矶。想换成 🏷️/📎/⚡ 等随意; 留空 "" 则只剩序号
const LINKS = [
  // 用法: 去掉行首 // 换成你的真链接即可。三种写法(可混用):括号引号和后面的逗号不可删除
  // ["🇺🇸洛杉矶家宽", "vless://....."],   // 自定义名 + 链接
  // "http://user:pass@5.6.7.8:8080#🇯🇵东京HTTP家宽",         // 只填链接(用链接自带 #备注)
  // "hysteria2://....",               // 只填链接(无备注 → 用协议名)
];

// 自建节点 YAML写法(proxies 口子): 直接粘订阅/客户端里 proxies: 下那种 YAML 节点(单行 flow 写法, 行首 "- " 可有可无)。
// 同样加 PROXY_TAG 前缀; 留空就是空操作。注: 仅支持单行 {k: v,...} flow 式, 不支持缩进多行块式。
// 下面带#号是单行yaml写法样本可供参考，自己写的时候要把前面的#和例子都删掉，也可以直接把机场的复制粘贴进来
const useProxies = true;   // 关掉就完全不并入; PROXIES_YAML 为空时本就是空操作
const PROXY_TAG = "🏠";    // 自建节点名前缀, 区分自建与机场(¹²³)/链接(📌)。效果: 🏠洛杉矶自建。可改 🛠️/⭐/🏡 等; 留空 "" 则用原名。不带上标序号
const PROXIES_YAML = `
# - {name: "🇺🇸 VLESS_TCP/TLS_Vision", type: vless, server: a.com, port: 443, uuid: your-uuid, udp: true, tls: true, network: tcp, client-fingerprint: chrome, flow: xtls-rprx-vision, servername: a.com, skip-cert-verify: false}
# - {name: "🇺🇸美国SOCKS5", type: socks5, server: 1.2.3.4, port: 1080, username: user, password: pass, udp: true}
# - {name: "🇯🇵日本HTTP", type: http, server: 5.6.7.8, port: 8080, username: user, password: pass, tls: false}
`;

// 国家组: [组名, 匹配正则]。顺序即面板展示顺序; 只输出命中的。美国旗一律 🇺🇸。
// ["🏠自建美国随机", /^🏠.*(🇺🇸|美国|洛杉矶|自建)/],也可以像这样锚定前缀写法来识别自建
// 英文短代码一律带 \b 词边界: 防 US 误吸 RUSSIA、TH 误吸 SOUTH、AR 误吸 WARP/STAR、CA 误吸 AFRICA 之类
const autoCountry = true;        // 动态国家组总开关: true=扫描节点自动创建(受 threshold 约束) | false=整段不扫不建(下面 CUSTOM_RANDOM 自定义组不受此开关影响, 恒生成)
const COUNTRY = [
  ["🇭🇰香港随机",   /🇭🇰|\bHK\b|Hong|hong|香港|深港|沪港|京港/],
  ["🇹🇼台湾随机",   /🇹🇼|\bTW\b|\bTWN\b|Taiwan|Taipei|台湾|台灣|台北/],
  ["🇯🇵日本随机",   /🇯🇵|\bJP\b|Japan|japan|Tokyo|东京|大阪|日本/],
  ["🇸🇬新加坡随机", /🇸🇬|\bSG\b|Singapore|singapore|新加坡|狮城/],
  ["🇰🇷韩国随机",   /🇰🇷|\bKR\b|Korea|korea|韩国|首尔/],
  ["🇺🇸美国随机",   /🇺🇸|\bUS\b|\bUSA\b|America|美国|洛杉矶|纽约|西雅图|圣何塞|硅谷/],
  ["🇬🇧英国随机",   /🇬🇧|\bUK\b|\bGB\b|England|Britain|London|英国|伦敦/],
  ["🇩🇪德国随机",   /🇩🇪|\bDE\b|Germany|German|Frankfurt|德国|法兰克福/],
  ["🇳🇱荷兰随机",   /🇳🇱|\bNL\b|Netherlands|Holland|Amsterdam|荷兰|阿姆斯特丹/],
  ["🇫🇷法国随机",   /🇫🇷|\bFR\b|France|Paris|法国|巴黎/],
  ["🇨🇦加拿大随机",  /🇨🇦|\bCA\b|Canada|加拿大|多伦多/],
  ["🇦🇺澳洲随机",    /🇦🇺|\bAU\b|Australia|Sydney|澳大利亚|悉尼/],
  ["🇷🇺俄罗斯随机",  /🇷🇺|\bRU\b|Russia|Moscow|俄罗斯|莫斯科/],
  ["🇮🇳印度随机",    /🇮🇳|India|india|Mumbai|Bombay|Delhi|Bangalore|Bengaluru|Chennai|印度|孟买|新德里|班加罗尔/],
  ["🇻🇳越南随机",    /🇻🇳|Vietnam|vietnam|Hanoi|Saigon|越南|河内|胡志明|西贡/],
  ["🇲🇾马来西亚随机", /🇲🇾|Malaysia|malaysia|KualaLumpur|Kuala|马来|吉隆坡/],
  ["🇹🇭泰国随机",    /🇹🇭|\bTH\b|Thailand|thailand|Bangkok|泰国|曼谷/],
  ["🇮🇩印尼随机",    /🇮🇩|Indonesia|indonesia|Jakarta|印尼|印度尼西亚|雅加达/],
  ["🇵🇭菲律宾随机",  /🇵🇭|\bPH\b|Philippines|philippines|Manila|菲律宾|马尼拉/],
  ["🇹🇷土耳其随机",  /🇹🇷|Turkey|turkey|Türkiye|Istanbul|土耳其|伊斯坦布尔/],
  ["🇦🇪阿联酋随机",  /🇦🇪|\bUAE\b|Emirates|Dubai|阿联酋|迪拜|阿布扎比/],
  ["🇧🇷巴西随机",    /🇧🇷|\bBR\b|Brazil|brazil|Brasil|SaoPaulo|巴西|圣保罗/],
  ["🇦🇷阿根廷随机",  /🇦🇷|\bAR\b|Argentina|argentina|阿根廷|布宜诺斯艾利斯/],
];

// 自定义显式国家随机分组 (脚本里的机场订阅可在这里国家随机分组扫到)，自己写的时候删掉前面两个斜杠和样品
const CUSTOM_RANDOM = [
  // ["🇺🇸美国随机", /\bUS\b|\bUSA\b|🇺🇸|美国|洛杉矶/],   // 占名示例: 上面动态的 🇺🇸美国随机 让位不再生成
  // ["🇰🇷韩国随机", /\bKR\b|🇰🇷|韩国|首尔/],
  // ["🏠家宽随机",   /家宽|住宅|ISP/],                    // 不占名示例: 纯新增组, 与动态组并存
];

// 规则集锚点。FETCH_VIA 决定下载通道(见上); path: 下成功后本地缓存, 之后冷启动直接读缓存
const FETCH_GROUP = "📥规则下载";   // FETCH_VIA="fallback" 时, 规则集走这个"DIRECT优先回落"组下载
const P = (u) => {
  const o = {};
  if (FETCH_VIA === "fallback") o.proxy = FETCH_GROUP;
  else if (FETCH_VIA) o.proxy = FETCH_VIA;
  o.path = "./bgpeer/" + u.replace(/[\/!]/g, "_");
  return o;
};
const D = (u) => Object.assign({ type: "http", behavior: "domain",    interval: 86400, format: "mrs",  url: RULES + u }, P(u));
const I = (u) => Object.assign({ type: "http", behavior: "ipcidr",    interval: 86400, format: "mrs",  url: RULES + u }, P(u));
const C = (u) => Object.assign({ type: "http", behavior: "classical", interval: 86400, format: "yaml", url: RULES + u }, P(u));

const CN_DNS = ["https://dns.alidns.com/dns-query", "https://doh.pub/dns-query"];
const G_DNS  = ["https://1.1.1.1/dns-query", "https://dns.google/dns-query", "https://dns.quad9.net/dns-query", "tls://cloudflare-dns.com:853", "tls://dns.google:853"];
// 主表: [规则集名, 类型, 文件基名, 目标组, no-resolve?, DNS归属?] —— providers / rules / DNS分流 全从这里生成
//   类型: d=域名mrs/geosite  c=域名yaml/geosite  i=IP mrs/geoip
//   no-resolve: IP规则(i)填1, 其余填0或直接省略;  DNS归属: g=走国外DNS, z=走国内DNS, 不写=默认DNS (位置无关)
const META = { d: ["geosite", "domain", "mrs"], c: ["geosite", "classical", "yaml"], i: ["geoip", "ipcidr", "mrs"] };
const T = [
  ["reject", "d", "category-ads-all", "REJECT"],
  ["TikTok-zj", "c", "tiktok", "🎬TikTok", 0, "g"],
  ["OpenAI-zj", "c", "openai", "🧠OpenAI", 0, "g"],
  ["Claude-zj", "c", "anthropic", "🤖Claude", 0, "g"],
  ["PayPal", "d", "paypal", "💳PayPal", 0, "g"],
  ["Cryptocurrency", "d", "category-cryptocurrency", "💰加密货币", 0, "z"],
  ["games-!cn", "c", "category-games-!cn", "🎮国际游戏", 0, "g"],
  ["Telegram-zj", "c", "telegram", "💻Telegram", 0, "g"],
  ["Netflix", "c", "netflix", "📽️Netflix", 0, "g"],
  ["Spotify", "d", "spotify", "🎵Spotify", 0, "g"],
  ["Google-zj", "c", "google", "🌐Google服务", 0, "g"],
  ["google-ip", "i", "google", "🌐Google服务", 1],
  ["Facebook-zj", "d", "meta", "📱Meta", 0, "g"],
  ["GitHub-zj", "d", "github", "😈GitHub", 0, "g"],
  ["Microsoft", "d", "microsoft", "😊微软服务", 0, "g"],
  ["icloud", "d", "icloud", "🍎苹果服务", 0, "g"],
  ["Apple", "d", "apple", "🍎苹果服务", 0, "g"],
  ["twitter", "d", "twitter", "🐦X", 0, "g"],
  ["cloudflare-ip", "i", "cloudflare", "Dick Service", 1],
  ["cloudfront-ip", "i", "cloudfront", "Dick Service", 1],
  ["fastly-ip", "i", "fastly", "Dick Service", 1],
  ["greatfire", "d", "greatfire", "Dick Service", 0, "g"],
  ["gfw", "d", "gfw", "Dick Service", 0, "g"],
  ["geolocation-!cn", "d", "geolocation-!cn", "Dick Service", 0, "g"],
  ["games-cn", "d", "category-games-cn", "🎯直连", 0, "z"],
  ["bilibili", "d", "bilibili", "📺哔哩哔哩", 0, "z"],
  ["xiaohongshu", "d", "xiaohongshu", "📕小红书", 0, "z"],
  ["Alibaba", "c", "alibaba", "⛩️阿里腾讯", 0, "z"],
  ["Tencent", "c", "tencent", "⛩️阿里腾讯", 0, "z"],
  ["private", "d", "private", "🎯直连", 0, "z"],
  ["cn-domain", "d", "cn", "🎯直连", 0, "z"],
  ["private-ip", "i", "private", "🎯直连", 1],
  ["cn-ip", "i", "cn", "🎯直连", 1],
];
// 尾部可选项解析(位置无关): 值===1 -> no-resolve; 值==="g"/"z" -> DNS归属; 其余(0/""/省略)忽略=默认DNS
// T 表从第5位(idx4)起扫, CUSTOM 从第4位(idx3)起扫。故 no-resolve 与 g/z 都可省略, 不报错。
function tailOpts(arr, from) {
  let nr = false, dns = "";
  for (let i = from; i < arr.length; i++) {
    const v = arr[i];
    if (v === "g" || v === "z") dns = v;
    else if (v === 1 || v === true) nr = true;
  }
  return { nr: nr, dns: dns };
}
// G_SETS / CN_SETS 从 T 的 DNS归属自动分出 (位置无关, 见 tailOpts; 增减只在 T 行尾改 g/z)
const G_SETS  = T.filter(r => tailOpts(r, 4).dns === "g").map(r => r[0]);
const CN_SETS = T.filter(r => tailOpts(r, 4).dns === "z").map(r => r[0]);

// 服务组表: [组名, 图标, 默认直连?]  —— 图标可省略; 默认直连填1(🎯直连开头), 省略=Dick Service开头
//   四种写法: ["组名","图标.png"] / ["组名","图标.png",1] / ["组名"](无图标) / ["组名",1](无图标,直连)
//   规则: 第2位是字符串=图标; 是数字=直连标志(此时无图标)。图标想换/想给无图标组配图 -> 用下面 ICONS 口子
const SVC = [
  ["🎬TikTok", "tiktok_1.png"], ["🎮国际游戏", "game_2.png"],
  ["💻Telegram", "telegram.png"], ["🧠OpenAI", "chatgpt.png"], ["🤖Claude", "claude_1.png"],
  ["💳PayPal", "paypal_1.png"], ["🌐Google服务", "google_1.png"], ["📱Meta", "meta.png"],
  ["🐦X", "x.png"], ["📽️Netflix", "netflix.png"], ["🎵Spotify", "spotify.png", 1], ["😈GitHub", "github.png"],
  ["😊微软服务", "microsoft.png", 1], ["🍎苹果服务", "apple.png", 1], ["💰加密货币", "cryptocurrency.png", 1],
  ["📺哔哩哔哩", "bilibili_2.png", 1], ["📕小红书", "xiaohongshu_1.png", 1],
];

// 可以在上面SVC组创建一个策略组例如["🎬Emby"],然后自定义图标 (优先级高于 SVC 及默认图标; 给任意组换图标) 
// [组名, 图标完整URL]。组名匹配到则覆盖其图标; 这里填的是完整链接(不走 ICON 前缀, 想用啥源都行)。
// 此组只可以自定义图标没有其他功能; 组若本就没图标也不会凭空报错。留空 [] = no-op。
const ICONS = [
  ["🎵Spotify", "https://fastly.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Spotify.png"],
  // ["🎬Emby",       "https://gh.669588.xyz/bgpeer/icons/main/color/emby.png"],
  // ["🌐Google服务", "https://example.com/my-google.png"],   // 覆盖 SVC 里给的图标
];

// 自定义添加单条分流规则: [规则类型, 值, 目标组,]  —— 表内顺序=匹配优先级(谁在前谁先命中)，不可SET规则集
const CUSTOM = [
  // ["DOMAIN-SUFFIX",  "emby.某机场域名.com", "🎬Emby", 0, "g"],   // 机场 Emby 域名, 走国外DNS
  // ["DOMAIN-SUFFIX",  "example.com",        "Dick Service", "g"],     // 省 no-resolve, 只给 DNS 归属
  // ["DOMAIN-KEYWORD", "emby",               "🎬Emby"],             // 啥都不写=默认DNS(关键词本就不做DNS分流)
];

function main(config) {
  // 空 config / 没传 config 兜底: 即使客户端给空壳(proxies: [])甚至什么都不给, 也能输出完整配置。
  // 注: 这只保证 js 自身不崩; 客户端是否允许"无订阅启动"由客户端决定, 多数仍需一个空壳订阅当载体。
  if (!config || typeof config !== "object") config = {};
  if (!Array.isArray(config.proxies)) config.proxies = [];
  const proxies = config.proxies;
  // 合并而非覆盖: 保留软件 yaml 里已有的 proxy-providers; 机场节点经 include-all 自动并入各组
  if (useProviders) config["proxy-providers"] = Object.assign({}, config["proxy-providers"], buildProviders());

  // 单节点分享链接 -> 解析成节点对象并入 proxies (去重: 同名自动加后缀, 不丢节点)。单条解析失败只跳过该条。
  if (useLinks) {
    const added = parseLinks(LINKS);
    const seen = {};
    for (const p of proxies) if (p && p.name) seen[p.name] = 1;
    for (const p of added) {
      let nm = p.name || p.server, base = nm, k = 2;
      while (seen[nm]) nm = base + " " + (k++);
      p.name = nm; seen[nm] = 1;
      proxies.push(p);
    }
  }

  // 自建节点 -> 直接并入 proxies (加 PROXY_TAG 前缀, 不加上标; 去重同上)。来源: PROXIES_YAML(YAML文本)。缺 server 跳过。
  if (useProxies) {
    const seen = {};
    for (const p of proxies) if (p && p.name) seen[p.name] = 1;
    const selfNodes = parseYamlProxies(PROXIES_YAML);
    for (const raw of selfNodes) {
      if (!raw || typeof raw !== "object" || !raw.server) continue;   // 没 server 的当占位/写错 -> 跳过, 不丢其他
      const p = Object.assign({}, raw);                               // 拷贝, 不改动源对象
      const base = (p.name == null ? "" : String(p.name)).trim() || String(p.server);
      let nm = PROXY_TAG + base, root = nm, k = 2;
      while (seen[nm]) nm = root + " " + (k++);
      p.name = nm; seen[nm] = 1;
      proxies.push(p);
    }
  }

  // 1) 美国旗规范
  if (fixUSFlag) {
    for (const p of proxies) {
      if (p && p.name) p.name = p.name.replace(/\u{1F1FA}\u{1F1F2}/gu, "\u{1F1FA}\u{1F1F8}");
    }
  }

  // 1.5) 节点名 YAML 安全化前移(原在 makeYamlSafe 里最后才做): 让国家检测/漏网检测/运行期 filter
  //      全部作用于同一份"最终名字", 消除 ^锚定 等写法的编译期/运行期分裂
  for (const p of proxies) if (p && p.name) p.name = safeName(p.name);

  // 2) 自定义随机分组: 无视 threshold/autoCountry 强制生成(显示卡片)。坏行(缺名/坏正则)跳过, 不影响其他行
  const custom = [];
  for (const c of (CUSTOM_RANDOM || [])) {
    if (!c || !c[0] || !c[1]) continue;
    let re = c[1];
    if (!re.source) { try { re = new RegExp(String(re)); } catch (e) { continue; } }   // 兼容手滑写成字符串
    custom.push([c[0], re]);
  }
  const customNames = custom.map(function (c) { return c[0]; });

  // 2.1) 动态检测国家 (autoCountry=false 时整段不扫不建): 节点数 >= threshold; 已被自定义占名的让位, 不重复建
  const present = !autoCountry ? [] : COUNTRY.filter(function (c) {
    if (customNames.indexOf(c[0]) !== -1) return false;      // 同名压制: 自定义优先
    let n = 0;
    for (const p of proxies) if (p && p.name && c[1].test(p.name)) n++;
    return n >= threshold;
  });
  const countryNames = customNames.concat(present.map(function (c) { return c[0]; }));

  // 2.5) 检测是否有"未归入任何组"的漏网节点 (归属判定 = 自定义组 + 启用中的动态表; autoCountry 关了动态表不算)
  const ALL_PAT = custom.map(function (c) { return c[1].source; })
    .concat(autoCountry ? COUNTRY.map(function (c) { return c[1].source; }) : [])
    .join("|");
  const ALL_RE = ALL_PAT ? new RegExp(ALL_PAT) : null;       // 两表皆空 -> 无归属正则, 所有节点都算漏网
  let hasOther = false;
  for (const p of proxies) { if (p && p.name && (!ALL_RE || !ALL_RE.test(p.name))) { hasOther = true; break; } }
  const useOther = otherGroup && hasOther;
  const OTHER = "🎲其他随机";
  const tail = countryNames.concat(useOther ? [OTHER] : []);  // 国家组 + (可选)其他随机

  // 3) 公共片段
  const URLTEST = {
    type: "url-test", lazy: true, icon: ICON + "bypass.png",
    "include-all": true, "exclude-type": "direct",
    url: "https://www.gstatic.com/generate_204", interval: 120, tolerance: 30, timeout: 5000, hidden: true,
  };
  const AUTO = { "include-all": true, "exclude-type": "direct", filter: ".*" };

  // 4) 三处列表 (随国家动态变化)
  const ACCEL   = ["♻️全部随机", "🔗链式出口"].concat(tail);
  const GLOBAL  = ["Dick Service", "🔗链式出口", "♻️全部随机"].concat(tail, ["🎯直连"]);
  const GLOBAL_D = ["🎯直连", "Dick Service", "🔗链式出口", "♻️全部随机"].concat(tail);

  // 5) select 服务组辅助
  const sel = function (name, icon, list) {
    if (icon == null) return Object.assign({ name: name, type: "select", proxies: list }, AUTO);
    return Object.assign({ name: name, type: "select", icon: ICON + icon, proxies: list }, AUTO);
  };

  // 6) 自定义随机组(显示卡片)在前 + 动态国家组(只含命中的)在后 + (可选)其他随机 + 全部随机兜底
  const countryGroups = custom.map(function (c) {
    return Object.assign({}, URLTEST, { name: c[0], filter: safeFilter(c[1].source) });
  }).concat(present.map(function (c) {
    return Object.assign({}, URLTEST, { name: c[0], filter: safeFilter(c[1].source) });
  }));
  if (useOther) {
    // include-all 收全部, 再用 exclude-filter 排除所有已归类关键字 = 只剩没归类的; 无任何归类正则时=直接收全部
    const og = Object.assign({}, URLTEST, { name: OTHER });
    if (ALL_PAT) og["exclude-filter"] = safeFilter(ALL_PAT);
    countryGroups.push(og);
  }
  countryGroups.push(Object.assign({}, URLTEST, { name: "♻️全部随机", filter: ".*" }));

  // 7) 组装 proxy-groups
  config["proxy-groups"] = [
    Object.assign({ name: "Dick Service", type: "select", icon: ICON + "global.png", proxies: ACCEL },
                  AUTO, { url: "https://www.gstatic.com/generate_204", interval: 120, timeout: 5000 }),
    ...SVC.map(function (s) {
      const hasIcon = typeof s[1] === "string";   // 第2位: 字符串=图标; 数字=直连标志(此时无图标)
      return sel(s[0], hasIcon ? s[1] : null, (hasIcon ? s[2] : s[1]) ? GLOBAL_D : GLOBAL);
    }),
    { name: "⛩️阿里腾讯", type: "select", icon: ICON + "alibaba_tencent.png", proxies: ["🎯直连", "Dick Service"] },
    { name: "🎯直连",   type: "select", icon: ICON + "china.png", proxies: ["DIRECT", "Dick Service"], url: "http://connect.rom.miui.com/generate_204" },
    { name: "🤡漏网之鱼", type: "select", icon: ICON + "match_1.png", proxies: ["Dick Service", "🎯直连"] },
    // ── 链式 出口/中转 (可见卡片, 放漏网之鱼后面; 直接点卡片进组选节点) ──
    // 出口(落地): override.dialer-proxy 给 include-all 单节点注入前置=中转; 选"单节点"才成链, 不含Dick Service(否则成环)
    Object.assign({ name: "🔗链式出口", type: "select", icon: ICON + "chainexport.png",
      override: { "dialer-proxy": "🔗链式中转" },
      proxies: ["♻️全部随机"].concat(tail) }, AUTO),
    // 中转(前置跳板): Dick Service + 国家动态组 + ♻️全部随机 + 单节点
    Object.assign({ name: "🔗链式中转", type: "select", icon: ICON + "chaintransfer.png",
      proxies: ["Dick Service", "♻️全部随机"].concat(tail) }, AUTO),
  ].concat(
    // FETCH_VIA="fallback": 规则集下载走 DIRECT优先, 健康检查指向真实下载源(gh-proxy),
    // 直连连得上就用直连, 连不上才自动切到 Dick Service。冷启动默认用列表第一个(DIRECT)。
    FETCH_VIA === "fallback" ? [{
      name: FETCH_GROUP, type: "fallback", icon: ICON + "bypass.png",
      proxies: ["DIRECT", "Dick Service"],
      url: RULES + "geo/geoip/private.mrs",
      interval: 300, lazy: false, hidden: true,
    }] : []
  ).concat(
    // 📥订阅下载: 机场订阅下载通道。DIRECT优先(健康检查直连能过就用直连), 不通自动切Dick Service。
    // 也解决纯机场冷启动: 首启组里还没节点时, 先用 DIRECT 拉订阅把节点引导起来。
    (useProviders && PROVIDER_PROXY === "📥订阅下载") ? [{
      name: "📥订阅下载", type: "fallback", icon: ICON + "bypass.png",
      proxies: ["DIRECT", "Dick Service"],
      url: "https://www.gstatic.com/generate_204",
      interval: 300, lazy: false, hidden: true,
    }] : []
  ).concat(countryGroups);

  // 8.5) 自定义内置 GLOBAL 组。
  const orderedGroups = config["proxy-groups"].filter(g => !g.hidden && g.name !== "GLOBAL").map(g => g.name);
  config["proxy-groups"].push({
    name: "GLOBAL",
    type: "select",
    icon: ICON + "match.png",
    "include-all": true,                          
    proxies: [...new Set(orderedGroups.concat(ACCEL, ["DIRECT"]))],  // 去重: 🔗链式出口在orderedGroups和ACCEL里各一次
  });

  // 8.55) 链式开关: CHAIN=false 时删除 🔗链式出口/🔗链式中转 两组, 并清掉其它组(含 GLOBAL)对它们的引用
  //       所有组建完后统一处理, 一次搞定; 引用被删后若某组 proxies 空了, 用 DIRECT 兜底防止内核报错。
  if (!CHAIN) {
    const CHAIN_GROUPS = ["🔗链式出口", "🔗链式中转"];
    config["proxy-groups"] = config["proxy-groups"].filter(g => !CHAIN_GROUPS.includes(g.name));
    for (const g of config["proxy-groups"]) {
      if (Array.isArray(g.proxies)) {
        g.proxies = g.proxies.filter(p => !CHAIN_GROUPS.includes(p));
        if (!g.proxies.length) g.proxies = ["DIRECT"];
      }
    }
  }

  // 8.6) 图标覆盖: 优先级高于 SVC 及默认图标。所有组建好后统一覆盖, ICONS 里有同名组则换图(完整URL)。
  //      没写 URL / 占位(#) / 空表 -> 跳过, 不动任何组(也不报错)。
  const ICON_MAP = {};
  for (const it of (ICONS || [])) {
    if (!it || !it[0] || !it[1] || String(it[1]).charAt(0) === "#") continue;
    ICON_MAP[it[0]] = it[1];
  }
  for (const g of config["proxy-groups"]) {
    if (g && g.name && ICON_MAP[g.name]) g.icon = ICON_MAP[g.name];
  }

  // 8+9) rule-providers 与 rules 由主表 T 一次生成
  //      provider 是 map (顺序无所谓); rules 是数组 (顺序=T 的顺序, 即匹配优先级)
  config["rule-providers"] = {};
  config.rules = [];
  // 自定义内联规则: 按表内顺序, 整批排在所有 RULE-SET 之前 = 最高优先级。no-resolve 由 tailOpts 识别(位置无关)
  for (const c of CUSTOM) config.rules.push(c[0] + "," + c[1] + "," + c[2] + (tailOpts(c, 3).nr ? ",no-resolve" : ""));
  for (const r of T) {
    const [name, t, file, group] = r;
    if (!ADBLOCK && name === "reject") continue;   // 关广告: provider 与规则一起跳过
    const [dir, behavior, ext] = META[t];          // d/c/i -> [目录, behavior, 扩展名(也是format)]
    const u = "geo/" + dir + "/" + file + "." + ext;
    config["rule-providers"][name] = Object.assign(
      { type: "http", behavior: behavior, format: ext, interval: 86400, url: RULES + u }, P(u)
    );
    config.rules.push("RULE-SET," + name + "," + group + (tailOpts(r, 4).nr ? ",no-resolve" : ""));
  }
  config.rules.push("MATCH,🤡漏网之鱼");

  // 10) DNS (可选)
  if (setDNS) {
    // 由 G_SETS/CN_SETS 自动生成 nameserver-policy (增减只改顶部那两个数组)
    const nsPolicy = ADBLOCK ? { "rule-set:reject": ["https://dns.adguard.com/dns-query"] } : {};
    for (const s of G_SETS)  nsPolicy["rule-set:" + s] = G_DNS;
    for (const s of CN_SETS) nsPolicy["rule-set:" + s] = CN_DNS;
    // 追加: CUSTOM 内联域名的 DNS 归属。仅 DOMAIN(精确) / DOMAIN-SUFFIX(+.) 可转 policy key;
    //       关键词/正则/IP 无法按域名做 DNS 分流 -> 跳过(规则本身照常生效, 只是不进 DNS 分流)
    for (const c of CUSTOM) {
      const dns = tailOpts(c, 3).dns;
      if (dns !== "g" && dns !== "z") continue;
      let key = null;
      if (c[0] === "DOMAIN") key = c[1];
      else if (c[0] === "DOMAIN-SUFFIX") key = "+." + c[1];
      else continue;
      nsPolicy[key] = dns === "g" ? G_DNS : CN_DNS;
    }
    config.dns = {
      enable: true, listen: "0.0.0.0:1053", ipv6: true,
      "enhanced-mode": "fake-ip", "cache-algorithm": "arc",
      "fake-ip-range": "198.18.0.0/16", "prefer-h3": true,
      "use-hosts": true, "use-system-hosts": true, "respect-rules": true,
      "fake-ip-filter-mode": "blacklist", "fake-ip-ttl": 60,
      "fake-ip-filter": ["localhost", "+.lan", "+.local", "+.arpa", "+.ntp.org", "captive.apple.com", "connectivitycheck.gstatic.com", "msftconnecttest.com", "msftncsi.com", "openai.*", "+.openai.*", "report-v2.samsung.japps.cn", "rule-set:private"],
      "direct-nameserver": ["system"],
      "default-nameserver": ["223.5.5.5", "119.29.29.29", "114.114.114.114", "180.76.76.76"],
      nameserver: ["https://dns.alidns.com/dns-query", "https://1.1.1.1/dns-query", "https://doh.pub/dns-query", "https://dns.google/dns-query", "https://dns.quad9.net/dns-query", "https://dns.adguard.com/dns-query", "tls://cloudflare-dns.com:853", "tls://dns.google:853"],
      "proxy-server-nameserver": ["https://1.1.1.1/dns-query", "https://dns.google/dns-query", "https://cloudflare-dns.com/dns-query", "https://dns.quad9.net/dns-query", "https://dns.adguard.com/dns-query", "https://public.dns.iij.jp/dns-query", "tls://cloudflare-dns.com:853", "tls://dns.google:853"],
      "direct-nameserver-follow-policy": true,
      "nameserver-policy": nsPolicy,
    };
  }

  // 11) 域名嗅探 (可选)
  if (setSniffer) {
    config.sniffer = {
      enable: true, "force-dns-mapping": true, "parse-pure-ip": true, "override-destination": true,
      sniff: { HTTP: { ports: [80, "8080-8880"], "override-destination": true }, TLS: { ports: [443, 8443] }, QUIC: { ports: [443, 8443] } },
      "force-domain": ["+.cloudflare.net", "+.akamaized.net", "+.akamai.net", "+.fastly.net", "+.cloudfront.net", "+.googlevideo.com", "+.ytimg.com", "+.youtube.com", "+.netflix.com", "+.instagram.com", "+.tiktokcdn.com", "+.tiktokv.com", "+.telegram.org", "+.t.me", "+.tdesktop.com", "+.cdn-telegram.org", "+.telegram-cdn.org"],
      "skip-domain": ["localhost", "+.lan", "+.local", "+.arpa", "+.invalid", "+.test", "+.push.apple.com", "+.pvp.net", "+.riotgames.com", "+.openai.com", "+.oaistatic.com", "+.oaiusercontent.com", "+.chatgpt.com"],
      "skip-src-address": ["127.0.0.0/8", "::1/128"],
      "skip-dst-address": ["17.0.0.0/8", "149.154.160.0/20", "91.108.0.0/16"],
    };
  }

  // —— 顶层配置 (与 Clashmi-fx 一致; setClientOpts 见顶部参数区) ——
  Object.assign(config, {
    "mode": "rule",
    "find-process-mode": "always",
    "unified-delay": true,
    "tcp-concurrent": true,
    "ipv6": true,
    ...(setClientOpts ? {
      "port": 7896, "socks-port": 7891, "redir-port": 7892, "tproxy-port": 7894, "mixed-port": 7893,
      "log-level": "warning",
      "etag-support": true,
      "disable-keep-alive": false,
      "inbound-tfo": true,
      "inbound-mptcp": false,
      "allow-lan": true,
      "bind-address": "*",
      "keep-alive-idle": 300,
      "keep-alive-interval": 30,
      "authentication": ["meta:88888888"],
      "skip-auth-prefixes": ["127.0.0.1/8", "::1/128"],
      "lan-allowed-ips": ["0.0.0.0/0", "::/0"],
      "lan-disallowed-ips": [],
      "global-ua": "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
      "ntp": { "enable": true, "server": "time.apple.com", "port": 123, "interval": 30, "dialer-proxy": "", "write-to-system": false },
      "experimental": { "quic-go-disable-ecn": true },
    } : {}),
  });

  // —— 浏览器面板 (控制器 API) —— 三档: false=关 | "local"=仅本机(默认) | "lan"=局域网。与 setClientOpts 解耦
  // secret 由 PANEL_SECRET 决定; "random" 走 resolveSecret 按节点确定性派生(覆写脚本无持久存储,故同批节点恒定同值)
  let panel = setPanel === true ? "lan" : setPanel;            // 兼容老写法: 旧配置里的 setPanel=true 视作全开
  if (panel === "lan" && PANEL_SECRET === "") panel = "local"; // 全开必须有口令, 留空则自动降回本机, 杜绝无口令裸奔
  if (panel === "local" || panel === "lan") {
    const realSecret = resolveSecret(PANEL_SECRET, config.proxies);
    config["external-controller"] = (panel === "lan" ? "0.0.0.0" : "127.0.0.1") + ":9092";
    config["secret"] = realSecret;
    config["external-controller-cors"] = panel === "lan"
      ? { "allow-origins": ["*"], "allow-private-network": true }  // 全开: 允许站外/跨私网面板访问
      : { "allow-origins": ["*"] };                                // 本机: 无需私网放行
    config["external-ui"] = "./ui";
    config["external-ui-name"] = "zashboard";
    config["external-ui-url"] = "https://codeload.github.com/Zephyruso/zashboard/zip/refs/heads/gh-pages";
    // 全开 + random: 把派生口令显示成一个 display-only 假组, 开 App 在组列表一眼可见, 抄进外部浏览器登录即可
    // (自己填了固定串的不显示——你本就知道; local 档不暴露端口, 也无需显示)
    if (panel === "lan" && PANEL_SECRET === "random") {
      config["proxy-groups"].push({ name: "🔑面板口令:" + realSecret, type: "select", proxies: ["DIRECT"] });
    }
  }
  config.profile = Object.assign({ "store-selected": true, "store-fake-ip": true }, config.profile || {});

  // —— TUN (裸订阅必须有, 否则抓不到系统流量; 已补全到与 Clashmi-fx 一致; TUN_STACK 见顶部参数区) ——
  if (setTun) {
    const t = {
      enable: true,
      device: "mihomo",
      stack: TUN_STACK,
      mtu: 1500,
      "inet6-address": ["fdfe:dcba:9876::1/126"],
      "strict-route": true,
      "dns-hijack": ["any:53", "tcp://any:53"],
      "auto-route": true,
      "auto-detect-interface": true,
      "endpoint-independent-nat": true,
      "udp-timeout": 60,
      "disable-icmp-forwarding": true,
      "route-exclude-address-set": ["private-ip"],
      "route-exclude-cidr": ["192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12", "100.64.0.0/10", "fc00::/7", "fe80::/10"],
    };
    // auto-redirect / gso 只在 system/mixed 栈下有意义, gvisor 下加了可能报错, 故按栈区分
    if (TUN_STACK !== "gvisor") { t["auto-redirect"] = true; t["gso"] = true; t["gso-max-size"] = 65536; }
    config.tun = t;
  }

  // —— hosts (与 Clashmi-fx 一致) —— 值都是 127.0.0.1, 只列域名
  config.hosts = Object.assign(
    ["*.backloop.dev", "*.localtest.me", "*.lvh.me", "*.vcap.me", "*.traefik.me", "*.readymade.dev"]
      .reduce((h, d) => (h[d] = "127.0.0.1", h), {}),
    config.hosts || {}
  );

  // —— tunnels (端口转发, 与 Clashmi-fx 一致) —— [本地端口, 目标, 走哪个组]; network 都是 tcp+udp
  const TUN = [
    [7788, "jp1.wildrift.riotgames.com:443", "🎮国际游戏"],
    [7789, "jp1.pvp.net:443", "🎮国际游戏"],
    [9000, "149.154.167.91:443", "💻Telegram"],
    [9001, "149.154.167.92:443", "💻Telegram"],
    [9002, "149.154.175.100:443", "💻Telegram"],
    [7999, "api.openai.com:443", "🧠OpenAI"],
    [7443, "chat.openai.com:443", "🧠OpenAI"],
    [7700, "www.google.com:443", "🌐Google服务"],
    [7701, "accounts.google.com:443", "🌐Google服务"],
    [7702, "www.googleapis.com:443", "🌐Google服务"],
  ];
  config.tunnels = TUN.map(([port, target, proxy]) => ({
    network: ["tcp", "udp"], address: "127.0.0.1:" + port, target, proxy,
  }));

  // —— 给"吃 uTLS 指纹"的节点补 client-fingerprint=chrome(替代已废弃的 global-client-fingerprint)——
  // 只处理走标准 TLS 的协议(FP_OK 白名单); QUIC系(hysteria/hysteria2/tuic)、wireguard、ssh、
  // 纯 ss/ssr、anytls 等不在名单内一律跳过(它们不吃 uTLS, 强加可能告警/握手失败)。已自带指纹的也不动。
  (config.proxies || []).forEach(function (p) {
    if (!p || FP_OK.indexOf(p.type) === -1) return;   // 协议不在白名单 -> 跳过
    if (p["client-fingerprint"]) return;              // 已自带(含 REALITY 自带) -> 不覆盖
    var usesTLS = p.type === "trojan" || p.tls === true || p["reality-opts"];
    if (usesTLS) p["client-fingerprint"] = "chrome";  // 仅确实走 TLS 时才补
  });
  // 注: 不再给 proxy-providers 统一加 override.client-fingerprint —— 那是"整份订阅强制套用",
  // 会把订阅里的 hy2/tuic 等也一起套, 反而可能出问题。订阅模式请在订阅/机场侧配置指纹。

  // —— 给支持 smux 的节点补 smux h2mux(SMUX_FILL 开关; 服务端没开 mux 会连不上 -> 关掉)——
  // 仅 SMUX_OK 白名单内的协议; 且排除 XTLS Vision(有 flow 字段, 叠 smux 会破坏 XTLS);
  // hy2/tuic/wireguard/ssh/anytls 不在名单 -> 不碰(QUIC/自带mux/不支持)。已自带 smux 的不覆盖。
  if (SMUX_FILL) {
    (config.proxies || []).forEach(function (p) {
      if (!p || SMUX_OK.indexOf(p.type) === -1) return;   // 协议不支持 -> 跳过
      if (p.smux) return;                    // 已自带 -> 不动
      if (p.flow) return;                    // XTLS Vision(flow非空) -> 绝不加
      p.smux = { enable: true, protocol: "h2mux", "max-connections": 4, "min-streams": 4, padding: true };
    });
  }

  // —— YAML 安全化: 无条件执行(都是功能等价改写) ——
  return makeYamlSafe(config);
}

// 把单个节点名改成 YAML 安全。只动会破坏裸标量的字符; 国家匹配正则不含这些字符, 匹配不受影响。
function safeName(name) {
  let s = String(name)
    .replace(/:/g, "：").replace(/,/g, "，")
    .replace(/\[/g, "【").replace(/\]/g, "】")
    .replace(/\{/g, "｛").replace(/\}/g, "｝");
  // 行首保留字符(* & ! | > @ % # ?)会被当成指示符 -> 替成全角; 行首引号/反引号直接去掉
  s = s.replace(/^\*/, "＊").replace(/^&/, "＆").replace(/^!/, "！")
       .replace(/^\|/, "｜").replace(/^>/, "＞").replace(/^@/, "＠")
       .replace(/^%/, "％").replace(/^#/, "＃").replace(/^\?/, "？")
       .replace(/^["'`]/, "");
  return s;
}

// 组 filter/exclude-filter 的正则源若以 YAML 指示符开头(如 [ { & ! > | * 等, 裸标量序列化后非法),
// 包一层 (?:...) 等价规避——(?: 以 "(" 开头, 天然 YAML 安全, 且不改变正则语义。emoji/普通字母开头原样返回。
function safeFilter(src) {
  return /^[\[\]{}>|*&!%@`"',#?:-]/.test(src) ? "(?:" + src + ")" : src;
}

// 数字 -> 上标 (1->¹, 10->¹⁰, 100->¹⁰⁰)。任意位数, 不设上限。
function sup(n) {
  const S = "⁰¹²³⁴⁵⁶⁷⁸⁹";  // ⁰¹²³⁴⁵⁶⁷⁸⁹
  return String(n).replace(/\d/g, function (d) { return S[+d]; });
}
// 解析 PANEL_SECRET: 非 "random" 直接返回原串; "random" 按节点名做 djb2 确定性派生。
// 覆写脚本无持久存储、每次重载重跑 main(), 无法"生成一次永久记住", 故用派生: 同批节点恒定同值, 换节点才变, 且每人不同。
// 注: 纯机场(proxies 为空)时 basis 回落 "bgpeer", 此时各用户派生值相同——介意可在 lan 档手填固定串代替 random。
function resolveSecret(raw, proxies) {
  if (raw !== "random") return raw;
  let h = 5381;
  const basis = (proxies || []).map(function (p) { return p && p.name; }).filter(Boolean).join("|") || "bgpeer";
  for (let i = 0; i < basis.length; i++) h = ((h << 5) + h + basis.charCodeAt(i)) >>> 0;
  return "p" + h.toString(36);
}
// 生成 proxy-providers: 展开原锚点 *p, 按顺序自动加上标前缀。节点靠各组 include-all 自动收入。
function buildProviders() {
  const out = {}, names = Object.keys(PROVIDER_URLS);
  for (let i = 0; i < names.length; i++) {
    const url = PROVIDER_URLS[names[i]];
    if (!url || url.charAt(0) === "#") continue;   // 空 / 占位符(#机场订阅) -> 跳过, 上标序号不占用
    out[names[i]] = {
      type: "http", interval: 3600, proxy: PROVIDER_PROXY,
      "health-check": { enable: true, url: "https://www.gstatic.com/generate_204", interval: 300 },
      url: url, override: { "additional-prefix": sup(i + 1) },
    };
  }
  return out;
}

// ===================== 分享链接解析器 (自带, 不依赖 atob/URL/Buffer) =====================
// base64 -> 字节数组 (兼容 url-safe 与缺省填充)
function b64bytes(s) {
  s = String(s).replace(/-/g, "+").replace(/_/g, "/").replace(/\s+/g, "");
  while (s.length % 4) s += "=";
  const T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const out = []; let buf = 0, bits = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i); if (c === "=") break;
    const v = T.indexOf(c); if (v < 0) continue;
    buf = (buf << 6) | v; bits += 6;
    if (bits >= 8) { bits -= 8; out.push((buf >> bits) & 0xff); }
  }
  return out;
}
// 字节数组 -> UTF-8 字符串 (支持中文/emoji 节点名)
function utf8(b) {
  let s = "", i = 0;
  while (i < b.length) {
    let c = b[i++];
    if (c < 0x80) s += String.fromCharCode(c);
    else if (c < 0xE0) s += String.fromCharCode(((c & 0x1f) << 6) | (b[i++] & 0x3f));
    else if (c < 0xF0) s += String.fromCharCode(((c & 0x0f) << 12) | ((b[i++] & 0x3f) << 6) | (b[i++] & 0x3f));
    else { let cp = ((c & 0x07) << 18) | ((b[i++] & 0x3f) << 12) | ((b[i++] & 0x3f) << 6) | (b[i++] & 0x3f); cp -= 0x10000; s += String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)); }
  }
  return s;
}
function b64str(s) { return utf8(b64bytes(s)); }
function dec(s) { try { return decodeURIComponent(s); } catch (e) { return s; } }
function qparse(q) {
  const o = {}; if (!q) return o;
  q.split("&").forEach(function (kv) {
    if (!kv) return; const i = kv.indexOf("=");
    o[dec(i < 0 ? kv : kv.slice(0, i))] = i < 0 ? "" : dec(kv.slice(i + 1));
  });
  return o;
}
// scheme://rest?query#frag
function splitURI(u) {
  const m = /^([a-z0-9]+):\/\/([\s\S]*)$/i.exec(u); if (!m) return null;
  let rest = m[2], frag = "", query = "";
  const h = rest.indexOf("#"); if (h >= 0) { frag = dec(rest.slice(h + 1)); rest = rest.slice(0, h); }
  const q = rest.indexOf("?"); if (q >= 0) { query = rest.slice(q + 1); rest = rest.slice(0, q); }
  return { scheme: m[1].toLowerCase(), rest: rest, query: query, frag: frag };
}
// userinfo@host:port[/path] -> 各字段 (支持 IPv6 [..])
function splitAuthority(rest) {
  let path = ""; const sl = rest.indexOf("/"); if (sl >= 0) { path = rest.slice(sl); rest = rest.slice(0, sl); }
  let userinfo = "", hp = rest; const at = rest.lastIndexOf("@");
  if (at >= 0) { userinfo = rest.slice(0, at); hp = rest.slice(at + 1); }
  let host = hp, port = "";
  if (hp.charAt(0) === "[") { const e = hp.indexOf("]"); host = hp.slice(1, e); const c = hp.indexOf(":", e); if (c >= 0) port = hp.slice(c + 1); }
  else { const c = hp.lastIndexOf(":"); if (c >= 0) { host = hp.slice(0, c); port = hp.slice(c + 1); } }
  return { userinfo: userinfo, host: host, port: port, path: path };
}
function wsOpts(q) { return { path: q.path || "/", headers: q.host ? { Host: q.host } : {} }; }
function grpcOpts(q) { return { "grpc-service-name": q.serviceName || q.path || "" }; }
function insec(q) { return q.insecure === "1" || q.allowInsecure === "1" || q.allow_insecure === "1"; }

function pVmess(s) {
  const j = JSON.parse(b64str(s.rest)); const net = j.net || "tcp";
  const p = { name: j.ps || "", type: "vmess", server: j.add, port: +j.port, uuid: j.id, alterId: +(j.aid || 0), cipher: j.scy || j.security || "auto", udp: true, network: net === "h2" ? "h2" : net };
  if (j.tls === "tls" || j.tls === true) { p.tls = true; if (j.sni || j.host) p.servername = j.sni || j.host; }
  if (j.fp) p["client-fingerprint"] = j.fp;
  if (j.alpn) p.alpn = String(j.alpn).split(",");
  if (net === "ws") p["ws-opts"] = { path: j.path || "/", headers: j.host ? { Host: j.host } : {} };
  else if (net === "grpc") p["grpc-opts"] = { "grpc-service-name": j.path || "" };
  else if (net === "h2") p["h2-opts"] = { host: j.host ? [j.host] : [], path: j.path || "/" };
  return p;
}
function pVless(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query), net = q.type || "tcp", sec = q.security || "none";
  const p = { name: s.frag || "", type: "vless", server: a.host, port: +a.port, uuid: dec(a.userinfo), udp: true, network: net };
  if (q.flow) p.flow = q.flow;
  if (sec === "tls" || sec === "reality") { p.tls = true; if (q.sni) p.servername = q.sni; if (q.alpn) p.alpn = q.alpn.split(","); if (q.fp) p["client-fingerprint"] = q.fp; }
  if (sec === "reality") p["reality-opts"] = { "public-key": q.pbk || "", "short-id": q.sid || "" };
  if (insec(q)) p["skip-cert-verify"] = true;
  if (net === "ws") p["ws-opts"] = wsOpts(q);
  else if (net === "grpc") p["grpc-opts"] = grpcOpts(q);
  return p;
}
function pTrojan(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query), net = q.type || "tcp";
  const p = { name: s.frag || "", type: "trojan", server: a.host, port: +a.port, password: dec(a.userinfo), udp: true };
  if (q.sni) p.sni = q.sni;
  if (q.alpn) p.alpn = q.alpn.split(",");
  if (q.fp) p["client-fingerprint"] = q.fp;
  if (insec(q)) p["skip-cert-verify"] = true;
  if (net === "ws") { p.network = "ws"; p["ws-opts"] = wsOpts(q); }
  else if (net === "grpc") { p.network = "grpc"; p["grpc-opts"] = grpcOpts(q); }
  return p;
}
function ssObj(name, host, port, cipher, password, q) {
  const p = { name: name, type: "ss", server: host, port: +port, cipher: cipher, password: password, udp: true };
  if (q && q.plugin) {
    const parts = q.plugin.split(";"), pl = parts[0], opts = {};
    for (let i = 1; i < parts.length; i++) { const kv = parts[i].split("="); opts[kv[0]] = kv[1] === undefined ? true : kv[1]; }
    if (pl === "obfs-local" || pl === "simple-obfs") { p.plugin = "obfs"; p["plugin-opts"] = { mode: opts.obfs || "http", host: opts["obfs-host"] }; }
    else if (pl.indexOf("v2ray") >= 0) { p.plugin = "v2ray-plugin"; p["plugin-opts"] = { mode: "websocket", host: opts.host, path: opts.path, tls: !!opts.tls }; }
  }
  return p;
}
function pSS(s) {
  if (s.rest.indexOf("@") >= 0) {
    const a = splitAuthority(s.rest); let mp = a.userinfo;
    if (mp.indexOf(":") < 0) mp = b64str(mp);          // userinfo 是 base64(method:pass)
    const ci = mp.indexOf(":");
    return ssObj(s.frag || "", a.host, a.port, mp.slice(0, ci), mp.slice(ci + 1), qparse(s.query));
  }
  const d = b64str(s.rest), at = d.lastIndexOf("@"), mp = d.slice(0, at), hp = d.slice(at + 1);
  const ci = mp.indexOf(":"), cp = hp.lastIndexOf(":");
  return ssObj(s.frag || "", hp.slice(0, cp), hp.slice(cp + 1), mp.slice(0, ci), mp.slice(ci + 1), {});
}
function pHy2(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query);
  const p = { name: s.frag || "", type: "hysteria2", server: a.host, port: +a.port, password: dec(a.userinfo) };
  if (q.sni) p.sni = q.sni;
  if (insec(q)) p["skip-cert-verify"] = true;
  if (q.obfs && q.obfs !== "none") { p.obfs = q.obfs; if (q["obfs-password"]) p["obfs-password"] = q["obfs-password"]; }
  if (q.alpn) p.alpn = q.alpn.split(",");
  if (q.mport) p.ports = q.mport;                       // 端口跳跃 30000-31000
  return p;
}
function pTuic(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query);
  let uuid = dec(a.userinfo), password = ""; const ci = a.userinfo.indexOf(":");
  if (ci >= 0) { uuid = dec(a.userinfo.slice(0, ci)); password = dec(a.userinfo.slice(ci + 1)); }
  const p = { name: s.frag || "", type: "tuic", server: a.host, port: +a.port, uuid: uuid, password: password };
  if (q.sni) p.sni = q.sni;
  if (q.alpn) p.alpn = q.alpn.split(",");
  if (q.congestion_control) p["congestion-controller"] = q.congestion_control;
  if (q.udp_relay_mode) p["udp-relay-mode"] = q.udp_relay_mode;
  if (insec(q)) p["skip-cert-verify"] = true;
  return p;
}
function pAnytls(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query);
  const p = { name: s.frag || "", type: "anytls", server: a.host, port: +a.port, password: dec(a.userinfo), udp: true };
  if (q.sni) p.sni = q.sni;
  if (insec(q)) p["skip-cert-verify"] = true;
  if (q.fp) p["client-fingerprint"] = q.fp;
  if (q.alpn) p.alpn = q.alpn.split(",");
  return p;
}
// userinfo 取用户名/密码: 先试 base64(user:pass), 再试明文 user:pass。塞进目标对象。
function authCreds(userinfo, p) {
  if (!userinfo) return;
  let ui = userinfo;
  if (ui.indexOf(":") < 0) { try { ui = b64str(ui); } catch (e) {} }  // 无冒号 -> 当 base64(user:pass)
  const ci = ui.indexOf(":");
  if (ci < 0) { p.username = dec(ui); return; }                       // 只有用户名
  p.username = dec(ui.slice(0, ci));
  p.password = dec(ui.slice(ci + 1));
}
// socks://(socks5://) [base64(user:pass)|user:pass@]host:port[?tls=1&...]#name
function pSocks(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query);
  const p = { name: s.frag || "", type: "socks5", server: a.host, port: +a.port, udp: true };
  authCreds(a.userinfo, p);
  if (q.tls === "1" || q.tls === "true") p.tls = true;
  if (insec(q)) p["skip-cert-verify"] = true;
  return p;
}
// http://(https://) [user:pass@]host:port[?sni=...]#name  (https:// 或 ?tls=1 -> 走 TLS)
function pHttp(s) {
  const a = splitAuthority(s.rest), q = qparse(s.query);
  const p = { name: s.frag || "", type: "http", server: a.host, port: +a.port };
  authCreds(a.userinfo, p);
  if (s.scheme === "https" || q.tls === "1" || q.tls === "true") { p.tls = true; if (q.sni) p.sni = q.sni; }
  if (insec(q)) p["skip-cert-verify"] = true;
  return p;
}
function parseOne(u) {
  const s = splitURI(u); if (!s) return null;
  switch (s.scheme) {
    case "vmess": return pVmess(s);
    case "vless": return pVless(s);
    case "trojan": return pTrojan(s);
    case "ss": return pSS(s);
    case "hysteria2": case "hy2": return pHy2(s);
    case "tuic": return pTuic(s);
    case "anytls": return pAnytls(s);
    case "socks": case "socks5": return pSocks(s);
    case "http": case "https": return pHttp(s);
    default: return null;
  }
}
// 遍历链接列表 -> 节点对象数组。
// 元素两种写法: "链接"  或  ["自定义名","链接"]。空行/注释(#开头)/坏链接跳过, 且不占序号。
// 名称优先级: 自定义名 > 链接自带#备注(parseOne 存进 p.name) > 协议名; 最终统一加上标序号前缀 ¹²³…
function parseLinks(list) {
  const out = [];
  let n = 0;
  for (let item of (list || [])) {
    let nm = "", link = "";
    if (Array.isArray(item)) {                                   // ["名称","链接"]
      nm = String(item[0] == null ? "" : item[0]).trim();
      link = String(item[1] == null ? "" : item[1]).trim();
    } else {                                                     // "链接"
      link = String(item == null ? "" : item).trim();
    }
    if (!link || link.charAt(0) === "#") continue;               // 空/占位 -> 跳过, 不占序号
    let p = null;
    try { p = parseOne(link); } catch (e) { p = null; }
    if (!p || !p.server || !p.port) continue;                    // 解析失败 -> 跳过, 不占序号
    n++;
    const base = nm || p.name || p.type;                         // 自定义名 > 链接#备注 > 协议名
    p.name = LINK_TAG + sup(n) + base;                           // 前缀: 区分标记 + 上标序号, 如 📌¹洛杉矶
    out.push(p);
  }
  return out;
}

// 解析"订阅 proxies: 下的 YAML 节点"(flow 写法子集): 每行一个 {k: v, ...} 映射, 行首 "- " 可有可无。
// 支持: 双引号/裸标量, 整数/小数/布尔, 嵌套 {} 与 []; 端口段(30000-31000)、uuid、域名等带"-"或"."的串原样保留为字符串。
// 不支持: 缩进多行块式写法(必须单行 flow)。解析失败的行整条跳过, 不影响其他行。
function parseYamlProxies(text) {
  const out = [];
  if (!text) return out;
  for (let line of String(text).split(/\r?\n/)) {
    line = line.trim();
    if (!line || line.charAt(0) === "#") continue;            // 空行 / 注释
    if (line.charAt(0) === "-") line = line.slice(1).trim();  // 去掉块序列标记 "- "
    if (line.charAt(0) !== "{") continue;                     // 只收 flow 映射
    let obj = null;
    try { obj = yflow(line); } catch (e) { obj = null; }
    if (obj && typeof obj === "object" && obj.server) out.push(obj);
  }
  return out;
}
// 极简 flow 解析器: 解析单个 {map} / [seq] / 标量。仅覆盖节点配置所需子集, 不是完整 YAML。
function yflow(s) {
  let i = 0;
  const ws = function () { while (i < s.length && /\s/.test(s[i])) i++; };
  function parseValue() {
    ws();
    const ch = s[i];
    if (ch === "{") return parseMap();
    if (ch === "[") return parseSeq();
    return parseScalar();
  }
  function parseMap() {
    const o = {}; i++; ws();                       // 跳过 {
    if (s[i] === "}") { i++; return o; }
    while (i < s.length) {
      ws();
      let key;
      if (s[i] === '"' || s[i] === "'") key = parseQuoted();
      else { let j = i; while (i < s.length && s[i] !== ":") i++; key = s.slice(j, i).trim(); }
      ws(); if (s[i] === ":") i++;                  // 跳过 :
      o[key] = parseValue(); ws();
      if (s[i] === ",") { i++; continue; }
      if (s[i] === "}") { i++; break; }
      break;
    }
    return o;
  }
  function parseSeq() {
    const a = []; i++; ws();                        // 跳过 [
    if (s[i] === "]") { i++; return a; }
    while (i < s.length) {
      a.push(parseValue()); ws();
      if (s[i] === ",") { i++; continue; }
      if (s[i] === "]") { i++; break; }
      break;
    }
    return a;
  }
  function parseScalar() {
    ws();
    if (s[i] === '"' || s[i] === "'") return parseQuoted();
    let j = i;
    while (i < s.length && ",}]".indexOf(s[i]) === -1) i++;   // 裸标量到结构符为止(冒号不算, 故 URL 可保留)
    const raw = s.slice(j, i).trim();
    if (raw === "true") return true;
    if (raw === "false") return false;
    if (raw === "null" || raw === "~" || raw === "") return null;
    if (/^-?\d+$/.test(raw)) return parseInt(raw, 10);        // 纯整数 -> 数字 (端口段含"-"不在此列, 保持字符串)
    if (/^-?\d+\.\d+$/.test(raw)) return parseFloat(raw);     // 小数 -> 数字
    return raw;                                                // 其余(uuid/域名/端口段/密钥…) -> 字符串
  }
  function parseQuoted() {
    const q = s[i]; i++;
    let buf = "";
    while (i < s.length && s[i] !== q) {
      if (s[i] === "\\" && i + 1 < s.length) { buf += s[i + 1]; i += 2; continue; }
      buf += s[i]; i++;
    }
    i++;                                            // 跳过结束引号
    return buf;
  }
  return parseValue();
}

// 把整份配置改成 YAML 安全(无条件执行)。逐项功能等价, 不删任何"功能", 只换 ClashMi 内核
// 序列化时不会加引号、会导致启动报错的写法。对 FlClash/Verge/Party 也无副作用。
// 注: 节点名 safeName 已前移到 main() 第 1.5 步(国家检测之前), 此处不再重复处理。
function makeYamlSafe(config) {
  if (config["bind-address"] === "*") delete config["bind-address"];      // = 默认监听全部

  const cors = config["external-controller-cors"];
  if (cors && Array.isArray(cors["allow-origins"]) && cors["allow-origins"].indexOf("*") !== -1) {
    delete cors["allow-origins"];                                          // 裸 '*' 无安全等价, 仅去此项
  }

  if (config.hosts && typeof config.hosts === "object") {                  // '*.x' -> '.x'
    const h = {};
    for (const k of Object.keys(config.hosts)) h[k.indexOf("*.") === 0 ? k.slice(1) : k] = config.hosts[k];
    config.hosts = h;
  }
  return config;
}

// 兼容部分客户端的导出习惯; 浏览器/纯脚本环境忽略即可
if (typeof module !== "undefined") { module.exports = main; module.exports.main = main; }