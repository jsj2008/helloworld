//
//  IphoneAppDelegate.m
//  browser
//
//  Created by 毅 王 on 12-9-11.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//
#import "IphoneAppDelegate.h"
#import "SDImageCache.h"
#import "ReportManage.h"
#import "FileUtil.h"
#import "BppDistriPlistManager.h"
#import "AppStatusManage.h"
#import "ResourceIPhoneBrowserViewController.h"
#import "BppDownloadToLocal.h"
#import "SearchManager.h"
#import "MarketServerManage.h"
#import "RealtimeShowAdvertisement.h"
#import "DownloadReport.h"
#import "AfterLaunchPopView.h"
#import "Reachability.h"
#import "MobClick.h" // UM SDK
#import "UIApplication+MS.h" // 3/4G/WiFi...

#import "SSLServer.h"
#import "NSDictionary+noNIL.h"
#import<AssetsLibrary/AssetsLibrary.h>//访问相册
#import <objc/runtime.h>
#import "webserver.h"
#import "webserver_notifications.h"

#import "UserActiveLog.h"

#import "BackgroundAudio.h"

#import "UIWebClip.h"
#import "AppStoreNewDownload.h"
#import "LoginServerManage.h"
#import "BPush.h"
#import "AppStatusManage.h"

#import "AppUpdateNewVersion.h"

#import "ViewController.h"

#define  ALERTVIEW_TAG_INSTALL_ON_IPAD  100


@interface IphoneAppDelegate () <BppDistriPlistManagerControlDelegate> {
    

    NSInteger pcToIOSMediaNum;
    
    Reachability  *hostReach;
    
    webServer * httpServer;
    
    UIBackgroundTaskIdentifier taskIdentifier;
    
    NSString *tmpDistriURL;//非wifi下载时的临时变量
    NSDictionary *tmpInforDic;//非wifi下载时的临时变量
    
    NSDictionary *remotePushInfor;//远程推送内容
}

@property (nonatomic, retain) SSLServer * sslServ;


@end



@implementation IphoneAppDelegate

@synthesize window = _window;
@synthesize sslServ;


- (id)init{
    
    self = [super init];
    if(self){
        self.isBackGround = NO;
        
        taskIdentifier = nil;
        self.sslServ = nil;
        
        //设置控制流程代理
        [BppDistriPlistManager getManager].controlDelegate = self;
    }
    
    return self;
}

- (void)dealloc
{
    hostReach = nil;
}
#pragma mark - 保存log日志
- (void)redirectNSlogToDocumentFolder
{

    NSString *documentDirectory = [[FileUtil instance] getDocumentsPath];
    NSString *logFilePath = [documentDirectory stringByAppendingPathComponent:@"log.log"];
    // 先删除已经存在的文件
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:logFilePath error:nil];
    
    // 将log输入到文件
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}




//class_replaceMethod(objc_getMetaClass("SBFWallpaperOptions"), @selector(optionsWithName:parallaxFactor:zoomScale:supportsCropping:cropRect:), optionsWithName, "@40@0:4@8f12f16c20{CGRect={CGPoint=ff}{CGSize=ff}}24");
//static void optionsWithName(id self, SEL releaseSelector, id arg1, double arg2, double arg3, bool arg4, CGRect arg5) {
//    NSLog(@"Release called on an NSTableView");
//}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //判断是否安全包
    
#if (URL_TYPE == 1)
    self.isSafeURL = YES;
#else
    self.isSafeURL = NO;
#endif
    
    
    {
        //Then somewhere do this:
        NSLog(@"launchOptions:%@", launchOptions);
        NSLog(@"BundlePath: %@", [NSBundle mainBundle].bundlePath);
        NSLog(@"DocumentsPath: %@", [[FileUtil instance] getDocumentsPath] );
    }
    
    [[FileUtil instance] saveFileToPC];
    
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//        
//        BOOL isInstallKKK = [[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString:@"kkbrowser://"]];
//        
//        if ([[FileUtil instance] isJailbroken] && isInstallKKK == NO) {
//            
//            NSString *tmp = [[NSUserDefaults standardUserDefaults] objectForKey:@"kkkA"];
//            if (!tmp||[[[NSUserDefaults standardUserDefaults] objectForKey:@"kkkA"] isEqualToString:@"1"]) {
//                [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"kkkA"];
//                //获取3K助手下载地址
//                [[AppUpdateNewVersion shareInstance] requestKKKDownloadAdress];
//            }
//        }
//        
//    });

    //请求获取免费账号信息
    
    self.installingAppIDs = [NSMutableArray array];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[LoginServerManage getManager] requestAppleLoginSwitch];
    });
    
    
    [BppDistriPlistManager getManager].controlDelegate = self;
    
//    [self redirectNSlogToDocumentFolder];
    
    // 清理网页内存
    int cacheSizeMemory = 4*1024*1024; // 4MB
    int cacheSizeDisk = 32*1024*1024; // 32MB
    NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:sharedCache];
    
    {
//        // 友盟sdk数据统计
//        NSString * youmeng = [[NSBundle mainBundle] pathForResource:@"youmeng" ofType:@"plist"];
//        NSDictionary * youmengInfo = [NSDictionary dictionaryWithContentsOfFile:youmeng];
//        assert(youmengInfo
//               && [youmengInfo objectForKey:@"appkey"]
//               && [youmengInfo objectForKey:@"channelid"]);
//        
//        [MobClick startWithAppkey:[youmengInfo objectForKey:@"appkey"]
//                     reportPolicy:REALTIME
//                        channelId:[youmengInfo objectForKey:@"channelid"]];
//        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
//        [MobClick setAppVersion:version];
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self umengTrack];
        });
        
    }
    
    if (IOS7)
        //2.7
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];


    self.isBackGround = NO;
    
    //汇报启动日志
    [[ReportManage instance] ReportLaunch];


    
    [[SettingPlistConfig getObject] checkIphonePlistFile];
    [[DownloadReport getObject] checkPlistFile];
    {
        self.sslServ = [[SSLServer alloc] init];
        self.sslServ.basePath = [[FileUtil instance] getDocumentsPath];
        
        //修改起始端口
        self.sslPort = 4543;//4443
        int tryCount = 0;
        while ( 0 != [self.sslServ start:self.sslPort] //打开失败
               && tryCount < 50) {  //重试次数< 50
            self.sslPort += 2;
            tryCount ++;
        };
        
        NSLog(@"ssl bind:%d", self.sslPort);
        //ssl server通知: OTA请求plist
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNotification:)
                                                     name:HTTPS_SERVER_REQUEST_PLIST_OK_NOTIFICATION
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNotification:)
                                                     name:HTTPS_NEED_RESTART_SERVER
                                                   object:nil];
    }
    
    //启动照片导入服务
    server = [[PCServer alloc] init];
    
    //更改端口
    [server start:9200];//9000
    server.serverDelegate = self;
    
    {
        httpServer = [[webServer alloc] init];
        httpServer.rootPath = [[FileUtil instance] getDocumentsPath];
        
        //更改端口
        self.webserverPort = 8959;//8899
        int tryCount = 0;
        while( ![httpServer startServer:self.webserverPort] && tryCount < 50){
            self.webserverPort += 2;
            tryCount ++;
        }
        
        NSLog(@"http bind:%d", self.webserverPort);
        
        //webserver通知: 点击了安装按钮
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNotification:)
                                                     name:WEBSERVER_NOTIFICATION_REQUEST_DOWNLOAD_FILE
                                                   object:nil];
        //webserver通知: IPA下载完毕
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNotification:)
                                                     name:WEBSERVER_NOTIFICATION_DOWONLOAD_FILE_COMPLETE
                                                   object:nil];
    }
    
    //进入前台
    [self applicationWillEnterForeground:nil];
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    
    ViewController * controller = [[ViewController alloc] init];
    controller.view.frame = self.window.bounds;
    controller.view.autoresizesSubviews = YES;
    controller.view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    self.window.rootViewController = controller;
    
    
//    [controller->tmpPopView showWithDic:nil];
    
    NSDictionary *currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
    NSString *device = [UIDevice currentDevice].model;
    NSString * userAgent = [NSString stringWithFormat:
                                @"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/%@ Mobile/9B179 kuaiyongbrowser/%@",
                                device,device,
                            [UIDevice currentDevice].systemVersion,
                            [UIDevice currentDevice].systemVersion,
                            currentVersion];
    
    NSDictionary *dictionnary = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 userAgent, @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionnary];
    
    
    //自动下载IPA
    NSURL * launchOptionsURL = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if(launchOptionsURL) {
        //示例数据
        //kybrowser:itms-services://?action=download-manifest&url=https://dinfo.wanmeiyueyu.com/Data/APPINFOR/21/58/net.crimoon.pm.ky/dizigui_zhouyi_net.crimoon.pm.ky_1402329600_1.0.0.plist
        
        NSString *distriPlistURL = launchOptionsURL.resourceSpecifier;
        if( [distriPlistURL hasPrefix:@"itms-services"] ) {
            [self downloadIPAByPlistURL:distriPlistURL];
        }
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name: kReachabilityChangedNotification
                                               object: nil];
    hostReach = [Reachability reachabilityWithHostName:@"www.baidu.com"];
    [hostReach startNotifier];
    
    
    [self.window makeKeyAndVisible];
    [WXApi registerApp:WXAppID];
    [WeiboSDK registerApp:kAppKey];
    
    
     //BppDistriPlistManager 通知: 点击了安装或开始下载按钮
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_3GDataPrompt:)
                                                 name: DISTRI_PLIST_MANAGER_NOTIFICATION_ADD_OR_START_DOWNLOAD
                                               object: nil];

    //记录用户活动
    [UserActiveLog userLogin];
    
    UILocalNotification *notif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    
    NSDictionary*launchDic = notif.userInfo;
    if ([launchDic objectForKey:@"id"]) {
        [self openInfoPageForNotifi:launchOptions];
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:[launchDic objectForKey:@"push_type"],@"push_type",[launchDic objectForKey:@"push_type_info"],@"push_type_info", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:LOCAL_PUSH_DETAIL object:dic];
        
    }else if([launchDic objectForKey:@"downed"]){
        [[NSNotificationCenter defaultCenter] postNotificationName:LOCAL_PUSH_CLICK_OK object:nil];
    }
    
    
    NSDictionary *userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REMOTE_PUSH object:userInfo];
        NSLog(@"NNNNNNNNNNNNNNNNNNNNN");
    }
    
    
    
    
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [self RegisteredLocalNotification];
//    });
    
    //My助手注释闪退修复
    
//    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"repairky"]) {
//        UIAlertView *alert =[ [UIAlertView alloc]initWithTitle:nil message:@"主人，为了防止小快突然闪退，跪求安装\"快用自身修复\"程序，让小快安安稳稳的陪伴在您身边" delegate:self cancelButtonTitle:nil otherButtonTitles:@"立即安装",@"残忍拒绝", nil];
//        alert.tag = TAG_ALERTVIEW_INSTALLSFIX;
//        alert.delegate = self;
//        [alert show];
//        [[NSUserDefaults standardUserDefaults] setObject:@"yes" forKey:@"repairky"];
//    }
    
    //注册百度推送
    
    [BPush setupChannel:launchOptions]; // 必须
    
    [BPush setDelegate:self]; // 必须。参数对象必须实现onMethod: response:方法，本示例中为self
    
    // [BPush setAccessToken:@"3.ad0c16fa2c6aa378f450f54adb08039.2592000.1367133742.282335-602025"];  // 可选。api key绑定时不需要，也可在其它时机调用
    
    if (IOS8) {
        UIUserNotificationType myTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:myTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }else {
        UIRemoteNotificationType myTypes = UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound;
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:myTypes];
    }

    

//    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"yindaotu"]) {
//        [[NSUserDefaults standardUserDefaults] setObject:@"yindaotu" forKey:@"yindaotu"];
//        [self creatCustomWindow];
//    }
    if (launchOptions) {
        
        NSDictionary * userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        NSLog(@"jjjjj - userinfo-%@",userInfo);
        if(userInfo) {
            //            NSLog(@"通过消息推送进入\n %@",userInfo);
            _note = [[NSNotification alloc] initWithName:RECEIVE_NOTIFICATION_PUSH object:userInfo userInfo:nil];
        }else {
            _note = nil;
        }
        [application setApplicationIconBadgeNumber:0];
    }else {
        _note = nil;
    }
    
    //引导图显示
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(creatCustomWindow) name:@"yibujihuochangtu" object:nil];;
    }
    
    
    
    
    
    return YES;
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    completionHandler(UIBackgroundFetchResultNewData);
}


//itms-services://?action=download-manifest&url=https://dinfo.wanmeiyueyu.com/Data/APPINFOR/21/58/net.crimoon.pm.ky/dizigui_zhouyi_net.crimoon.pm.ky_1402329600_1.0.0.plist?appid=test.com&appname=%E6%88%91%E4%BB%AC&appversion=2.1.0.0&appiconurl=http%3A%2F%2Fwww.kuaiyong.com%2F1.png&dlfrom=123
//快速添加需要附带参数
//必须: appid 唯一标示符, appname 名称, appversion 版本, appiconurl 图标URL
//可选: dlfrom 来源
//说明: 所有参数值必须URL编码
- (void)downloadIPAByPlistURL:(NSString*)distriPlist {
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        
        
        NSString * plistURL = [[FileUtil instance] plistURLNoArg:distriPlist];
        if(plistURL.length <= 0)
            return ;
        
        
        NSString * appid = [[FileUtil instance] getPlistURLArg:distriPlist argName:@"appid"];
        appid = [[FileUtil instance] urlDecode:appid];
        if(!appid)
            appid = @"";
        
        NSString * appname = [[FileUtil instance] getPlistURLArg:distriPlist argName:@"appname"];
        appname = [[FileUtil instance] urlDecode:appname];
        if(!appname)
            appname = @"";
        
        NSString * appversion = [[FileUtil instance] getPlistURLArg:distriPlist argName:@"appversion"];
        appversion = [[FileUtil instance] urlDecode:appversion];
        if(!appversion)
            appversion = @"";
        
        
        NSString * appiconurl = [[FileUtil instance] getPlistURLArg:distriPlist argName:@"appiconurl"];
        appiconurl = [[FileUtil instance] urlDecode:appiconurl];
        if(!appiconurl)
            appiconurl = @"";

        NSString * dlfrom = [[FileUtil instance] getPlistURLArg:distriPlist argName:@"dlfrom"];
        dlfrom = [[FileUtil instance] urlDecode:dlfrom];
        if(!dlfrom)
            dlfrom = @"";

        
        NSDictionary * AppInfo = nil;
        //参数信息全， 快速添加下载
        if(appid.length > 0 &&
           appname.length > 0 &&
           appversion.length > 0 &&
           appiconurl.length > 0 ) {
            
            AppInfo = [NSDictionary dictionaryWithObjectsAndKeys:appid, DISTRI_APP_ID,
                                      appversion, DISTRI_APP_VERSION,
                                      appname, DISTRI_APP_NAME,
                                      appiconurl, DISTRI_APP_IMAGE_URL,
                                      dlfrom, DISTRI_APP_FROM, nil];
        }else {
            //参数信息不全， 慢速添加下载
            
            //下载plist
            NSDictionary * dicInfo = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:plistURL]];
            if(!dicInfo) {
                return ;
            }
            //分析plist
            __block NSString * imageURL = nil;
            NSArray *assets = [[[dicInfo objectForKey:@"items"] objectAtIndex:0] objectForKey:@"assets"];
            [assets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if( [[obj objectForKey:@"kind"] hasSuffix:@"image"] ) {
                    imageURL = [obj objectNoNILForKey:@"url"];
                }
            }];
            
            //获取应用信息
            NSDictionary * metadata = [[[dicInfo objectForKey:@"items"] objectAtIndex:0] objectForKey:@"metadata"];
            NSString * bundleIdentifier = [metadata objectNoNILForKey:@"bundle-identifier"];
            NSString * bundleVersion = [metadata objectNoNILForKey:@"bundle-version"];
            NSString * title = [metadata objectNoNILForKey:@"title"];
            
            
            AppInfo = [NSDictionary dictionaryWithObjectsAndKeys:bundleIdentifier, DISTRI_APP_ID,
                                      bundleVersion, DISTRI_APP_VERSION,
                                      title, DISTRI_APP_NAME,
                                      imageURL, DISTRI_APP_IMAGE_URL,
                                      dlfrom, DISTRI_APP_FROM, nil];
        }
        
        [self addDistriPlistURL:distriPlist appInfo:AppInfo];

    });
}


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    if (self.shareID == 1)
    {
        return [WeiboSDK handleOpenURL:url delegate:self];
        //return 1;
    }
    else if (self.shareID == 2)
    {
        return [WXApi handleOpenURL:url delegate:self];
    }
    else
    {
        return 1;
    }

}

- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {
    
}
- (void)didReceiveWeiboResponse:(WBBaseResponse *)response
{
    if ([response isKindOfClass:[WBSendMessageToWeiboResponse class]])
    {
        NSString * str = nil;
        if (response.statusCode == 0)
        {
            str = @"新浪微博分享成功!";
        }
        else
        {
            str = @"新浪微博分享失败";
        }
        UIAlertView * av = [[UIAlertView alloc] initWithTitle:str message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [av show];
    }
}


- (void)onResp:(BaseResp *)resp
{
    if ([resp isKindOfClass:[SendMessageToWXResp class]])
    {
        
        NSString * str = nil;
        if (resp.errCode == 0)
        {
            str = @"微信分享成功!";
        }
        else
        {
            str = @"微信分享失败!";
        }
        UIAlertView * av = [[UIAlertView alloc] initWithTitle:str message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [av show];
    }
}

- (void)openInfoPageForNotifi:(NSDictionary*)infoDic{
    NSString*key = [[MarketServerManage getManager] zipLocalNotifiDocmentKey:[infoDic objectForKey:@"id"] fireDate:[infoDic objectForKey:@"show_date"]];
    [[MarketServerManage getManager] deleteLocalNotifiFromDocment:key];
    
    
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    
    
    if( [url.scheme isEqualToString:@"myhelper"] ) {
        //示例数据
        //kybrowser:itms-services://?action=download-manifest&url=https://dinfo.wanmeiyueyu.com/Data/APPINFOR/21/58/net.crimoon.pm.ky/dizigui_zhouyi_net.crimoon.pm.ky_1402329600_1.0.0.plist
        NSString *distriPlistURL = url.resourceSpecifier;
        if( [distriPlistURL hasPrefix:@"itms-services"] ) {
            [self downloadIPAByPlistURL:distriPlistURL];
        }
        
    }else{
        if (self.shareID == 1)
        {
            return [WeiboSDK handleOpenURL:url delegate:self];
        }
        else if (self.shareID == 2)
        {
            return [WXApi handleOpenURL:url delegate:self];
        }
    }
    
    return YES;
}

//程序被挂起时调用
BOOL _reportFlag;
- (void)applicationWillResignActive:(UIApplication *)application
{
    _reportFlag = NO;
}

//进入后台
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    self.isBackGround = YES;
    
    //判断是否有应用正在下载中，nil为无，否则为有
    NSDictionary *dc = [[BppDistriPlistManager getManager] ItemInfoInDownloadingByAttriName:DISTRI_APP_DOWNLOAD_STATUS value:[NSNumber numberWithInt:DOWNLOAD_STATUS_RUN]];
    if (dc) {
        //播放无声背景音乐
        [[BackgroundAudio getObject] firstEnableMainAudioStrength:1];
    }


    if (IOS8) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    
    //结束长时间任务
    if(taskIdentifier){
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
        taskIdentifier = nil;
    }
    taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//        [application endBackgroundTask:taskIdentifier];
//        taskIdentifier = UIBackgroundTaskInvalid;
        NSLog(@"\n ===> 程序超时退出 !");

    }];
    
    NSLog(@"\n ===> 程序进入后台 !");
    
    [self appBackGroundBadge];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LIGHT_OFF object:nil];
    
}
//进入前台
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    _reportFlag = YES; // 轮播图汇报日志
//    //回到前台停止音乐
//    [[BackgroundAudio getObject] stopMainAudio];
    
    [[MarketServerManage getManager] getTimingLocalNotifications];
    
    self.isBackGround = NO;
    
    
    //结束长时间任务
    if(taskIdentifier){
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
        taskIdentifier = nil;
    }
    
}
//挂起后恢复、程序启动在didFinishLaunchingWithOptions之后
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] postNotificationName:UPDATE_DOWNLOAD_TOPVIEW_COUNT object:nil]; // 下载管理安装完成程序数字更改
    [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MOTION_ENDED_ACTION object:nil]; // 解决热词菊花后台到前台不停转bug
//    NSLog(@"\n ===> 程序重新激活 !"); 
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}
//程序终止（如果长主按钮强制退出则不会调用）
- (void)applicationWillTerminate:(UIApplication *)application
{
//    NSLog(@"\n ===> 程序意外暂行 !"); 
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    [self.sslServ stop];
    self.sslServ = nil;
    
    NSLog(@"程序退出");
}

-(void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    //收到内存警告，删除所有缓存
    NSLog(@"收到内存警告: 清空TMCache");
    [[TMCache sharedCache] removeAllObjects];
    [[SDImageCache sharedImageCache] clearMemory];
}



- (NSString *)getSystemLanguage{
    //判断系统语言
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] objectAtIndex:0];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if (alertView.tag == ALERTVIEW_TAG_INSTALL_ON_IPAD) {
        if (buttonIndex == 1) {
            //openurl Ipad 安装
            NSDictionary * info = objc_getAssociatedObject(alertView, @"info");
            NSString * distriPlist = [info objectForKey:@"plist"];
            objc_setAssociatedObject(alertView, @"info", nil, OBJC_ASSOCIATION_RETAIN);
            
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:distriPlist ]];
        }
    }
    if (alertView.tag == TAG_ALERTVIEW_INSTALLSFIX) {
        //安装自身修复
        if (buttonIndex ==0) {
            [self installFix];
        }
    }
    if (alertView.tag == NO_WIFI_DOWN_TAG) {
        if (buttonIndex == 0) {
            //继续下载
            if (tmpInforDic&&tmpDistriURL) {
                [[BppDistriPlistManager getManager] addPlistURL:tmpDistriURL appInfoDic:tmpInforDic];
                tmpDistriURL = nil;
                tmpInforDic = nil;
            }

        }else{
            [[NSNotificationCenter defaultCenter] postNotificationName:RELOAD_UPDATA_AFTER_SCREEN object:nil];
        }
    }
    if (alertView.tag == PUSH_ALERTVIEW_TAG) {
        if (buttonIndex == 1) {
            if(remotePushInfor)[[NSNotificationCenter defaultCenter] postNotificationName:REMOTE_PUSH object:remotePushInfor];
            remotePushInfor = nil;
        }
    }
}

- (void) appBackGroundBadge{
    NSString *strLanguage = nil;
    strLanguage = [self getSystemLanguage];
    
    if ([strLanguage isEqualToString:@"zh-Hans"] || [strLanguage isEqualToString:@"zh-Hant"]){
        //My助手取消更新badge
    }else{
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
}


//主线程
//PC端的链接通知
-(void)onPCConnected {
    
    NSLog(@"连接PC--%s", __FUNCTION__);
}

//主线程
//PC端断开链接通知
-(void)onPCDisConnected {
    NSLog(@"断开PC--%s", __FUNCTION__);
}

//非主线程
//接收到PC端数据
BOOL ifsuddess = TRUE;
NSMutableArray *successArray;
-(BOOL)onRecvPCCommand:(NSDictionary*)cmd {
    
    //此处：根据客户端的命令，导入图片
    //NSLog(@"%@", cmd);
    
    successArray = [NSMutableArray array];
    [successArray removeAllObjects];
    
    //[self performSelectorInBackground:@selector(saveTheImage:) withObject:cmd];
    
    photosAlbumManager = [[PhotosAlbumManager alloc] initWithDelegate:self];
    
    ALBUMVISITSTATE state = [photosAlbumManager ifCanVisitTheAlbum];
    
    NSMutableDictionary * infoDic;
    [infoDic removeAllObjects];
    infoDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              @"ImageAuthority", @"message",
                              [NSNumber numberWithInt:state], @"AuthorityType", nil];
    //发送状态
    [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic];
    
    if (state==CHOOCESTATE || state==VISIABLESTATE) {
        //去同步
        [self saveTheImage:cmd];
    }else{
        
        [infoDic removeAllObjects];
        infoDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                   @"syncEnd", @"message",
                   successArray, @"NameArray",
                   [NSNumber numberWithBool:NO], @"Result", nil];
        
        //不可访问，返回失败
        [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic];
        
        UIAlertView *tmpAlertView = [[UIAlertView alloc] initWithTitle:@"访问相册失败" message:@"请在“设置-隐私-照片”中允许“应用宝贝”，重新尝试即可" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [tmpAlertView show];
    }
    
    return ifsuddess;
}


- (void)saveTheImage:(NSDictionary *)cmd
{
    NSMutableArray *fileNamesArray = [cmd objectForKey:@"NameArray"];
    pcToIOSMediaNum = [fileNamesArray count];
    
    if ([fileNamesArray count]) {
        if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusNotDetermined) {
            
            ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
            
            [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                
                if (*stop) {
                    //点击“好”回调方法
                    
                    NSMutableDictionary * infoDic1;
                    [infoDic1 removeAllObjects];
                    infoDic1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                @"syncBegin", @"message", nil];
                    NSLog(@"点好发送消息-=-=  %@",infoDic1);
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic1];
                    
                    [photosAlbumManager saveImageToNewAlbum:fileNamesArray AlbumName:@"应用宝贝"];//导入自定义相册
                }
                *stop = TRUE;
                
            } failureBlock:^(NSError *error) {
                //点击“不允许”回调方法
                ifsuddess = FALSE;
                
                NSMutableDictionary * infoDic1;
                [infoDic1 removeAllObjects];
                infoDic1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                            @"syncEnd", @"message",
                            successArray, @"NameArray",
                            [NSNumber numberWithBool:NO], @"Result", nil];
                NSLog(@"点不允许发送消息-=-=  %@",infoDic1);
                //不可访问，返回失败
                [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic1];
            }];
        }else
        {
            NSMutableDictionary * infoDic1;
            [infoDic1 removeAllObjects];
            infoDic1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        @"syncBegin", @"message", nil];
            NSLog(@"已允许发送消息-=-=  %@",infoDic1);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic1];
            [photosAlbumManager saveImageToNewAlbum:fileNamesArray AlbumName:@"应用宝贝"];//导入自定义相册
        }
    }else
    {
        NSLog(@"pc传值为空");
    }
}


#pragma mark -
#pragma mark SaveUtilDelegate

- (void)mediaItemCopiedIsSuccess:(BOOL)success andPath:(NSString *)path
{
    static int failedcount = 0;
    static int successcount = 0;
    
    if (!success) {
        //统计失败个数
        NSLog(@"faild one");
        failedcount += 1;
        NSLog(@"失败个数%i",failedcount);
    }else
    {
        NSLog(@"success one");
        successcount += 1;
        NSLog(@"成功个数%i",successcount);
        [successArray addObject:path];
    }
    if (failedcount+successcount == pcToIOSMediaNum) {
        NSLog(@"所有传输完成 成功%i个  失败%i个",successcount,failedcount);
        
        if (failedcount>0) {
            ifsuddess = FALSE;
        }else
        {
            ifsuddess = TRUE;
        }
        
        NSMutableDictionary * infoDic;
        [infoDic removeAllObjects];
        infoDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                   @"syncEnd", @"message",
                   successArray, @"NameArray",
                   [NSNumber numberWithBool:ifsuddess], @"Result", nil];
        
        //返回传输结果
        [[NSNotificationCenter defaultCenter] postNotificationName:@"respondMessage" object:infoDic];
        
        failedcount = 0;
        successcount = 0;
    }
}

#pragma mark 实时判断网络变化
- (void)reachabilityChanged:(NSNotification *)note {
    
    static NetworkStatus beforeState=kNotReachable;
    
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    NetworkStatus status = [curReach currentReachabilityStatus];
    if (beforeState!=status)
    {
        beforeState = status;

    }
}


-(void)onNotification:(NSNotification*)notify {

    if ( [notify.name isEqualToString:HTTPS_SERVER_REQUEST_PLIST_OK_NOTIFICATION] ) {
        NSDictionary * dic = notify.userInfo;
        NSString * localPath = [dic objectForKey:@"LocalPath"];
        if( [localPath hasSuffix:@"plist"] ) {
            NSLog(@"plist下载完毕:%@", localPath);
            //删除临时plist文件
            [[NSFileManager defaultManager] removeItemAtPath:[self.sslServ.basePath stringByAppendingPathComponent:localPath]
                                                       error:nil];
            //系统弹框 被点击了"安装"，AppID
            NSString * appID = [[localPath lastPathComponent] stringByDeletingPathExtension];

            NSRange range = [appID rangeOfString:@"_t_"];
            if( range.location != NSNotFound ){
                appID = [appID substringToIndex:range.location];
            }

            //上报安装日志
            NSDictionary * attrInfo = [[BppDistriPlistManager getManager] ItemInfoByAttriName:DISTRI_APP_ID value:appID];
            if(attrInfo) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    NSString *appName = [attrInfo objectNoNILForKey:DISTRI_APP_NAME];
                    NSString *appVer = [attrInfo objectNoNILForKey:DISTRI_APP_VERSION];
                    NSString * appID = [attrInfo objectForKey: DISTRI_APP_ID];
                    
                    [[GetDevIPAddress getObject] reportInstallAPPID:appID appName:appName appVersion:appVer];
                });
            }
            
        }else if( [localPath hasSuffix:@"png"] ){
            NSLog(@"png 下载完毕:%@", localPath);
            
            //系统弹框 被点击了"安装"
            
            NSString * appID = [[localPath lastPathComponent] stringByDeletingPathExtension];

            NSRange range = [appID rangeOfString:@"_t_"];
            if( range.location != NSNotFound ){
                appID = [appID substringToIndex:range.location];
            }
            
            //该App信息
            NSDictionary * attrInfo = [[BppDistriPlistManager getManager] ItemInfoByAttriName:DISTRI_APP_ID value:appID];

            ;
            //系统弹框, 点击了"安装"按钮（IOS8 以下）
            [[FileUtil instance] setupLocalNotifications:[NSString stringWithFormat:@"应用宝贝正在为您安装%@，点我返回应用宝贝",[attrInfo objectForKey:@"distriAppName"]] time:2 infoDic:[NSDictionary dictionaryWithObjectsAndKeys:@"clickInstallButton", @"clickInstallButton",nil]];
            
            //删除临时png文件
            [[NSFileManager defaultManager] removeItemAtPath:[self.sslServ.basePath stringByAppendingPathComponent:localPath]
                                                       error:nil];
        }
    }else if ([notify.name isEqualToString:WEBSERVER_NOTIFICATION_REQUEST_DOWNLOAD_FILE]){
        
        //系统弹框, 点击了"安装"按钮
        
        NSDictionary * dic = notify.userInfo;
        NSString * localPath = [dic objectForKey:@"LocalPath"];
        //删除路径前的 /
        localPath = [localPath substringFromIndex:1];
        if( [localPath hasSuffix:@"ipa"] ){
            
            //系统弹框, 点击了"安装"按钮（IOS8及以上）
            NSDictionary * attrInfo = [[BppDistriPlistManager getManager] ItemInfoByAttriName:DISTRI_APP_IPA_LOCAL_PATH value:localPath];
            
            //distriAppID
            
            NSString *installingAppid = [attrInfo objectForKey:@"distriAppID"];
            
            NSLog(@"##########添加appid: %@", installingAppid);
            [self.installingAppIDs addObject:installingAppid];
            
            [[FileUtil instance] setupLocalNotifications:[NSString stringWithFormat:@"应用宝贝正在为您安装%@，点我返回应用宝贝",[attrInfo objectForKey:@"distriAppName"]] time:2 infoDic:[NSDictionary dictionaryWithObjectsAndKeys:@"clickInstallButton", @"clickInstallButton",nil]];
        }

        
    }else if ( [notify.name isEqualToString:WEBSERVER_NOTIFICATION_DOWONLOAD_FILE_COMPLETE] ) {
        
        //IPA 下载完毕
        
        
        NSDictionary * dic = notify.userInfo;
        NSString * localPath = [dic objectForKey:@"LocalPath"];
        //删除路径前的
        localPath = [localPath substringFromIndex:1];
        
        if ([localPath hasSuffix:@".ipa"]) {
            NSString *appid = [[localPath lastPathComponent] stringByDeletingPathExtension];
            
            [self.installingAppIDs removeObject:appid];
            NSLog(@"##########删除appid: %@", appid);
            
            
        }

//        NSDictionary * attrInfo = [[BppDistriPlistManager getManager] ItemInfoByAttriName:DISTRI_APP_IPA_LOCAL_PATH value:localPath];
//        if(attrInfo){
//            NSLog(@"%@", attrInfo);
//
//            //上报安装日志
//            dispatch_async(dispatch_get_global_queue(0, 0), ^{
//                NSString *appName = [attrInfo objectNoNILForKey:DISTRI_APP_NAME];
//                NSString *appVer = [attrInfo objectNoNILForKey:DISTRI_APP_VERSION];
//                NSString * appID = [attrInfo objectForKey: DISTRI_APP_ID];
//                
//                [[GetDevIPAddress getObject] reportInstallAPPID:appID appName:appName appVersion:appVer];
//            });
//        }
        
    }else if([notify.name isEqualToString:HTTPS_NEED_RESTART_SERVER]){
        
//        //直接退出客户端
        NSLog(@"本地服务器异常！关闭ssl服务器!!");
        [self.sslServ stop];
        [httpServer stopServer];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //直接退出客户端
            NSLog(@"重启ssl服务器");
            [self.sslServ start:self.sslPort];
            
            [httpServer startServer:self.webserverPort];
        });
    }
}

-(void)addDistriPlistURL:(NSString*)distriPlistURL   appInfo:(NSDictionary*)appInfo {
    
//    itms-services://?action=download-manifest&url=https://dinfo.wanmeiyueyu.com/gxltest/my/My_YiJing_KU3X3.bUDI0wFoSSL4QD.dvElT4mvz3vf.da1wkZPITeL.cZqH1M.d5LZe.biafpeGZk.b.dk_0_bfc45450667982c34d7dcd101e466cee.plist

    BOOL flag = ENABLE_EU;//开关,是否启用EU
    BOOL flag_ = HAS_CONNECTED_PC;//是否连接过PC端激活(写入文件)
    BOOL flag__ = DIRECTLY_GO_APPSTORE;//是否直接跳store
    NSLog(@"企签开关~~%d,是否激活~~%d,跳转store~~%d",flag,flag_,flag__);
    
    //My助手新增是否直接跳转AppStore
//    if ((!ENABLE_EU && DIRECTLY_GO_APPSTORE) || (!ENABLE_EU && ![[FileUtil instance] hasBindAppleID])) {
    
        NSString *digitalid = [[NSUserDefaults standardUserDefaults] objectForKey:[appInfo objectForKey:@"appid"]];
        if (digitalid) {
            [[NSNotificationCenter  defaultCenter] postNotificationName:OPEN_APPSTORE object:digitalid];
        }
        return;
//    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        // 要下载的应用程序是否可以运行在本机系统
        NSString *minVer = [appInfo objectForKey:@"appminosver"];
        if (![self isAppNeedsSystemVersionValid:minVer]) {
            return;
        }
        
        if (!distriPlistURL) {
            return ;
        }
        if (!appInfo) {
            return;
        }
        NSString*appid = [appInfo objectForKey:@"appid"];
        if(!appid){
            appid = [appInfo objectForKey:DISTRI_APP_ID];
        }
        if(!appid)
            return;
        
        NSString*appversion = [appInfo objectForKey:@"appversion"];
        if(!appversion){
            appversion = [appInfo objectForKey:DISTRI_APP_VERSION];
        }
        if(!appversion)
            return;
        NSString *appprice = [appInfo objectForKey:@"appprice"];
        if(!appprice){
            appprice = [appInfo objectForKey:DISTRI_APP_PRICE];
        }
        if(!appprice || [appprice isEqualToString:@""]){
            NSLog(@"价格错误");
            return;
        }
        //My助手新增,价格不为0,直接跳Store
        if (![appprice isEqualToString:@"0.00"]) {
            [[NSNotificationCenter  defaultCenter] postNotificationName:OPEN_APPSTORE object:[appInfo objectForKey:@"distriAppID"]];
            return;
        }
        
        NSString*appname = [appInfo objectForKey:@"appname"];
        if(!appname){
            appname = [appInfo objectForKey:DISTRI_APP_NAME];
        }
        if(!appname)
            return;
        
        NSString*appiconurl = [appInfo objectForKey:@"appiconurl"];
        if(!appiconurl){
            appiconurl = [appInfo objectForKey:DISTRI_APP_IMAGE_URL];
        }
        if(!appiconurl)
            return;
        
        
        NSString*dlfrom = [appInfo objectForKey:@"dlfrom"];
        if(!dlfrom){
            dlfrom = [appInfo objectForKey:DISTRI_APP_FROM];
        }
        if(!dlfrom)
            return;


        NSDictionary *infoDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 appid, DISTRI_APP_ID,
                                 appversion,DISTRI_APP_VERSION,
                                 appname,DISTRI_APP_NAME,
                                 appiconurl,DISTRI_APP_IMAGE_URL,
                                 dlfrom,DISTRI_APP_FROM,
                                 appprice,DISTRI_APP_PRICE,nil];
        
        NSString *netState = [[FileUtil instance] GetCurrntNet];        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //不用下载到下载管理中
            if (![[SettingPlistConfig getObject] getPlistObject:DOWNLOAD_TO_LOCAL])
            {
                
                if ([netState isEqualToString:@"wifi"]) {
                    [[BppDownloadToLocal getObject] downLoadPlistFile:distriPlistURL];
                    
                }else if ([netState isEqualToString:@"3g"]){
                    
                    if ([[SettingPlistConfig getObject] getPlistObject:DOWN_ONLY_ON_WIFI] == YES) {
                        UIAlertView * netAlert = [[UIAlertView alloc] initWithTitle:nil message:ON_WIFI_DOWN_TIP delegate:self cancelButtonTitle:@"流量够用" otherButtonTitles:@"取消下载", nil];
                        [netAlert show];
                        
                    }else{
                        [[BppDownloadToLocal getObject] downLoadPlistFile:distriPlistURL];
                    }
                }else{
                    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"网络异常，请检查网络" message:nil delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
                    [alert show];
                }
            }
            //下载到下载管理中
            else
            {
                DOWNLOAD_STATUS status = [[BppDistriPlistManager getManager]getPlistURLStatus:distriPlistURL];
                
                if (status == STATUS_ALREADY_IN_DOWNLOADING_LIST) {
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"mainVCDelegateAlertMethod" object:@{@"state":[NSNumber numberWithInt:STATUS_ALREADY_IN_DOWNLOADING_LIST],@"url":distriPlistURL}];
                    
                }else if (status == STATUS_ALREADY_IN_DOWNLOADED_LIST){
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"mainVCDelegateAlertMethod" object:@{@"state":[NSNumber numberWithInt:STATUS_ALREADY_IN_DOWNLOADED_LIST],@"url":distriPlistURL}];
                }else if (status == STATUS_NONE){
                    
                    if ([netState isEqualToString:@"3g"]){
                        
                        //仅WIFI下载?
                        if ([[SettingPlistConfig getObject] getPlistObject:DOWN_ONLY_ON_WIFI] == YES)
                        {
                            UIAlertView * netAlert = [[UIAlertView alloc] initWithTitle:nil message:ON_WIFI_DOWN_TIP delegate:self cancelButtonTitle:@"流量够用" otherButtonTitles:@"取消下载", nil];
                            netAlert.tag = NO_WIFI_DOWN_TAG;
                            [netAlert show];
                            
                            tmpDistriURL = distriPlistURL;
                            tmpInforDic = infoDic;
                            
                        }
                        else{
                            [[BppDistriPlistManager getManager] addPlistURL:distriPlistURL appInfoDic:infoDic];
                        }
                        
                    }else //if ([netState isEqualToString:@"wifi"])
                    {
                        //WIFI下
                        [[BppDistriPlistManager getManager] addPlistURL:distriPlistURL appInfoDic:infoDic];
                    }
                }
            }

        });
    });
}

-(void)add3GFreeFlowDistriPlistURL:(NSString*)distriPlistURL   appInfo:(NSDictionary*)appInfo {
    
    // 要下载的应用程序是否可以运行在本机系统
    NSString *minVer = [appInfo objectForKey:@"appminosver"];
    if (![self isAppNeedsSystemVersionValid:minVer]) {
        return;
    }
    
    // 判断下载条件并下载、安装
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        if (!distriPlistURL) {
            return ;
        }
        if (!appInfo) {
            return;
        }
        
        NSString*appid = [appInfo objectForKey:@"appid"];
        if(!appid) {
            appid = [appInfo objectForKey:DISTRI_APP_ID];
        }
        if(!appid)
            return ;
        
        
        NSString*appversion = [appInfo objectForKey:@"appversion"];
        if(!appversion) {
            appversion = [appInfo objectForKey:DISTRI_APP_VERSION];
        }
        if(!appversion)
            return ;

        
        NSString*appname = [appInfo objectForKey:@"appname"];
        if(!appname) {
            appname = [appInfo objectForKey:DISTRI_APP_NAME];
        }
        if(!appname)
            return ;

        
        NSString*appiconurl = [appInfo objectForKey:@"appiconurl"];
        if(!appiconurl) {
            appiconurl = [appInfo objectForKey:DISTRI_APP_IMAGE_URL];
        }
        if(!appiconurl)
            return ;

                
        NSString*dlfrom = [appInfo objectForKey:@"dlfrom"];
        if(!dlfrom) {
            dlfrom = [appInfo objectForKey:DISTRI_APP_FROM];
        }
        if(!dlfrom)
            return ;
        
        
        NSDictionary *infoDic = [NSDictionary dictionaryWithObjectsAndKeys:appid, DISTRI_APP_ID,
                                 appversion,DISTRI_APP_VERSION,
                                 appname,DISTRI_APP_NAME,
                                 appiconurl,DISTRI_APP_IMAGE_URL,
                                 dlfrom,DISTRI_APP_FROM,
                                 nil];
        
        NSString *netState = [[FileUtil instance] GetCurrntNet];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //不用下载到下载管理中
            if (![[SettingPlistConfig getObject] getPlistObject:DOWNLOAD_TO_LOCAL])
            {
                if ([netState isEqualToString:@"wifi"]) {
                    [[BppDownloadToLocal getObject] downLoadPlistFile:distriPlistURL];
                }
                else if ([netState isEqualToString:@"3g"]){
                    
                    //直接安装
                    [[BppDownloadToLocal getObject] downLoadPlistFile:distriPlistURL];
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [[GetDevIPAddress getObject] reportUpdataAppID:appid AppName:appname AppVersion:appversion];
                    });
                }
                else
                {
                    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"网络异常，请检查网络" message:nil delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
                    [alert show];
                }
                
            }
            //下载到下载管理中
            else
            {
                DOWNLOAD_STATUS status = [[BppDistriPlistManager getManager]getPlistURLStatus:distriPlistURL];
                if (status == STATUS_ALREADY_IN_DOWNLOADING_LIST) {
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"mainVCDelegateAlertMethod" object:@{@"state":[NSNumber numberWithInt:STATUS_ALREADY_IN_DOWNLOADING_LIST],@"url":distriPlistURL}];
                    
                }else if (status == STATUS_ALREADY_IN_DOWNLOADED_LIST){
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"mainVCDelegateAlertMethod" object:@{@"state":[NSNumber numberWithInt:STATUS_ALREADY_IN_DOWNLOADED_LIST],@"url":distriPlistURL}];
                    
                }else if (status == STATUS_NONE){
                    
                    if ([netState isEqualToString:@"3g"]
                        || [netState isEqualToString:@"wifi"]){
                        
                        NSMutableDictionary * mutableInfoDic = [NSMutableDictionary dictionaryWithDictionary:infoDic];
                        NSString *netOperatorState = [[FileUtil instance] checkChinaMobileNetState];
                        if([netOperatorState hasPrefix:@"中国联通"]){
                            [mutableInfoDic setObject:[NSNumber numberWithBool:YES] forKey:DISTRI_FREE_FLOW];
                        }
                        
                        [[BppDistriPlistManager getManager] addPlistURL:distriPlistURL appInfoDic:mutableInfoDic];
                    }else{
                        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"网络异常，请检查网络" message:nil delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
                        [alert show];
                    }
                }
            }
            
        });
    });
}


-(void)onIPadDistriPlistResponse:(NSDictionary *)Info{

    NSLog(@"%@", Info);
    
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"应用宝贝"
                                                         message:@"请您安装适配于iPad设备的应用宝贝HD"
                                                        delegate:self
                                               cancelButtonTitle:@"取消"
                                               otherButtonTitles:@"确认",
                               nil];
    alertView.tag = ALERTVIEW_TAG_INSTALL_ON_IPAD;
    objc_setAssociatedObject(alertView, @"info", Info, OBJC_ASSOCIATION_RETAIN);
    
    [alertView show];
}


-(void)_3GDataPrompt:(NSNotification*)notifi {
    
    NSDictionary * appInfo = notifi.object;

    //如果是免流的，则直接返回不提示
    NSNumber * bFree = [appInfo objectForKey:DISTRI_FREE_FLOW];
    if(bFree && [bFree boolValue]) {
        NSString *netOperatorState = [[FileUtil instance] checkChinaMobileNetState];
        //免流只针对联通，只有联通不提示 “非WIFI不耗流量”
        if([netOperatorState hasPrefix:@"中国联通"]){
            return ;
        }
    }
    
    //
//    static BOOL  lbFirst = NO;
//    if(!lbFirst) {
//        
//        if( [[[FileUtil instance] GetCurrntNet] isEqualToString:@"3g"] )
//        {
//            lbFirst = YES;
//            
//            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"您目前在非WiFi环境下，下载应用将耗费手机流量"
//                                                                 message:nil
//                                                                delegate:self
//                                                       cancelButtonTitle:@"知道了"
//                                                       otherButtonTitles:nil, nil];
//            [alertView show];
//            
//            //3秒后消失
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [alertView dismissWithClickedButtonIndex:0 animated:YES];
//            });
//        }
//    }
}
#pragma mark - 判断应用程序所需手机系统的版本是否满足条件

-(BOOL)isAppNeedsSystemVersionValid:(NSString *)minSysVer
{ // 要下载的应用程序是否可以运行在本机系统
    
    if ([self deviceVerBigThanAppVer:minSysVer] || minSysVer==nil || [minSysVer isEqualToString:@""]) {
        return YES;
    }
    
    // 不可以运行在本机系统
    [self showAppInvalidAlert];
    return NO;
    
}

-(BOOL)deviceVerBigThanAppVer:(NSString *)appVer
{ // 应用程序所需系统版本 是否大于当前系统
    NSString *sysVer = [UIDevice currentDevice].systemVersion;
    
    NSArray *sysVerArr = [sysVer componentsSeparatedByString:@"."];
    NSArray *appVerArr = [appVer componentsSeparatedByString:@"."];
    
    int count = (sysVerArr.count>appVerArr.count)?appVerArr.count:sysVerArr.count;
    BOOL isValid = NO;
    int i=0;
    for (; i < count; i++) {
        if ([sysVerArr[i] intValue]>[appVerArr[i] intValue]) {// 系统版本号大
            isValid = YES;
            break;
        }
        else if ([sysVerArr[i] intValue] <[appVerArr[i] intValue])
        {
            isValid = NO;
            break;
        }
    }
    
    // 相等
    if (!isValid && i==count) {
        isValid = YES;
    }
    
    return isValid;
}

-(void)showAppInvalidAlert
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"此应用安装所需版本号高于当前设备iOS系统，请您升级iOS系统" message:nil delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
        [alertView show];
    });
}
/*
- (void)RegisteredLocalNotification{
    
    if (IOS8) {
        //创建消息上面要添加的动作(按钮的形式显示出来)
        UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
        action.identifier = @"action";//按钮的标示
        action.title=@"接收";//按钮的标题
        action.activationMode = UIUserNotificationActivationModeForeground;//当点击的时候启动程序
        //    action.authenticationRequired = YES;
        //    action.destructive = YES;
        
        UIMutableUserNotificationAction *action2 = [[UIMutableUserNotificationAction alloc] init];  //第二按钮
        action2.identifier = @"action2";
        action2.title=@"拒绝";
        action2.activationMode = UIUserNotificationActivationModeBackground;//当点击的时候不启动程序，在后台处理
        action.authenticationRequired = YES;//需要解锁才能处理，如果action.activationMode = UIUserNotificationActivationModeForeground;则这个属性被忽略；
        action.destructive = YES;
        
        
        //创建动作(按钮)的类别集合
        UIMutableUserNotificationCategory *categorys = [[UIMutableUserNotificationCategory alloc] init];
        categorys.identifier = @"alert";//这组动作的唯一标示
        [categorys setActions:@[action,action2] forContext:(UIUserNotificationActionContextMinimal)];
        
        //创建UIUserNotificationSettings，并设置消息的显示类类型
        UIUserNotificationSettings *uns = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound) categories:[NSSet setWithObjects:categorys,nil]];
        
        
        //注册推送
        [[UIApplication sharedApplication] registerUserNotificationSettings:uns];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }

}
*/
//本地推送通知
-(void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    //成功注册registerUserNotificationSettings:后回调的方法
    NSLog(@"didRegisterUserNotificationSettings ----%@",notificationSettings);
    [application registerForRemoteNotifications];

}

//接受本地通知
-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
//    NSLog(@"didReceiveLocalNotification ----%@",notification.userInfo);
    NSDictionary *info = notification.userInfo;
//    if (application.applicationState == UIApplicationStateActive){
    
    if (application.applicationState == UIApplicationStateInactive || application.applicationState == UIApplicationStateBackground){
        

    
        if ([info objectForKey:@"id"]) {
            [self openInfoPageForNotifi:info];
            NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:[info objectForKey:@"push_type"],@"push_type",[info objectForKey:@"push_type_info"],@"push_type_info", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:LOCAL_PUSH_DETAIL object:dic];
            return;
        }else if([info objectForKey:@"downed"]){
            [[NSNotificationCenter defaultCenter] postNotificationName:LOCAL_PUSH_CLICK_OK object:nil];
        }
        
    }
}
-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    //在非本App界面时收到本地消息，下拉消息会有快捷回复的按钮，点击按钮后调用的方法，根据identifier来判断点击的哪个按钮，notification为消息内容
    NSLog(@"handleActionWithIdentifier----%@----forLocalNotification----%@",identifier,notification);
    
    completionHandler();//处理完消息，最后一定要调用这个代码块
    
}

//远程推送通知
-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //向APNS注册成功，收到返回的deviceToken
    [BPush registerDeviceToken:deviceToken]; // 必须
    
    [BPush bindChannel]; // 必须。可以在其它时机调用，只有在该方法返回（通过onMethod:response:回调）绑定成功时，app才能接收到Push消息。一个app绑定成功至少一次即可（如果access token变更请重新绑定）。
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    //向APNS注册失败，返回错误信息error
}
-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    //收到远程推送通知消息
    [BPush handleNotification:userInfo]; // 可选
    
    
    //远程推送需要设置键值
    //@"push_detail"
    //@"push_type",可能值:REMOTE_PUSH_APP等
    //@"push_description"
    
    
    if (application.applicationState == UIApplicationStateInactive || application.applicationState == UIApplicationStateBackground){
        NSLog(@"MMMMMMMMMMMMMMMMMMMMM");
        [[NSNotificationCenter defaultCenter] postNotificationName:REMOTE_PUSH object:userInfo];
    }else if (application.applicationState ==UIApplicationStateActive){
        UIAlertView *remotePushAlertView = [[UIAlertView alloc] initWithTitle:@"消息推送"
                                                               message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
                                                              delegate:self
                                                     cancelButtonTitle:@"忽略"
                                                     otherButtonTitles:@"查看", nil];
        remotePushAlertView.tag = PUSH_ALERTVIEW_TAG;
        [remotePushAlertView show];
        remotePushInfor = userInfo;
        
    }
    
}

-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler
{
    //在没有启动本App时，收到服务器推送消息，下拉消息会有快捷回复的按钮，点击按钮后调用的方法，根据identifier来判断点击的哪个按钮
}


- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    return UIInterfaceOrientationMaskPortrait;
}

//流程控制代理
#pragma mark BppDistriPlistManagerControlDelegate
//获得当前最大同时下载数
-(NSInteger)maxDowndingCount {
    return [[SettingPlistConfig getObject] getPlistObject_holdStrength_downCount:DOWNLOADCOUNT];
}

//解决IOS8 OTA安装没反应的问题

//My助手修改
-(BOOL)IsChangeAppid {
    return YES;//[UpdateAppManager getManager].isChangeAppid;
}

//当前SSL Port
-(NSInteger)currentSSLPort{
    return self.sslPort;
}

//当前HTTP Port
-(NSInteger)currentWebServerPort{
    return self.webserverPort;
}

//该appid 是否在安装中
-(BOOL)IsAppInstalling:(NSString*)appid{
    
    if( [self.installingAppIDs containsObject:appid] )
        return YES;
    
    return NO;
}
///////////////////////////////////////////////////////////////////////////////


//是否已经安装闪退修复
-(BOOL)isInstallFix {

    NSString * dst = [[[FileUtil instance] getDocumentsPath] stringByAppendingPathComponent:@"iphone.mobileconfig"];
    if([[NSFileManager defaultManager] fileExistsAtPath:dst isDirectory:nil]){
        return YES;
    }
    
    return NO;
    
    
//    if(objc_getMetaClass("UIWebClip")){
//
//        //获取所有的类方法
//        NSMutableArray * selnames = [NSMutableArray array];
//        unsigned int numMethods=0;
//        Method *methods = class_copyMethodList(objc_getMetaClass("UIWebClip"), &numMethods);
//        for (int i = 0; i < numMethods; i++) {
//            Method method = methods[i];
//            const char* selname =sel_getName(method_getName(method));
//            [selnames addObject:[NSString stringWithFormat:@"%s", selname]];
//        }
//        
//        //安装闪退修复应用
//        if([selnames containsObject:@"pathForWebClipWithIdentifier:"]){
//            NSString * t = [UIWebClip pathForWebClipWithIdentifier:@"com.kuaiyong.browser.webclip"];
//            if(t.length>0){
//                return YES;
//            }
//        }
//    }
//    return NO;
}

//安装闪退修复
-(void)installFix {

    NSString * src = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"iphone.mobileconfig"];
    NSString * dst = [[[FileUtil instance] getDocumentsPath] stringByAppendingPathComponent:@"iphone.mobileconfig"];
    [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil];

    NSString * url = [NSString stringWithFormat:@"http://127.0.0.1:%d/iphone.mobileconfig", self.webserverPort];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    });
}

- (void)creatCustomWindow{
    if (!self.yindaoWindow) {
        self.yindaoWindow = [[EnableView alloc] initWithFrame:MainScreeFrame];
        self.yindaoWindow.backgroundColor = WHITE_COLOR;
        self.yindaoWindow.windowLevel = UIWindowLevelAlert;
    }
    
    [self.yindaoWindow showEnableWindow];
}

#pragma mark 友盟方法

- (void)umengTrack
{
    //    [MobClick setLogEnabled:YES];
    [MobClick setEncryptEnabled:YES];
    [MobClick setAppVersion:XcodeAppVersion];
    
    [MobClick startWithAppkey:UMENG_APPKEY reportPolicy:BATCH channelId:nil];
    [Context defaults].adUrlStr = [MobClick getAdURL];
}
@end
