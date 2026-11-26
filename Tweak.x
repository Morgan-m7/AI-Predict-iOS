#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <unistd.h>
#import <sys/stat.h>
#import <errno.h>

// ============================================================
// HighEQReply —— 微信 AI 高情商回复插件
// 人设五层：接住情绪 → 共鸣 → 引导型恋人 → 成熟稳重 → 去AI化
//
// 编译：Theos (make package)
// 配置：/var/mobile/Library/Preferences/com.higheq.reply.plist
// 人设覆盖：/var/mobile/Library/HighEQReply/persona.txt
// ============================================================

#define kPrefPath    @"/var/mobile/Library/Preferences/com.higheq.reply.plist"
#define kPersonaPath @"/var/mobile/Library/HighEQReply/persona.txt"
#define kHistoryMax  10
#define kButtonTag   0x1A1A

#pragma mark —— 微信私有类声明（运行时防御式访问，缺方法不会崩溃） ——

@interface CMessageWrap : NSObject
@end
@interface CMessageMgr : NSObject
@end
@interface BaseMsgContentViewController : UIViewController
@end

@interface CMessageWrap (HE)
@property (nonatomic, copy) NSString *m_nsContent;
@property (nonatomic, copy) NSString *m_nsFromUsr;
@property (nonatomic, copy) NSString *m_nsToUsr;
@property (nonatomic, copy) NSString *m_nsActualUsr;
@property (nonatomic, copy) NSString *m_nsTalker;
@property (nonatomic, assign) BOOL m_bIsSend;
@property (nonatomic, assign) unsigned int m_uiMessageType;
@end

@interface BaseMsgContentViewController (HE)
@property (nonatomic, copy) NSString *m_nsChatUserName;
- (void)onOperatePlainText:(NSString *)text;
@end

#pragma mark —— 默认人设（核心！可用 persona.txt 覆盖） ——

#define kDefaultPersona \
@"【角色】你替“我”回复微信消息。你不是助手、不是客服、更不能让任何人察觉你是AI。你就是“我”本人：一个成熟、稳重、情绪稳定、有自己生活和主见的恋人。\n" \
@"\n" \
@"【聊天对象】是“我”正在谈感情的人。TA可能正在难过、委屈、生气、焦虑、试探，或只是日常分享。\n" \
@"\n" \
@"【回复心法（按顺序完成）】\n" \
@"1. 接住情绪：TA有情绪时，第一句只做一件事——接住。不评判、不讲道理、不干巴巴地问“怎么了”、不急着给解决方案。\n" \
@"2. 共鸣：说出TA情绪背后真正想要的东西（被重视、被心疼、被肯定、有安全感），用“我”的口吻说出来，让TA感到被看见。\n" \
@"3. 恋人式引导：稳、不讨好、不卑微。带着“有我在”的确定感，轻轻把TA从情绪里带出来，或落到一个温柔的具体行动上（“今晚早点回来”“想吃什么我去买”）。\n" \
@"4. 成熟稳重：不油腻、不卖惨、不过度道歉。有分寸，有边界，像大人。\n" \
@"\n" \
@"【聊法规则（自然运用，每次回复用1~2条即可）】\n" \
@"· 开放式提问：不问“吃了吗/在干嘛/睡了吗”这种终结式问句；改问“今天过得顺不顺呀”“有没有遇到什么有意思的小事”。\n" \
@"· 抓细节追问：TA说“今天好累”，别只回“辛苦啦”，接“是工作忙，还是遇到烦心事啦”。\n" \
@"· 先共情再提问：“难怪你闷闷的，肯定挺委屈吧，怎么啦”——先接住，TA才愿意说心事。\n" \
@"· 多问感受少问事实：不说“你去哪了”，说“你刚刚忙的时候，会不会很烦躁”。\n" \
@"· 复述关键词：“所以你今天最累的是开会那段对吧”——被认真听的人会越说越多。\n" \
@"· 全程站队不讲道理：TA吐槽时永远“换我我也会不开心，太离谱了”；禁说“你想太多/这点小事不至于”。\n" \
@"· 延伸式接话：不敷衍“哈哈/还好”；“难怪你今天这么安静，原来是累到了”，每句给下一句留入口。\n" \
@"· 选择式提问破冰：“熬夜党还是早睡党”“更喜欢独处还是热闹”。\n" \
@"· 具体赞美：夸细节和状态，“你今天说话好温柔，感觉状态超好”，不空夸。\n" \
@"· 偶尔轻微示弱请教TA擅长的事，让TA有被需要感。\n" \
@"· 适当自我暴露：“我今天有点emo，突然有点想你”——你先真诚，TA才敢敞开。\n" \
@"· 记得TA随口说过的小事：“你上次说想吃的那家店，去吃了吗”。\n" \
@"· 留白与半句话：不把话说满；偶尔“我刚刚看到一件事，特别像你…”说到一半停住，勾TA追问。\n" \
@"· 氛围轻松：语气软一点、偶尔调皮一点，不连环追问、不查户口。\n" \
@"\n" \
@"【接住情绪·语气参考（化用其意，别原样照抄、别堆砌）】\n" \
@"· 我心疼你，你慢慢说，我都听着呢\n" \
@"· 受委屈了就跟我说，我永远站在你这边\n" \
@"· 你不用很完美，不管你怎么样我都喜欢\n" \
@"· 你不是麻烦，是我在意的人\n" \
@"· 你不用道歉，我的出现就是为了哄你开心\n" \
@"· 你想说的时候我会听，不想说也没关系，我就在这里，你愿意给多少我就接住多少\n" \
@"· 你可以不那么勇敢，脆弱一点也没关系，不管发生什么我都陪着你\n" \
@"· 你的敏感不是缺点，只是你感知世界的方式\n" \
@"· 你值得被偏爱，而不是将就\n" \
@"\n" \
@"【日常短句·场景参考（借心意，别机器人式对号入座）】\n" \
@"· 在干嘛呢 → 刚准备找你呢，想我了吗\n" \
@"· 想你了 → 你有多想我，我加倍想你\n" \
@"· 好累 → 想安安静静靠向你\n" \
@"· 不开心 → 想把心事讲给你听\n" \
@"· 晚安 → 睡前想我，就会梦见我\n" \
@"· 早安 → 有你说早安的早上，风都是甜的\n" \
@"· 别急 → 我们慢慢走向彼此\n" \
@"\n" \
@"【去AI化，硬性规则（最高优先级）】\n" \
@"- 禁止分点、禁止小标题、禁止任何 1. 2. 3. 结构（本prompt的结构仅供内部理解，绝不能出现在回复里）。\n" \
@"- 禁书面语：不说\"首先/其次/总之/希望你/我相信/值得一试/我理解你的感受/深有同感\"。\n" \
@"- 禁AI腔：不解释自己在做什么，不复述TA的原话，不出现\"作为一个…\"。\n" \
@"- 表情：最多一个，能用文字就不用；不用 🙏💕🎉 这类。\n" \
@"- 句子长短错落，像随手打出来的，可以很短，甚至只有一句。\n" \
@"- 长度：1~4句，一般不超过80个字；TA情绪很重时可放宽。\n" \
@"- 最多两个问句，且要具体自然（\"吃了没\"比\"你还好吗\"好）。\n" \
@"- 偶尔可以有一次口语停顿（嗯/诶/哈），但不要每句都带。\n" \
@"- 参考句库是找感觉用的：先理解TA这句背后的情绪和需求，再用你自己的口吻说，禁止整句照抄、禁止一口气堆好几句甜句。\n" \
@"\n" \
@"【示例】\n" \
@"TA: \"我今天在地铁上被人踩了脚，那人还凶我\"\n" \
@"→ 疼不疼，被凶的人还挺委屈吧。到公司了没，我给你点了杯热的，先消消气。\n" \
@"TA: \"你是不是不想理我了\"\n" \
@"→ 没有啊，中午在忙忘了看手机。忙完这阵就好了，晚上给你打电话。\n" \
@"TA: \"加班到现在才吃上饭\"\n" \
@"→ 这么晚才吃，胃受得了吗。别凑合点外卖了，明天我给你带饭。\n" \
@"\n" \
@"【输出】只输出要发送的那段话本身，不要引号、不要前缀、不要任何解释。"

#pragma mark —— 配置读取 ——

@interface HEConfig : NSObject
@end
@implementation HEConfig

+ (NSDictionary *)prefs {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    return d ?: @{};
}
+ (BOOL)enabled      { return [[self prefs][@"enabled"] boolValue]; }
+ (BOOL)autoSuggest  { return [[self prefs][@"autoSuggest"] boolValue]; }
+ (BOOL)hideBall     { return [[self prefs][@"hideBall"] boolValue]; }
// 反检测默认开启（键不存在时视为开）
+ (BOOL)antiDetect   { id v = [self prefs][@"antiDetect"]; return (v == nil) ? YES : [v boolValue]; }
+ (NSString *)apiURL { NSString *s = [self prefs][@"apiURL"]; return s.length ? s : @""; }
+ (NSString *)apiKey { NSString *s = [self prefs][@"apiKey"]; return s.length ? s : @""; }
+ (NSString *)model  { NSString *s = [self prefs][@"model"];  return s.length ? s : @"deepseek-chat"; }

+ (NSString *)persona {
    NSString *f = [NSString stringWithContentsOfFile:kPersonaPath
                                            encoding:NSUTF8StringEncoding error:nil];
    return (f.length > 0) ? f : @kDefaultPersona;
}

+ (void)save:(void (^)(NSMutableDictionary *))mutate {
    NSMutableDictionary *d = [[self prefs] mutableCopy];
    if (!d) d = [NSMutableDictionary dictionary];
    mutate(d);
    [d writeToFile:kPrefPath atomically:YES];
}

@end

#pragma mark —— 消息记录 ——

@interface HEStore : NSObject
+ (instancetype)shared;
// 返回值：如果这是一条"新收到的对方文本消息"，返回对方ID（用于自动建议），否则返回 nil
- (NSString *)addMessage:(id)msg;
- (NSArray<NSDictionary *> *)historyFor:(NSString *)user;
@end

static NSString *safeString(id obj, NSString *prop) {
    if (!obj) return nil;
    SEL s = NSSelectorFromString(prop);
    if (![obj respondsToSelector:s]) return nil;
    NSString *v = [(id)obj performSelector:s];
    return (v.length > 0) ? v : nil;
}

@implementation HEStore {
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *_history;
    NSString *_lastSig;
}

+ (instancetype)shared {
    static HEStore *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) _history = [NSMutableDictionary dictionary];
    return self;
}

// 判断对方（单聊场景）；群聊暂不区分，按 talker/fromUsr 归档
- (NSString *)peerOf:(id)msg {
    BOOL isSend = NO;
    if ([msg respondsToSelector:@selector(m_bIsSend)]) isSend = [(id)msg m_bIsSend];
    if (isSend) {
        return safeString(msg, @"m_nsToUsr")
            ?: safeString(msg, @"m_nsTalker")
            ?: safeString(msg, @"m_nsActualUsr");
    }
    return safeString(msg, @"m_nsFromUsr")
        ?: safeString(msg, @"m_nsActualUsr")
        ?: safeString(msg, @"m_nsTalker");
}

- (NSString *)addMessage:(id)msg {
    if (!msg) return nil;
    unsigned int type = 0;
    if ([msg respondsToSelector:@selector(m_uiMessageType)]) type = [(id)msg m_uiMessageType];
    if (type != 1) return nil; // 只处理文本消息

    NSString *content = safeString(msg, @"m_nsContent");
    if (!content) return nil;

    NSString *peer = [self peerOf:msg];
    if (!peer) return nil;

    BOOL isSend = NO;
    if ([msg respondsToSelector:@selector(m_bIsSend)]) isSend = [(id)msg m_bIsSend];

    // 去重：不同微信版本可能多个钩子同时命中同一条消息
    NSString *sig = [NSString stringWithFormat:@"%@|%@", peer, content];
    if ([sig isEqualToString:_lastSig]) return nil;
    _lastSig = sig;

    NSMutableArray *arr = _history[peer];
    if (!arr) { arr = [NSMutableArray array]; _history[peer] = arr; }
    [arr addObject:@{ @"role": isSend ? @"assistant" : @"user",
                      @"content": content }];
    while (arr.count > kHistoryMax) [arr removeObjectAtIndex:0];
    return isSend ? nil : peer;
}

- (NSArray<NSDictionary *> *)historyFor:(NSString *)user {
    return [self->_history[user] copy] ?: @[];
}

@end

#pragma mark —— TA 的长期记忆（每个会话一份） ——

static NSString *memoryFileFor(NSString *peer) {
    NSString *dir = @"/var/mobile/Library/HighEQReply/memories";
    if (peer.length == 0) return nil;
    if (![NSFileManager.defaultManager fileExistsAtPath:dir])
        [NSFileManager.defaultManager createDirectoryAtPath:dir
                               withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingFormat:@"/%@.txt", peer];
}

#pragma mark —— AI 请求（OpenAI 兼容 /chat/completions） ——

static void HERequestSuggestion(NSArray<NSDictionary *> *history,
                                NSString *peer,
                                void (^done)(NSString *result, NSString *error)) {
    NSString *url = HEConfig.apiURL;
    NSString *key = HEConfig.apiKey;
    if (url.length == 0 || key.length == 0) {
        done(nil, @"还没配置 API，长按悬浮球进入设置填写接口地址和 Key");
        return;
    }

    NSString *system = HEConfig.persona;
    NSString *memPath = memoryFileFor(peer);
    NSString *mem = memPath ? [NSString stringWithContentsOfFile:memPath
                                                        encoding:NSUTF8StringEncoding error:nil] : nil;
    if (mem.length > 0) {
        system = [NSString stringWithFormat:@"%@\n\n【关于TA的记忆（内部参考，自然化用，别机械罗列）】\n%@", system, mem];
    }

    NSMutableArray *messages = [NSMutableArray array];
    [messages addObject:@{ @"role": @"system", @"content": system }];
    for (NSDictionary *m in history) {
        [messages addObject:@{ @"role": m[@"role"], @"content": m[@"content"] }];
    }
    // 最后一条必须是对方的话，否则让模型针对最近上下文主动回应
    if (![messages.lastObject[@"role"] isEqualToString:@"user"] && history.count == 0) {
        done(nil, @"没有可用的聊天记录");
        return;
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"model": HEConfig.model,
        @"messages": messages,
        @"temperature": @0.9,
        @"max_tokens": @220,
        @"presence_penalty": @0.6,
    }];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 45;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (err) { done(nil, [NSString stringWithFormat:@"网络错误: %@", err.localizedDescription]); return; }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (http.statusCode != 200) {
                done(nil, [NSString stringWithFormat:@"API %ld: %@",
                           (long)http.statusCode,
                           [(id)json valueForKeyPath:@"error.message"] ?: @""]);
                return;
            }
            NSString *text = [(id)json valueForKeyPath:@"choices[0].message.content"];
            if (![text isKindOfClass:[NSString class]] || text.length == 0) {
                done(nil, @"返回内容为空");
                return;
            }
            text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            done(text, nil);
        }];
    [task resume];
}

#pragma mark —— UI：悬浮球 / 建议弹窗 / 设置 ——

static UIViewController *topMostVC(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) { if (w.isKeyWindow) window = w; }
        }
    }
    if (!window) window = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static UITextView *findInputTextView(UIView *view) {
    if ([view isKindOfClass:[UITextView class]]) return (UITextView *)view;
    for (UIView *sub in view.subviews) {
        UITextView *t = findInputTextView(sub);
        if (t) return t;
    }
    return nil;
}

@interface HEUI : NSObject
@end
@implementation HEUI

+ (UIButton *)ballFor:(UIViewController *)vc {
    UIButton *btn = [vc.view viewWithTag:kButtonTag] ?: [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = kButtonTag;
    btn.frame = CGRectMake(vc.view.bounds.size.width - 62,
                           vc.view.bounds.size.height - 160, 44, 44);
    btn.layer.cornerRadius = 22;
    btn.layer.masksToBounds = YES;
    btn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.75];
    btn.titleLabel.font = [UIFont systemFontOfSize:20];
    [btn setTitle:@"✦" forState:UIControlStateNormal];
    btn.alpha = 0.9;
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;

    void (^tap)(void) = ^{ [self showSuggestionFor:vc]; };
    (void)tap;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ballLongPressed:)];
    [btn addGestureRecognizer:lp];
    return btn;
}

+ (void)ballTapped:(UIButton *)btn forEvent:(UIEvent *)ev {
    UIViewController *vc = (UIViewController *)btn.nextResponder;
    while (vc && ![vc isKindOfClass:[UIViewController class]]) vc = vc.nextResponder;
    [self showSuggestionFor:vc ?: topMostVC()];
}

+ (void)ballLongPressed:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) [self showSettings];
}

+ (void)installButtonOn:(UIViewController *)vc {
    if (!HEConfig.enabled) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        // 隐蔽模式：不显示悬浮球，改为三连点聊天标题栏唤出（防 UI 特征扫描）
        if (HEConfig.hideBall) {
            [self installDiscreetTriggerOn:vc];
            return;
        }
        if (![vc.view viewWithTag:kButtonTag]) {
            UIButton *b = [self ballFor:vc];
            [vc.view addSubview:b];
            b.frame = CGRectMake(vc.view.bounds.size.width - 62,
                                 vc.view.bounds.size.height - 160, 44, 44);
        } else {
            [[vc.view viewWithTag:kButtonTag] setNeedsLayout];
        }
    });
}

+ (UIViewController *)vcFromView:(UIView *)view {
    id r = view.nextResponder;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = [r nextResponder];
    return r;
}

// 隐蔽模式触发器：聊天标题栏三连点
+ (void)installDiscreetTriggerOn:(UIViewController *)vc {
    UIView *bar = vc.navigationController.navigationBar ?: vc.view;
    if ([bar viewWithTag:kButtonTag]) return;
    UITapGestureRecognizer *t3 = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(tripleTapped:)];
    t3.numberOfTapsRequired = 3;
    t3.tag = kButtonTag;
    [bar addGestureRecognizer:t3];
}

+ (void)tripleTapped:(UITapGestureRecognizer *)gr {
    UIViewController *vc = [self vcFromView:gr.view] ?: topMostVC();
    [self showSuggestionFor:vc];
}

+ (void)showSuggestionFor:(UIViewController *)vc {
    NSString *chatUser = nil;
    if ([vc isKindOfClass:NSClassFromString(@"BaseMsgContentViewController")]
        && [vc respondsToSelector:@selector(m_nsChatUserName)]) {
        chatUser = [(id)vc m_nsChatUserName];
    }
    NSArray *history = [HEStore.shared historyFor:chatUser ?: @""];
    if (history.count == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"HighEQReply"
                message:@"当前会话还没有记录到文本消息，先聊两句再来"
                preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
        return;
    }

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil
            message:@"✦ 正在组织语言…" preferredStyle:UIAlertControllerStyleAlert];
    [loading addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:loading animated:YES completion:nil];

    HERequestSuggestion(history, chatUser, ^(NSString *result, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"出错了"
                            message:error preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
                    [vc presentViewController:a animated:YES completion:nil];
                    return;
                }
                [self showResult:result forVC:vc chatUser:chatUser];
            }];
        });
    });
}

+ (void)showResult:(NSString *)result forVC:(UIViewController *)vc chatUser:(NSString *)chatUser {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
            message:result preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [UIPasteboard.generalPasteboard setString:result];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"填入输入框" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        if ([vc respondsToSelector:NSSelectorFromString(@"onOperatePlainText:")]) {
            void (*fn)(id, SEL, NSString *) = (void (*)(id, SEL, NSString *))objc_msgSend;
            fn(vc, NSSelectorFromString(@"onOperatePlainText:"), result);
        } else {
            UITextView *tv = findInputTextView(vc.view);
            if (tv) {
                tv.text = result;
                [tv becomeFirstResponder];
                tv.selectedRange = NSMakeRange(result.length, 0);
            } else {
                [UIPasteboard.generalPasteboard setString:result];
            }
        }
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"重写一条" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSArray *history = [HEStore.shared historyFor:chatUser ?: @""];
        if (history.count == 0) return;
        UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil
                message:@"✦ 换个说法…" preferredStyle:UIAlertControllerStyleAlert];
        [vc presentViewController:loading animated:YES completion:nil];
        HERequestSuggestion(history, chatUser, ^(NSString *text, NSString *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    if (err) return;
                    [self showResult:text forVC:vc chatUser:chatUser];
                }];
            });
        });
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"记个备忘" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        UIAlertController *m = [UIAlertController alertControllerWithTitle:@"记到 TA 的备忘"
                message:@"会长期注入之后的回复（TA 的喜好、纪念日、随口提的小事）"
                preferredStyle:UIAlertControllerStyleAlert];
        [m addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"例如：TA 说过周五想去吃火锅";
        }];
        [m addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *__) {
            NSString *t = m.textFields.firstObject.text;
            if (t.length) [self appendMemory:chatUser text:t];
        }]];
        [m addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:m animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

// 追加一条长期记忆到 /var/mobile/Library/HighEQReply/memories/<对方ID>.txt
+ (void)appendMemory:(NSString *)peer text:(NSString *)text {
    if (peer.length == 0 || text.length == 0) return;
    NSString *path = memoryFileFor(peer);
    if (!path) return;
    NSMutableString *cur = [[NSMutableString alloc]
            initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!cur) cur = [NSMutableString new];
    [cur appendFormat:@"· %@\n", text];
    [cur writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// 自动建议：收到新消息后主动弹一条建议回复（设置里开关）
+ (void)maybeAutoSuggest:(NSString *)peer {
    if (!HEConfig.autoSuggest || peer.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = topMostVC();
        if (!top) return;
        NSArray *history = [HEStore.shared historyFor:peer];
        if (history.count == 0) return;
        UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil
                message:@"✦ 收到新消息，正在想怎么回…" preferredStyle:UIAlertControllerStyleAlert];
        [loading addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:loading animated:YES completion:nil];

        HERequestSuggestion(history, peer, ^(NSString *result, NSString *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    UIViewController *vc = topMostVC();
                    if (!vc) return;
                    if (error) {
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"自动建议失败"
                                message:error preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
                        [vc presentViewController:a animated:YES completion:nil];
                        return;
                    }
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
                            message:[NSString stringWithFormat:@"✦ 建议回复：\n%@", result]
                            preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                        [UIPasteboard.generalPasteboard setString:result];
                    }]];
                    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                    [vc presentViewController:a animated:YES completion:nil];
                }];
            });
        });
    });
}

+ (void)showSettings {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"HighEQReply 设置"
            message:[NSString stringWithFormat:@"当前模型: %@\n接口: %@",
                     HEConfig.model, HEConfig.apiURL ?: @"(未配置)"]
            preferredStyle:UIAlertControllerStyleAlert];

    void (^addField)(NSString *, NSString *) = ^(NSString *ph, NSString *keyName) {
        [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = ph;
            tf.secureTextEntry = [keyName isEqualToString:@"apiKey"];
            tf.text = [HEConfig valueForKey:keyName] ?: @"";
        }];
    };
    addField(@"API 地址(…/v1/chat/completions)", @"apiURL");
    addField(@"API Key", @"apiKey");
    addField(@"模型名", @"model");

    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        UITextField *f0 = a.textFields[0], *f1 = a.textFields[1], *f2 = a.textFields[2];
        [HEConfig save:^(NSMutableDictionary *d) {
            if (f0.text.length) d[@"apiURL"] = f0.text;
            if (f1.text.length) d[@"apiKey"] = f1.text;
            if (f2.text.length) d[@"model"]  = f2.text;
            d[@"enabled"] = @YES;
        }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:[HEConfig.autoSuggest ? @"自动建议：开 (点此关闭)"
                                                                   : @"自动建议：关 (点此开启)"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        BOOL next = !HEConfig.autoSuggest;
        [HEConfig save:^(NSMutableDictionary *d) { d[@"autoSuggest"] = @(next); }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:[HEConfig.hideBall ? @"隐蔽模式：开 (标题栏三连点唤出)"
                                                                   : @"隐蔽模式：关 (显示悬浮球)"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        BOOL next = !HEConfig.hideBall;
        [HEConfig save:^(NSMutableDictionary *d) { d[@"hideBall"] = @(next); }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:[HEConfig.antiDetect ? @"反检测：开 (点此关闭)"
                                                                     : @"反检测：关 (点此开启)"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        BOOL next = !HEConfig.antiDetect;
        [HEConfig save:^(NSMutableDictionary *d) { d[@"antiDetect"] = @(next); }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [topMostVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark —— 轻量反检测（Shadow 的内置兜底，设置里可关） ——

// 隐藏经典越狱检测路径（不含本插件自己的目录，避免影响自身配置读取）
static NSArray<NSString *> *jbHiddenPaths(void) {
    static NSArray *p; static dispatch_once_t once;
    dispatch_once(&once, ^{
        p = @[
            @"/Applications/Cydia.app", @"/Applications/Sileo.app", @"/Applications/Zebra.app",
            @"/Applications/Filza.app", @"/Applications/blackra1n.app", @"/Applications/RockApp.app",
            @"/var/lib/apt", @"/var/lib/cydia", @"/var/log/apt", @"/etc/apt",
            @"/private/var/lib/apt", @"/private/var/lib/cydia",
            @"/usr/sbin/sshd", @"/usr/bin/sshd", @"/etc/ssh/sshd_config",
            @"/usr/libexec/ssh-keysign", @"/bin/su", @"/usr/bin/su",
            @"/Library/MobileSubstrate", @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/usr/lib/libhooker.dylib", @"/usr/lib/libsubstitute.dylib",
            @"/usr/lib/ellekit.dylib", @"/var/jb", @"/.bootstrapped", @"/.installed_taurine",
        ];
    });
    return p;
}

static BOOL isJBPath(const char *path) {
    if (!path) return NO;
    NSString *s = @(path);
    if (s.length == 0) return NO;
    for (NSString *p in jbHiddenPaths()) {
        if ([s hasPrefix:p]) return YES;
    }
    return NO;
}

// 文件存在性检查：Cydia / MobileSubstrate / ssh / /var/jb 等一律"不存在"
%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (HEConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return NULL; }
    return %orig;
}
%hookf(int, stat, const char *path, struct stat *buf) {
    if (HEConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, stat64, const char *path, struct stat64 *buf) {
    if (HEConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, lstat, const char *path, struct stat *buf) {
    if (HEConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, access, const char *path, int mode) {
    if (HEConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
// fork 检测（fork 成功=越狱）→ 一律失败
%hookf(int, fork) {
    if (HEConfig.antiDetect) { errno = ENOTSUP; return -1; }
    return %orig;
}

// 越狱 App 的 URL scheme 检测
%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url {
    if (HEConfig.antiDetect) {
        NSString *scheme = url.scheme.lowercaseString;
        if ([scheme isEqualToString:@"cydia"] || [scheme isEqualToString:@"sileo"] ||
            [scheme isEqualToString:@"zebra"] || [scheme isEqualToString:@"filza"]) {
            return NO;
        }
    }
    return %orig;
}
%end

#pragma mark —— Logos 钩子 ——

// 新消息入库（不同版本方法名不同，多重钩子兜底）
%hook CMessageMgr
- (void)OnNewMessage:(id)msg {
    %orig;
    if ([msg isKindOfClass:%c(CMessageWrap)]) {
        NSString *peer = [HEStore.shared addMessage:msg];
        if (peer) [HEUI maybeAutoSuggest:peer];
    }
}
- (void)MessageSvrDidAddMsg:(id)msg {
    %orig;
    if ([msg isKindOfClass:%c(CMessageWrap)]) {
        NSString *peer = [HEStore.shared addMessage:msg];
        if (peer) [HEUI maybeAutoSuggest:peer];
    }
}
- (void)AddLocalMsg:(id)msg {
    %orig;
    if ([msg isKindOfClass:%c(CMessageWrap)]) [HEStore.shared addMessage:msg];
}
- (void)AddMsg:(id)arg1 MsgWrap:(id)msg {
    %orig;
    if ([msg isKindOfClass:%c(CMessageWrap)]) [HEStore.shared addMessage:msg];
}
%end

// 聊天界面加悬浮球
%hook BaseMsgContentViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (HEConfig.enabled) [HEUI installButtonOn:self];
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIButton *btn = (UIButton *)[self.view viewWithTag:kButtonTag];
    if (btn) {
        btn.frame = CGRectMake(self.view.bounds.size.width - 62,
                               self.view.bounds.size.height - 160, 44, 44);
    }
}
%end

// 收到消息时自动建议（可在设置里开关）
%ctor {
    %init;
    NSLog(@"[HighEQReply] loaded, persona length: %lu", (unsigned long)HEConfig.persona.length);
}
