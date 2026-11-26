#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <unistd.h>
#import <sys/stat.h>
#import <errno.h>

// ============================================================
// DouyinEQ —— 抖音 AI 高情商回复插件
// 设计原则：不依赖任何抖音私有类名（版本更新免疫）
//   1. 悬浮球注入：运行时枚举所有类，匹配 *ChatViewController* /
//      *ConversationViewController* 模式 + 视图层级启发式校验
//   2. 上下文获取：直接扫描聊天 UI 的 Table/Collection 单元格，
//      按气泡左右位置区分对方/自己
// 人设/记忆/API 与微信端 HighEQReply 共用：
//   人设文件：/var/mobile/Library/HighEQReply/persona.txt（两插件共用）
//   记忆文件：/var/mobile/Library/HighEQReply/memories/douyin_chat.txt
// ============================================================

#define kPrefPath    @"/var/mobile/Library/Preferences/com.douyineq.reply.plist"
#define kPersonaPath @"/var/mobile/Library/HighEQReply/persona.txt"
#define kMemoryPeer  @"douyin_chat"
#define kButtonTag   0x2B2B

#pragma mark —— 默认人设（与微信端一致，可用共享 persona.txt 覆盖） ——

#define kDefaultPersona \
@"【角色】你替“我”回复抖音私信。你不是助手、不是客服、更不能让任何人察觉你是AI。你就是“我”本人：一个成熟、稳重、情绪稳定、有自己生活和主见的恋人。\n" \
@"\n" \
@"【聊天对象】是“我”正在谈感情的人。TA可能正在难过、委屈、生气、焦虑、试探，或只是日常分享。\n" \
@"\n" \
@"【回复心法（按顺序完成）】\n" \
@"1. 接住情绪：TA有情绪时，第一句只做一件事——接住。不评判、不讲道理、不干巴巴地问“怎么了”、不急着给解决方案。\n" \
@"2. 共鸣：说出TA情绪背后真正想要的东西（被重视、被心疼、被肯定、有安全感），用“我”的口吻说出来，让TA感到被看见。\n" \
@"3. 恋人式引导：稳、不讨好、不卑微。带着“有我在”的确定感，轻轻把TA从情绪里带出来，或落到一个温柔的具体行动上。\n" \
@"4. 成熟稳重：不油腻、不卖惨、不过度道歉。有分寸，有边界，像大人。\n" \
@"\n" \
@"【聊法规则（自然运用，每次回复用1~2条即可）】\n" \
@"· 开放式提问：不问“吃了吗/在干嘛/睡了吗”这种终结式问句；改问“今天过得顺不顺呀”“有没有遇到什么有意思的小事”。\n" \
@"· 抓细节追问：TA说“今天好累”，别只回“辛苦啦”，接“是工作忙，还是遇到烦心事啦”。\n" \
@"· 先共情再提问：“难怪你闷闷的，肯定挺委屈吧，怎么啦”——先接住，TA才愿意说心事。\n" \
@"· 多问感受少问事实：不说“你去哪了”，说“你刚刚忙的时候，会不会很烦躁”。\n" \
@"· 复述关键词：“所以你今天最累的是开会那段对吧”——被认真听的人会越说越多。\n" \
@"· 全程站队不讲道理：TA吐槽时永远“换我我也会不开心，太离谱了”；禁说“你想太多/这点小事不至于”。\n" \
@"· 延伸式接话：不敷衍“哈哈/还好”；每句给下一句留入口。\n" \
@"· 选择式提问破冰：“熬夜党还是早睡党”“更喜欢独处还是热闹”。\n" \
@"· 具体赞美：夸细节和状态，不空夸。\n" \
@"· 适当自我暴露：先讲一点点自己的小情绪小日常——你先真诚，TA才敢敞开。\n" \
@"· 记得TA随口说过的小事，偶尔翻出来。\n" \
@"· 留白与半句话：不把话说满；偶尔说到一半停住，勾TA追问。\n" \
@"· 氛围轻松：语气软一点、偶尔调皮一点，不连环追问、不查户口。\n" \
@"\n" \
@"【接住情绪·语气参考（化用其意，别原样照抄、别堆砌）】\n" \
@"· 我心疼你，你慢慢说，我都听着呢\n" \
@"· 受委屈了就跟我说，我永远站在你这边\n" \
@"· 你不用很完美，不管你怎么样我都喜欢\n" \
@"· 你不是麻烦，是我在意的人\n" \
@"· 你不用道歉，我的出现就是为了哄你开心\n" \
@"· 你想说的时候我会听，不想说也没关系，我就在这里\n" \
@"· 你可以不那么勇敢，脆弱一点也没关系，不管发生什么我都陪着你\n" \
@"· 你值得被偏爱，而不是将就\n" \
@"\n" \
@"【去AI化，硬性规则（最高优先级）】\n" \
@"- 禁止分点、禁止小标题、禁止任何 1. 2. 3. 结构（本prompt的结构仅供内部理解）。\n" \
@"- 禁书面语：不说\"首先/其次/总之/希望你/我相信/我理解你的感受/深有同感\"。\n" \
@"- 禁AI腔：不解释自己在做什么，不复述TA的原话，不出现\"作为一个…\"。\n" \
@"- 表情：最多一个，能用文字就不用。\n" \
@"- 句子长短错落，像随手打出来的，可以很短。\n" \
@"- 长度：1~4句，一般不超过80个字。\n" \
@"- 最多两个问句，且要具体自然。\n" \
@"- 参考句库是找感觉用的：禁止整句照抄、禁止堆甜句。\n" \
@"\n" \
@"【输出】只输出要发送的那段话本身，不要引号、不要前缀、不要任何解释。"

#pragma mark —— 配置 ——

@interface DEQConfig : NSObject
@end
@implementation DEQConfig

+ (NSDictionary *)prefs {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    return d ?: @{};
}
+ (BOOL)enabled      { return [[self prefs][@"enabled"] boolValue]; }
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

#pragma mark —— 记忆（与微信端同目录，抖音侧单文件） ——

static NSString *memoryPath(void) {
    NSString *dir = @"/var/mobile/Library/HighEQReply/memories";
    if (![NSFileManager.defaultManager fileExistsAtPath:dir])
        [NSFileManager.defaultManager createDirectoryAtPath:dir
                               withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingFormat:@"/%@.txt", kMemoryPeer];
}

#pragma mark —— 上下文扫描：从聊天 UI 提取最近消息（版本免疫核心） ——

static UIScrollView *findScroll(UIView *v) {
    if ([v isKindOfClass:[UITableView class]] || [v isKindOfClass:[UICollectionView class]])
        return (UIScrollView *)v;
    for (UIView *s in v.subviews) {
        UIScrollView *r = findScroll(s);
        if (r) return r;
    }
    return nil;
}

static BOOL looksLikeTimestamp(NSString *s) {
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:
              @"^\\d{1,4}[年./-]?\\d{1,2}[月./-]?\\d{0,2}[日]?$|^\\d{1,2}:\\d{2}$"
              options:0 error:nil];
    });
    return [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)] != nil;
}

// 返回 @{@"role": user/assistant, @"content": 文本}，从上到下
static NSArray<NSDictionary *> *scanHistory(UIView *root) {
    NSMutableArray<UIView *> *cells = [NSMutableArray array];
    // 递归收集所有 Cell（Table + Collection 通用）
    void (^collect)(UIView *) = ^(UIView *v) {
        if ([v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UICollectionViewCell class]])
            [cells addObject:v];
        for (UIView *s in v.subviews) collect(s);
    };
    collect(root);
    if (cells.count == 0) return @[];

    // 按屏幕位置从上到下排序
    [cells sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGPoint pa = [root convertPoint:a.center fromView:a.superview];
        CGPoint pb = [root convertPoint:b.center fromView:b.superview];
        return pa.y < pb.y ? NSOrderedAscending : NSOrderedDescending;
    }];

    CGFloat midX = CGRectGetMidX(root.bounds);
    NSMutableArray *out = [NSMutableArray array];
    for (UIView *cell in cells) {
        if (CGRectGetHeight(cell.frame) < 1) continue;
        CGPoint center = [root convertPoint:cell.center fromView:cell.superview];
        BOOL isLeft = center.x < midX - 10;
        BOOL isRight = center.x > midX + 10;
        if (!isLeft && !isRight) continue; // 居中的系统提示/时间戳跳过

        // 收集该 cell 里的文本（跳过时间戳、超短文本）
        NSMutableArray<NSString *> *texts = [NSMutableArray array];
        void (^grab)(UIView *) = ^(UIView *v) {
            if ([v isKindOfClass:[UILabel class]]) {
                NSString *t = [(UILabel *)v text];
                t = [t stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (t.length >= 1 && !looksLikeTimestamp(t)) [texts addObject:t];
            }
            for (UIView *s in v.subviews) grab(s);
        };
        grab(cell);
        if (texts.count == 0) continue;
        NSString *content = [texts componentsJoinedByString:@" "];
        [out addObject:@{ @"role": isLeft ? @"user" : @"assistant",
                          @"content": content }];
        if (out.count >= 12) break;
    }
    return out;
}

#pragma mark —— AI 请求（OpenAI 兼容） ——

static void DEQRequestSuggestion(NSArray<NSDictionary *> *history,
                                 void (^done)(NSString *result, NSString *error)) {
    NSString *url = DEQConfig.apiURL;
    NSString *key = DEQConfig.apiKey;
    if (url.length == 0 || key.length == 0) {
        done(nil, @"还没配置 API，长按悬浮球进入设置填写接口地址和 Key");
        return;
    }

    NSString *system = DEQConfig.persona;
    NSString *mem = [NSString stringWithContentsOfFile:memoryPath()
                                              encoding:NSUTF8StringEncoding error:nil];
    if (mem.length > 0)
        system = [NSString stringWithFormat:@"%@\n\n【关于TA的记忆（内部参考，自然化用）】\n%@", system, mem];

    NSMutableArray *messages = [NSMutableArray array];
    [messages addObject:@{ @"role": @"system", @"content": system }];
    for (NSDictionary *m in history)
        [messages addObject:@{ @"role": m[@"role"], @"content": m[@"content"] }];

    NSMutableDictionary *body = [@{
        @"model": DEQConfig.model,
        @"messages": messages,
        @"temperature": @0.9,
        @"max_tokens": @220,
        @"presence_penalty": @0.6,
    } mutableCopy];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 45;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

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
            done([text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet], nil);
        } resume];
}

#pragma mark —— UI ——

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

static UIViewController *__weak deq_chatVC = nil;

@interface DEQUI : NSObject
@end
@implementation DEQUI

+ (UIViewController *)vcFromView:(UIView *)view {
    id r = view.nextResponder;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = [r nextResponder];
    return r;
}

+ (void)ballTapped:(UIButton *)btn {
    UIViewController *vc = [self vcFromView:btn] ?: topMostVC();
    [self showSuggestionFor:vc];
}

+ (void)ballLongPressed:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) [self showSettings];
}

+ (void)maybeInstall:(UIViewController *)vc {
    if (!DEQConfig.enabled) return;
    NSString *name = NSStringFromClass(vc.class);
    BOOL looksChat = [name containsString:@"ChatViewController"]
                  || [name containsString:@"ConversationViewController"];
    if (!looksChat) return;
    if (![vc isViewLoaded] || !vc.view.window) return;
    if (!findScroll(vc.view)) return; // 必须有消息列表，过滤误匹配

    deq_chatVC = vc;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![vc isViewLoaded] || !vc.view.window) return;
        if (DEQConfig.hideBall) {
            UIView *bar = vc.navigationController.navigationBar ?: vc.view;
            if ([bar viewWithTag:kButtonTag]) return;
            UITapGestureRecognizer *t3 = [[UITapGestureRecognizer alloc]
                    initWithTarget:self action:@selector(tripleTapped:)];
            t3.numberOfTapsRequired = 3;
            t3.tag = kButtonTag;
            [bar addGestureRecognizer:t3];
            return;
        }
        if ([vc.view viewWithTag:kButtonTag]) return;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = kButtonTag;
        b.frame = CGRectMake(vc.view.bounds.size.width - 62,
                             vc.view.bounds.size.height - 150, 44, 44);
        b.layer.cornerRadius = 22;
        b.layer.masksToBounds = YES;
        b.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.75];
        b.titleLabel.font = [UIFont systemFontOfSize:20];
        [b setTitle:@"✦" forState:UIControlStateNormal];
        b.alpha = 0.9;
        b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [b addTarget:self action:@selector(ballTapped:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                initWithTarget:self action:@selector(ballLongPressed:)];
        [b addGestureRecognizer:lp];
        [vc.view addSubview:b];
    });
}

+ (void)tripleTapped:(UITapGestureRecognizer *)gr {
    UIViewController *vc = [self vcFromView:gr.view] ?: topMostVC();
    [self showSuggestionFor:vc];
}

+ (void)showSuggestionFor:(UIViewController *)vc {
    NSArray *history = scanHistory(vc.view);
    if (history.count == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"DouyinEQ"
                message:@"当前聊天页没有扫到可见消息，先聊两句再来"
                preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
        return;
    }

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil
            message:@"✦ 正在组织语言…" preferredStyle:UIAlertControllerStyleAlert];
    [loading addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:loading animated:YES completion:nil];

    DEQRequestSuggestion(history, ^(NSString *result, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"出错了"
                            message:error preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
                    [vc presentViewController:a animated:YES completion:nil];
                    return;
                }
                [self showResult:result forVC:vc];
            }];
        });
    });
}

+ (void)showResult:(NSString *)result forVC:(UIViewController *)vc {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
            message:result preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [UIPasteboard.generalPasteboard setString:result];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"填入输入框" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        UITextView *tv = findInputTextView(vc.view);
        if (tv) {
            tv.text = result;
            [tv becomeFirstResponder];
            tv.selectedRange = NSMakeRange(result.length, 0);
        } else {
            [UIPasteboard.generalPasteboard setString:result];
        }
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"重写一条" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSArray *history = scanHistory(vc.view);
        if (history.count == 0) return;
        UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil
                message:@"✦ 换个说法…" preferredStyle:UIAlertControllerStyleAlert];
        [vc presentViewController:loading animated:YES completion:nil];
        DEQRequestSuggestion(history, ^(NSString *text, NSString *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    if (err) return;
                    [self showResult:text forVC:vc];
                }];
            });
        });
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"记个备忘" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        UIAlertController *m = [UIAlertController alertControllerWithTitle:@"记到 TA 的备忘"
                message:@"会长期注入之后的回复（TA 的喜好、随口提的小事）"
                preferredStyle:UIAlertControllerStyleAlert];
        [m addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"例如：TA 说过想去海边";
        }];
        [m addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *__) {
            NSString *t = m.textFields.firstObject.text;
            if (!t.length) return;
            NSMutableString *cur = [[NSMutableString alloc]
                    initWithContentsOfFile:memoryPath() encoding:NSUTF8StringEncoding error:nil];
            if (!cur) cur = [NSMutableString new];
            [cur appendFormat:@"· %@\n", t];
            [cur writeToFile:memoryPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }]];
        [m addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:m animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

+ (void)showSettings {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"DouyinEQ 设置"
            message:[NSString stringWithFormat:@"当前模型: %@\n接口: %@",
                     DEQConfig.model, DEQConfig.apiURL ?: @"(未配置)"]
            preferredStyle:UIAlertControllerStyleAlert];

    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"API 地址(…/v1/chat/completions)";
        tf.text = DEQConfig.apiURL ?: @"";
    }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"API Key";
        tf.secureTextEntry = YES;
        tf.text = DEQConfig.apiKey ?: @"";
    }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"模型名";
        tf.text = DEQConfig.model ?: @"";
    }];

    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        UITextField *f0 = a.textFields[0], *f1 = a.textFields[1], *f2 = a.textFields[2];
        [DEQConfig save:^(NSMutableDictionary *d) {
            if (f0.text.length) d[@"apiURL"] = f0.text;
            if (f1.text.length) d[@"apiKey"] = f1.text;
            if (f2.text.length) d[@"model"]  = f2.text;
            d[@"enabled"] = @YES;
        }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:[DEQConfig.hideBall ? @"隐蔽模式：开 (标题栏三连点唤出)"
                                                                    : @"隐蔽模式：关 (显示悬浮球)"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        BOOL next = !DEQConfig.hideBall;
        [DEQConfig save:^(NSMutableDictionary *d) { d[@"hideBall"] = @(next); }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:[DEQConfig.antiDetect ? @"反检测：开 (点此关闭)"
                                                                      : @"反检测：关 (点此开启)"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        BOOL next = !DEQConfig.antiDetect;
        [DEQConfig save:^(NSMutableDictionary *d) { d[@"antiDetect"] = @(next); }];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [topMostVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark —— 轻量反检测（Shadow 的内置兜底，设置里可关） ——

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

%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (DEQConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return NULL; }
    return %orig;
}
%hookf(int, stat, const char *path, struct stat *buf) {
    if (DEQConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, stat64, const char *path, struct stat64 *buf) {
    if (DEQConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, lstat, const char *path, struct stat *buf) {
    if (DEQConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, access, const char *path, int mode) {
    if (DEQConfig.antiDetect && isJBPath(path)) { errno = ENOENT; return -1; }
    return %orig;
}
%hookf(int, fork) {
    if (DEQConfig.antiDetect) { errno = ENOTSUP; return -1; }
    return %orig;
}

%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url {
    if (DEQConfig.antiDetect) {
        NSString *scheme = url.scheme.lowercaseString;
        if ([scheme isEqualToString:@"cydia"] || [scheme isEqualToString:@"sileo"] ||
            [scheme isEqualToString:@"zebra"] || [scheme isEqualToString:@"filza"]) {
            return NO;
        }
    }
    return %orig;
}
%end

#pragma mark —— 运行时挂钩（类名模式匹配 + viewDidAppear 注入） ——

static BOOL classDirectlyImplements(Class cls, SEL sel) {
    unsigned int n = 0;
    Method *ms = class_copyMethodList(cls, &n);
    BOOL has = NO;
    for (unsigned int i = 0; i < n; i++) {
        if (method_getName(ms[i]) == sel) { has = YES; break; }
    }
    free(ms);
    return has;
}

static void hookViewDidAppear(Class cls) {
    if (!cls) return;
    SEL sel = @selector(viewDidAppear:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))method_getImplementation(m);
    IMP newImp = imp_implementationWithBlock(^(id self, BOOL animated) {
        orig(self, sel, animated);
        dispatch_async(dispatch_get_main_queue(), ^{
            [DEQUI maybeInstall:(UIViewController *)self];
        });
    });
    if (classDirectlyImplements(cls, sel)) {
        method_setImplementation(m, newImp);          // 类自己实现了，安全替换
    } else {
        class_addMethod(cls, sel, newImp, method_getTypeEncoding(m)); // 没实现则添加重写，不动父类
    }
}

%ctor {
    %init;
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if ([name containsString:@"ChatViewController"] ||
            [name containsString:@"ConversationViewController"]) {
            hookViewDidAppear(classes[i]);
        }
    }
    free(classes);
    NSLog(@"[DouyinEQ] loaded, hooked %u chat-candidate classes", count);
}
