//
//  MoreAboutFeedbackViewController.m
//  browser
//
//  Created by liguiyang on 14-6-19.
//
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define TAG_ABOUT_BUTTON 1221
#define TAG_ABOUT_BACKBUTTON 1226
#define TAG_OTHER 8888

#define TAG_OFFICIAL_LABEL 1222
#define TAG_FORUM_LABEL 1223
#define TAG_WEIBO_LABEL 1224
#define TAG_WEIXIN_LABEL 1225


#import "MoreAboutViewController.h"
#import "UsageAgreementViewController.h"
#import "CustomNavigationBar.h"
#import "UITouchLabel.h"

@interface MoreAboutViewController ()<UITouchLabelDelegate,CustomNavigationBarDelegate>
{
    UIColor *defaultColor;
    UIColor *lineColor;
    UIColor *linkColor;
    
    // 关于
    UIImageView *iconImageView;
    UILabel *kyNameLabel;
    UILabel *versionLabel;
    
    // 中间模块
    UIView *middleView;
    UITouchLabel *officialWebLabel;
    UITouchLabel *forumWebLabel;
    UIImageView  *weiboImgView;
    UIImageView  *weixinImgView;
    UITouchLabel *weiboLabel;
    UITouchLabel *weiXinLabel;
    UIView *weiboLineView;
    UIView *weiXinLineView;
    UILabel *lineLabel;
    
    //
    UILabel *discribeLabel;
    UIImageView *copyrightImageView;
    //
    NSAttributedString *rightTopBtnTitle;
    CustomNavigationBar *navBar;
}

@end

@implementation MoreAboutViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        defaultColor = [UIColor colorWithRed:85.0/255.0 green:85.0/255.0 blue:85.0/255.0 alpha:1.0];
        lineColor = [UIColor colorWithRed:210.0/255.0 green:210.0/255.0 blue:210.0/255.0 alpha:1.0];
        linkColor = [UIColor colorWithRed:50.0/255.0 green:150.0/255.0 blue:220.0/255.0 alpha:1.0];
        self.view.backgroundColor = [UIColor colorWithRed:241.0/255.0 green:240.0/255.0 blue:246.0/255.0 alpha:1.0];
    }
    return self;
}

-(void)initAboutView
{
    UIFont *font = [UIFont systemFontOfSize:15.0f];
    //
    iconImageView = [[UIImageView alloc] init];
    SET_IMAGE(iconImageView.image, @"more_logo.png");
    iconImageView.layer.cornerRadius = 12.0f;
    iconImageView.clipsToBounds = YES;
    
    kyNameLabel = [self getLabel];
    kyNameLabel.font = [UIFont systemFontOfSize:20.0f];
    kyNameLabel.textColor = [UIColor colorWithRed:85.0/255.0 green:85.0/255.0 blue:85.0/255.0 alpha:1];
    kyNameLabel.text = @"应用宝贝";
    
    versionLabel = [self getLabel];
    versionLabel.font = font;
    versionLabel.textColor = MY_BLUE_COLOR;
    versionLabel.text = [self getVersionString];
    
//    // 中间模块
//    middleView = [[UIView alloc] init];
//    
//    officialWebLabel = [self getTouchLabel];
//    officialWebLabel.attributedText = [self getTwoColorStringWithString:@" 官网：http://www.kuaiyong.com"];
//    officialWebLabel.tag = TAG_OFFICIAL_LABEL;
//    UILabel *lineOffcial = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, officialWebLabel.frame.size.width, 0.5)];
//    lineOffcial.backgroundColor = lineColor;
//    [officialWebLabel addSubview:lineOffcial];
//    
//    forumWebLabel = [self getTouchLabel];
//    forumWebLabel.attributedText = [self getTwoColorStringWithString:@" 论坛：www.kuaiyongbbs.com/forum.php"];
//    forumWebLabel.tag = TAG_FORUM_LABEL;
//    UILabel *lineForum = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, forumWebLabel.frame.size.width, 0.5)];
//    lineForum.backgroundColor = lineColor;
//    [forumWebLabel addSubview:lineForum];
//    
//    weiboImgView = [[UIImageView alloc] init];
//    SET_IMAGE(weiboImgView.image, @"about_weibo.png");
//    weiboLabel = [self getTouchLabel];
//    weiboLabel.attributedText = [self getDefaultColorStringWithString:@" 微博：快用苹果助手"];
//    weiboLabel.tag = TAG_WEIBO_LABEL;
//    weiboLineView = [self getLineView];
//    [weiboLineView addSubview:weiboLabel];
//    [weiboLineView addSubview:weiboImgView];
//    
//    weixinImgView = [[UIImageView alloc] init];
//    SET_IMAGE(weixinImgView.image, @"about_weixin.png");
//    weiXinLabel = [self getTouchLabel];
//    weiXinLabel.attributedText = [self getDefaultColorStringWithString:@" 微信：快用苹果助手"];
//    weiXinLabel.tag = TAG_WEIXIN_LABEL;
//    weiXinLineView = [self getLineView];
//    [weiXinLineView addSubview:weixinImgView];
//    [weiXinLineView addSubview:weiXinLabel];
//    
//    lineLabel = [[UILabel alloc] init];
//    lineLabel.backgroundColor = lineColor;
//    
//    // 底部模块
//    discribeLabel = [self getLabel];
//    discribeLabel.textColor = defaultColor;
//    discribeLabel.font = [UIFont systemFontOfSize:15.0f];
//    discribeLabel.text = @"免费/免越狱\n随时随地  下载海量苹果APP";
    
    copyrightImageView = [[UIImageView alloc] init];
    SET_IMAGE(copyrightImageView.image, @"more_about_copyright.png");
    
    // addsubView
    [self.view addSubview:iconImageView];
    [self.view addSubview:kyNameLabel];
    [self.view addSubview:versionLabel];
//    [self.view addSubview:officialWebLabel];
//    [self.view addSubview:forumWebLabel];
//    [self.view addSubview:weiboLineView];
//    [self.view addSubview:weiXinLineView];
//    [self.view addSubview:lineLabel];
//    [self.view addSubview:discribeLabel];
    [self.view addSubview:copyrightImageView];
}

#pragma mark - Utility

-(void)backMoreVC
{
    [self.navigationController popViewControllerAnimated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:HIDETABBAR object:[NSNumber numberWithBool:NO]];
}

-(void)pushUsageAgreementVC
{
    UsageAgreementViewController *usageAgreementVC = [[UsageAgreementViewController alloc] init];
    [self.navigationController pushViewController:usageAgreementVC animated:YES];
}

-(NSString *)getVersionString
{// 版本号
    NSDictionary *tmpDic = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"build" ofType:@"plist"]];
    NSString *localVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *version = [NSString stringWithFormat:@"V %@(%d)",localVersion, [[tmpDic objectForKey:@"build"] intValue]];
    return version;
}

-(NSAttributedString *)getTwoColorStringWithString:(NSString *)string
{ // 链接文字
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:string];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:defaultColor} range:NSMakeRange(0, 4)];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:linkColor} range:NSMakeRange(4, attrStr.length-4)];
    return attrStr;
}

-(NSAttributedString *)getDefaultColorStringWithString:(NSString *)string
{ //
    NSDictionary *attDic = @{NSForegroundColorAttributeName:defaultColor};
    NSAttributedString *attStr = [[NSMutableAttributedString alloc] initWithString:string attributes:attDic];
    return attStr;
}

-(UILabel *)getLabel
{ // 创建普通UILabel
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    
    return label;
}

-(UITouchLabel *)getTouchLabel
{
    CGRect rect = [UIScreen mainScreen].bounds;
    UITouchLabel *touchLabel = [[UITouchLabel alloc] initWithFrame:CGRectMake(15, 0, rect.size.width-15, 44)];
    touchLabel.textAlignment = NSTextAlignmentLeft;
    touchLabel.delegate = self;
    touchLabel.font = [UIFont systemFontOfSize:15.0f];
    
    return touchLabel;
}

-(UIView *)getLineView
{
    CGRect rect = [UIScreen mainScreen].bounds;
    UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(19, 0, rect.size.width-19, 44)];
    
    UILabel *line = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, lineView.frame.size.width, 0.5f)];
    line.backgroundColor = lineColor;
    [lineView addSubview:line];
    
    return lineView;
}

-(void)copyStringToPasteboard:(NSString *)string
{
    [[UIPasteboard generalPasteboard] setPersistent:YES];
    [[UIPasteboard generalPasteboard] setString:string];
}

-(void)setCustomFrame
{
    CGRect rect = [UIScreen mainScreen].bounds;
    CGFloat topHeight = IOS7?64:0;
    CGRect labelFrame = officialWebLabel.frame;
    
    CGFloat width = rect.size.width;
    labelFrame.size.height = 32*PHONE_SCALE_PARAMETER;
    iconImageView.frame = CGRectMake((rect.size.width-108)*0.5, (80+topHeight)*PHONE_SCALE_PARAMETER, 108, 108);
    kyNameLabel.frame = CGRectMake(0, iconImageView.frame.origin.y+iconImageView.frame.size.height+27*PHONE_SCALE_PARAMETER, width, 22*PHONE_SCALE_PARAMETER);
    versionLabel.frame = CGRectMake(0, kyNameLabel.frame.origin.y+kyNameLabel.frame.size.height+3*PHONE_SCALE_PARAMETER, width, 15*PHONE_SCALE_PARAMETER);
    
//    labelFrame.origin.y = versionLabel.frame.origin.y+versionLabel.frame.size.height+24*scale;
//    officialWebLabel.frame = labelFrame;
//    
//    labelFrame.origin.y = labelFrame.origin.y+labelFrame.size.height+1;
//    forumWebLabel.frame = labelFrame;
//    
//    labelFrame.origin.y = labelFrame.origin.y+labelFrame.size.height+1;
//    weiboLineView.frame = labelFrame;
//    weiboImgView.frame = CGRectMake(5, (labelFrame.size.height-20)*0.5, 20, 20);// weiboImgView、weiboLabel是weiboLineView的子view
//    weiboLabel.frame = CGRectMake(26, 0, labelFrame.size.width-26, labelFrame.size.height);
//    
//    labelFrame.origin.y = labelFrame.origin.y+labelFrame.size.height+1;
//    weiXinLineView.frame = labelFrame;
//    weixinImgView.frame = CGRectMake(5, (labelFrame.size.height-20)*0.5, 20, 20);// weiXinImgView、weiXinLabel是weiXinLineView的子view
//    weiXinLabel.frame = CGRectMake(26, 0, labelFrame.size.width-26, labelFrame.size.height);
//    
//    labelFrame.origin.y = labelFrame.origin.y+labelFrame.size.height+0.5;
//    labelFrame.size.height = 0.5;
//    lineLabel.frame = labelFrame;
//    
//    discribeLabel.frame = CGRectMake(0, MainScreeFrame.size.height-93, width, 40);
    copyrightImageView.frame = CGRectMake((width-248)*0.5, MainScreeFrame.size.height-43, 248, 23);
}

#pragma mark - UITouchLabelDelegate

-(void)tapTouchLabel:(UILabel *)touchLabel
{
    switch (touchLabel.tag) {
        case TAG_OFFICIAL_LABEL:{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.kuaiyong.com"]];
        }
            break;
        case TAG_FORUM_LABEL:{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.kuaiyongbbs.com/forum.php"]];
        }
            break;
        case TAG_WEIBO_LABEL:{
            [self copyStringToPasteboard:@"应用宝贝"];
            NSLog(@"weiBO 应用宝贝 拷贝至粘贴板");
        }
            break;
        case TAG_WEIXIN_LABEL:{
            [self copyStringToPasteboard:@"应用宝贝"];
            NSLog(@"weiXIN 应用宝贝 拷贝至粘贴板");
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - CustomNavigationBarDelegate

-(void)popCurrentViewController
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Life Cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // navigationBar
    navBar = [[CustomNavigationBar alloc] init];
    [navBar showBackButton:YES navigationTitle:@"关于" rightButtonType:rightButtonType_ONE];
    navBar.delegate = self;
    //新春版
//    NSDictionary *titleAttrDic = @{NSForegroundColorAttributeName:TOP_RED_COLOR,NSFontAttributeName:[UIFont systemFontOfSize:16.0]};
//    rightTopBtnTitle = [[NSAttributedString alloc] initWithString:@"使用协议" attributes:titleAttrDic];
//    [navBar.rightTopButton setAttributedTitle:rightTopBtnTitle forState:UIControlStateNormal];
//    [navBar.rightTopButton addTarget:self action:@selector(pushUsageAgreementVC) forControlEvents:UIControlEventTouchUpInside];
    
    // mainView
    [self initAboutView];
    
    [self setCustomFrame];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.hidesBackButton = YES;
    [self.navigationController.navigationBar addSubview:navBar];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [navBar removeFromSuperview];
    if (self.navigationController.viewControllers.count==1) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HIDETABBAR object:[NSNumber numberWithBool:NO]];
    }
}
- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
