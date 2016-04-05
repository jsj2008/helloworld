//
//  SearchResult_DetailTableViewController.m
//  browser
//
//  Created by caohechun on 14-4-2.
//
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif
#import "SearchResult_DetailTableViewController.h"
#import "AppDetailView.h"
#import "AppInforView.h"
#import "AppInforFootView.h"
#import "AppDiscussWebView.h"
#import "AppRelevantTableViewController.h"
#import "AppTestTableViewController.h"
#import "SetDownloadButtonState.h"
#import "MarketServerManage.h"
#import "PreViewImageView.h"
#import "AppStatusManage.h"
#import "CollectionViewBack.h"
#import "SDImageCache.h"
#define sectionHeadView_Height 40
#define cellHeight (self.view.frame.size.height -sectionHeadView_Height)
#define tableViewHeadView_Heigh 100
#define tableViewFootView_Heigh 80
#define TAG_BUTTON_WEIGHT 60
#define CONTENTOFFSET_X scrollView.contentOffset.x

//定义后2两个标签页按钮的位置大小
#define CGRECT_OF_THIRD_BUTTON CGRectMake(self.discussButton.frame.origin.x + self.discussButton.frame.size.width + button_space, 0, 60, button_height)
#define CGRECT_OF_FOURTH_BUTTON CGRectMake(CGRECT_OF_THIRD_BUTTON.origin.x + CGRECT_OF_THIRD_BUTTON.size.width + button_space, 0, 80, button_height)
@interface SearchResult_DetailTableViewController ()
{
    int cell_type;
    AppDiscussWebView *discussWebView;
    float currentCellHeight;
    float discussWebViewHeight;
    UIView *sectionHeadView;
    UIImageView *sepetate_arrow;
    UIImageView *seperateBG;
    NSURL *iconURL;
    NSArray *introImagesURL;
    NSString *appID_;
    NSString *kid;
    NSString *discussURLString;
    AppRelevantTableViewController *appRelevantTableViewController;
    NSString *developerName;
    float relevantTableViewHeight;
    AppTestTableViewController *appTestTableViewController;
    float testTableViewHeight;
    SearchManager *searchManager;
    SearchServerManage *searchServerManager;
    BOOL discussWebViewLock;
    NSMutableArray *tagButtons;
    NSMutableDictionary *appInforDic;
    SetDownloadButtonState *buttonManager;
    int currentIndex;
    CollectionViewBack * _backView;//加载中
    BOOL atLeastOnePreviewSuccess;
}


@end
enum{
    DETAIL_PAGE = 0,
    DISCUSS_PAGE,
    RELEVANT_PAGE,
    TEST_PAGE
};


@implementation SearchResult_DetailTableViewController

- (void)dealloc{
    [[MarketServerManage getManager] removeListener:self];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;

    searchServerManager =[[SearchServerManage alloc]init];
    searchServerManager.delegate = self;
    [[MyServerRequestManager getManager] addListener:self];
    self.tableView.backgroundColor  = [UIColor clearColor];
    self.tableView.showsVerticalScrollIndicator = NO;
    
    //用于存储浏览过的app的详情信息
//    self.appCache = [[NSMutableArray alloc]init];
    
    //headView
    _headView =  [[AppInforView alloc]init];
    //在viewWillLayoutSubviews方法中赋值会导致headview 位置显示不正常
    _headView.frame = CGRectMake(0, 0, MainScreen_Width, tableViewHeadView_Heigh);
    _headView.backgroundColor = WHITE_BACKGROUND_COLOR;
    self.tableView.tableHeaderView = _headView;

    cell_type = DETAIL_PAGE;
    _appDetailView  = [[AppDetailView alloc]init];
    
    //初始化各个页签
    [self initDetailPage];
    
  
    //初始化section的headview
    sectionHeadView  = [[UIView alloc]init];
    sectionHeadView.backgroundColor = WHITE_BACKGROUND_COLOR;
    sectionHeadView.frame =  CGRectMake(0, 0, MainScreen_Width, sectionHeadView_Height);
    
#define button_space 30//标签页按钮间距
#define button_height 20//标签页按钮高度
    UIView *section_bg = [[UIView alloc]initWithFrame:CGRectMake(0, 8, MainScreen_Width, sectionHeadView_Height)];

//    section_bg.backgroundColor = WHITE_BACKGROUND_COLOR;
    
    

    self.detailsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.detailsButton.frame = CGRectMake(0, 8, TAG_BUTTON_WEIGHT, button_height);
    [self.detailsButton setTitle:@"详   情" forState:UIControlStateNormal];
    self.detailsButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.detailsButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.detailsButton addTarget:self action:@selector(showDetailsPage) forControlEvents:UIControlEventTouchUpInside];
    [section_bg addSubview:self.detailsButton];
    
    self.discussButton = [UIButton buttonWithType:UIButtonTypeCustom];

    self.discussButton.frame = CGRectMake(self.detailsButton.frame.origin.x + self.detailsButton.frame.size.width + button_space, 0, TAG_BUTTON_WEIGHT, button_height);
    [self.discussButton setTitle:@"评   论" forState:UIControlStateNormal];
    self.discussButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.discussButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.discussButton addTarget:self action:@selector(showDiscussPage) forControlEvents:UIControlEventTouchUpInside];
    [section_bg addSubview:self.discussButton];
    
    self.relevantAppsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.relevantAppsButton.frame = CGRECT_OF_THIRD_BUTTON;
    [self.relevantAppsButton setTitle:@"相关应用" forState:UIControlStateNormal];
    self.relevantAppsButton.titleLabel.font = [UIFont systemFontOfSize:15];
    self.relevantAppsButton.hidden = YES;
    [self.relevantAppsButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.relevantAppsButton addTarget:self action:@selector(showRelevantPage) forControlEvents:UIControlEventTouchUpInside];
    [section_bg addSubview:self.relevantAppsButton];
    
    self.testButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.testButton.frame = CGRECT_OF_FOURTH_BUTTON;
    [self.testButton setTitle:@"相关信息" forState:UIControlStateNormal];
    self.testButton.titleLabel.font = [UIFont systemFontOfSize:15];
    self.testButton.hidden = YES;
    [self.testButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.testButton addTarget:self action:@selector(showTestPage) forControlEvents:UIControlEventTouchUpInside];
    [section_bg addSubview:self.testButton];
    [sectionHeadView addSubview:section_bg];
    

    
    
    //初始化页签分割背景
    seperateBG = [[UIImageView alloc]init];
    seperateBG.frame = CGRectMake(0, self.detailsButton.frame.origin.y + self.detailsButton.frame.size.height + 6, MainScreen_Width, 13.0/2);
    SET_IMAGE(seperateBG.image, @"seperateBG.png");
    [sectionHeadView addSubview:seperateBG];
    
    //初始化页签指示箭头
    sepetate_arrow  =[[UIImageView alloc]init];
    SET_IMAGE(sepetate_arrow.image, @"seperate_arrow.png");

    [sectionHeadView addSubview:sepetate_arrow];
#pragma mark - 通知
    
    buttonManager = [[SetDownloadButtonState alloc]init];
    
    //加载中
    __weak typeof(self) mySelf = self;
    _backView = [CollectionViewBack new];
    [_appDetailView.imagesContainer addSubview:_backView];
    [_backView setClickActionWithBlock:^{
        [mySelf performSelector:@selector(retryPreviews) withObject:nil afterDelay:delayTime];
    }];
    
    
    //用于更新下载按钮状态
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateDownloadButtonState:)
                                                name:UPDATE_DOWNLOAD_TOPVIEW_COUNT
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateDownloadButtonState:)
                                                name:RELOAD_UPDATE_COUNT
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateDownloadButtonState:)
                                                name:@"updateDownloadButtonState"
                                              object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateDownloadButtonState:)
                                                 name:ADD_APP_DOWNLOADING
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateDownloadButtonState:)
                                                 name:RELOADDOWNLOADCOUNT
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateDownloadButtonState:)
                                                 name:REFRESH_MOBILE_APP_LIST
                                               object:nil];
    
    //监听软键盘弹出
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeDiscussPagePosition:) name:UIKeyboardWillShowNotification object:@"keyboardShow"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeDiscussPagePosition:) name:UIKeyboardWillHideNotification object:@"keyboardHide"];
    
}
#pragma mark - 更新下载按钮状态
- (void)updateDownloadButtonState:(NSNotification *)noti{
    [appRelevantTableViewController.tableView reloadData];
    if (!buttonManager) {
        return;
    }
    //设置状态
    [self.headView initDownloadButtonState];
    //添加响应方法
    [buttonManager setDownloadButton:self.headView.appStateButton withAppInforDic:appInforDic andDetailSoure:self.detailSource andUserData:buttonManager];
}

#pragma mark - 软键盘弹出,调整discuss位置
- (void)changeDiscussPagePosition:(NSNotification *)noti{
    if ([noti.object isEqualToString:@"keyboardShow"]) {
        self.tableView.contentOffset = CGPointMake(0, _headView.frame.size.height);
    }else{
        self.tableView.contentOffset = CGPointZero;

    }
    
}
- (void)viewWillLayoutSubviews{
    _backView.frame = self.appDetailView.imagesContainer.frame;
}


- (void)initDetailPage{
    //初始化详情页
    _appDetailView  = [[AppDetailView alloc]init];
    _appDetailView.frame = CGRectMake(0, 0, MainScreen_Width, [_appDetailView getAppDetailViewHeight]);
    _appDetailView.contentSize = _appDetailView.frame.size;
    _appDetailView.delegate = self;
    _appDetailView.scrollImageView.delegate = self;
    [_appDetailView.expandButton addTarget:self action:@selector(expandDetail) forControlEvents:UIControlEventTouchUpInside];
    [_appDetailView.promoteButton addTarget:self action:@selector(promoteApp) forControlEvents:UIControlEventTouchUpInside];
    //初始化内容
    [_appDetailView setDetailContent:nil];

    
}

    //初始化评论页面
- (void)initDiscussPage:(NSString *)URLString{
    discussWebView = [[AppDiscussWebView alloc ]init];
    discussWebView.delegate = self;
    
    discussWebView.frame = CGRectMake(- MainScreen_Width, 0, MainScreen_Width, 100);

    [self.tableView addSubview:discussWebView];
    [discussWebView loadURLString:URLString];

}


    //初始化相关应用页面
- (void)initRelevantPage:(NSArray *)data{
    appRelevantTableViewController  = [[AppRelevantTableViewController alloc]initWithStyle:UITableViewStylePlain];
    appRelevantTableViewController.relevantDelegate = self.parentVC;
    appRelevantTableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    relevantTableViewHeight = 80*[data count] + 30;//包括sectionHead高度30

    if ([data count] == 0 ) {
         relevantTableViewHeight = 30;//80*[data count] + 30;//包括sectionHead高度30
    }
    appRelevantTableViewController.tableView.frame = CGRectMake(- MainScreen_Width, 0, MainScreen_Width, 100);
    [self.view addSubview:appRelevantTableViewController.tableView];
    [appRelevantTableViewController setRelevantData:data];
}
    //初始化评测页面
- (void)initTestPage:(NSDictionary *)data{
    appTestTableViewController = [[AppTestTableViewController alloc]initWithStyle:UITableViewStylePlain];
    testTableViewHeight = 80 * ([[data objectForKey:@"huodong"] count] + [[data objectForKey:@"pingce"] count]) + 30*2;
    appTestTableViewController.tableView.frame = CGRectMake(-MainScreen_Width, 10, MainScreen_Width, 100);
    [self.view addSubview:appTestTableViewController.tableView];
    [appTestTableViewController setTestDetail:data];
    
    appTestTableViewController.testDetailDelegate = self.parentVC;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

#pragma  mark - webViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    NSString *meta = [NSString stringWithFormat:@"document.getElementsByName(\"viewport\")[0].content = \"width=%f, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no\"", webView.frame.size.width];
    [webView stringByEvaluatingJavaScriptFromString:meta];
    
    // 禁用用户选择
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitUserSelect='none';"];
    // 禁用长按弹出框
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitTouchCallout='none';"];
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{

        return sectionHeadView;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{

    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (cell_type) {
        
        case DETAIL_PAGE:
        {
            float height = [_appDetailView getAppDetailViewHeight];
            return height;
        }
            break;
        case DISCUSS_PAGE:
        {
            return cellHeight;
        }
            
            break;
        case RELEVANT_PAGE:
        {
            return relevantTableViewHeight+10;
        }
            break;
        case TEST_PAGE:
        {
            return testTableViewHeight;
        }
            break;
            
        default:
            return 100;
            break;
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return sectionHeadView_Height;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //只有一个cell,不使用重用
    UITableViewCell * cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    for (UIView *view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }
    //根据可能存在的详情\评论\相关应用\评测和活动等4个view动态改变调整cell的高度
    switch (cell_type) {
        case DETAIL_PAGE:
        {
            [cell.contentView addSubview:_appDetailView];
        }
            break;
        case DISCUSS_PAGE:
        {
//            [cell.contentView addSubview:discussWebView];
            discussWebView.frame = CGRectMake(0,  _headView.frame.size.height + sectionHeadView_Height, MainScreen_Width, self.tableView.frame.size.height - sectionHeadView_Height);
            [self.tableView addSubview:discussWebView];
        }
            break;
        case RELEVANT_PAGE:
        {
            
            appRelevantTableViewController.tableView.frame  = CGRectMake(0, 10, cell.frame.size.width, relevantTableViewHeight);
            appRelevantTableViewController.tableView.scrollEnabled = NO;
            [cell.contentView addSubview:appRelevantTableViewController.tableView];
        }
            break;
        case TEST_PAGE:
        {
            appTestTableViewController.tableView.frame  = CGRectMake(0, 10, cell.frame.size.width, testTableViewHeight);
            appTestTableViewController.tableView.scrollEnabled = NO;
            [cell.contentView addSubview:appTestTableViewController.tableView];
        }
            break;
            
        default:
            break;
    }
    cell.contentView.backgroundColor = WHITE_BACKGROUND_COLOR;
    return cell;
}

#pragma mark - 展开/收起阅读
//点击显示更多介绍
- (void)expandDetail{
    //需要根据服务器返回的文字内容获取真正要显示的字符串的占用高度;

    float detailNewHeight = [self getContentHeight:[_appDetailView getDetailContent]];
    
    [_appDetailView setExpandedDetailLabelHeight:detailNewHeight + 20];

    [LocalImageManager setImageName:@"recover_reading.png" complete:^(UIImage *image) {
        [_appDetailView.expandButton setImage:image forState:UIControlStateNormal];
    }];
    [_appDetailView.expandButton addTarget:self action:@selector(recoverDetail) forControlEvents:UIControlEventTouchUpInside];
    
    //防止tableview刷新时截图位置异常
    _appDetailView.scrollImageView.pagingEnabled  = NO;
    [self.tableView reloadData];
    _appDetailView.scrollImageView.pagingEnabled  = YES;
}

//收起更多
- (void)recoverDetail{
    [_appDetailView recoverDetailLabel];
    [LocalImageManager setImageName:@"expand_reading.png" complete:^(UIImage *image) {
        [_appDetailView.expandButton setImage:image forState:UIControlStateNormal];
    }];

    [_appDetailView.expandButton addTarget:self action:@selector(expandDetail) forControlEvents:UIControlEventTouchUpInside];
    
    //防止tableview刷新时截图位置异常
    _appDetailView.scrollImageView.pagingEnabled  = NO;
    [self.tableView reloadData];
    _appDetailView.scrollImageView.pagingEnabled  = YES;
}

//计算介绍label内 的内容高度
- (float)getContentHeight:(NSString *)content{
    CGSize constraint = CGSizeMake(self.tableView.frame.size.width - 20*2, 20000.0f);
    
    //    CGSize size = [text sizeWithFont:[UIFont systemFontOfSize:FONT_SIZE] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    //    boundingRectWithSize:options:attributes:context:
    CGRect rect;
    if(IOS7){
        NSDictionary *attribute = @{NSFontAttributeName: [UIFont systemFontOfSize:DETAIL_FONT_SIZE]};
        rect = [content boundingRectWithSize:constraint options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:attribute context:nil];
            return rect.size.height;
    }else{
        CGSize size = [content sizeWithFont:[UIFont systemFontOfSize:DETAIL_FONT_SIZE] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
        return size.height;
    }
    


}
- (void)promoteApp{

    if ([searchManager getRecommendState:appID_]) {
        [[NSNotificationCenter defaultCenter]postNotificationName:PROMOTE_INFO_SHOW object:ALREADY_PROMOTED];
    }else{
        [[NSNotificationCenter defaultCenter]postNotificationName:PROMOTE_INFO_SHOW object:PROMOTE_SUCCESS];
        
        //将推荐过的应用写入本地
        [searchManager setAppRecommendKid:appID_];
        //更新推荐按钮状态
        [self.parentVC checkPraiseButtonState];
        //向服务器发送信息
//        [searchServerManager requestRecommendApp:appID_];
        [[ReportManage instance] reportClickZan:CLICK_ZAN_APP typeid:appID_];
        
        
        
//        NSString *praiseCount = [_headView getPraiseCount];
//        if ([praiseCount rangeOfString:@"."].location == NSNotFound&&[praiseCount rangeOfString:@"万"].location == NSNotFound) {
//            praiseCount = [NSString stringWithFormat:@"%d",[praiseCount integerValue] + 1];
//        }
//        [_headView resetPraiseCount:praiseCount];
    }
}



//控制详情,评论等页签的显示
- (void )showPageWithIndex:(int)index{
    [self moveSepetate_arrowToButton:index];
    if (index != DISCUSS_PAGE) {
        //使discussWebView 失去响应焦点,达到收起键盘目的
        [discussWebView stringByEvaluatingJavaScriptFromString:@"document.activeElement.blur()"];
        discussWebView.frame = CGRectMake(-MainScreen_Width, 0, MainScreen_Width, 400);
    }else{
        discussWebView.frame = CGRectMake(0,  _headView.frame.size.height + sectionHeadView_Height, MainScreen_Width, self.tableView.frame.size.height  - sectionHeadView_Height);
    }
    cell_type = index;
    [self.tableView reloadData];

}
//将标签指示箭头移动到当前标签的底部,改变标题颜色
- (void)moveSepetate_arrowToButton:(int) index{
    //将页签按钮颜色还原
    [self.detailsButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.discussButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.relevantAppsButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.testButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];

    CGRect currentButtonFrame;
    switch (index) {
        case DETAIL_PAGE:
            //默认为显示详情页签,这时候的self.detailButton.frame = CGRectZero,会造成箭头位置错误;
//            currentButtonFrame = self.detailsButton.frame;
            currentButtonFrame =self.detailsButton.frame;
            [self.detailsButton setTitleColor:MY_YELLOW_COLOR forState:UIControlStateNormal];
            break;
        case DISCUSS_PAGE:
            currentButtonFrame = self.discussButton.frame;
            [self.discussButton setTitleColor:MY_YELLOW_COLOR forState:UIControlStateNormal];

            break;
        case RELEVANT_PAGE:
            currentButtonFrame = self.relevantAppsButton.frame;
            [self.relevantAppsButton setTitleColor:MY_YELLOW_COLOR forState:UIControlStateNormal];

            break;
        case TEST_PAGE:
            currentButtonFrame = self.testButton.frame;
            [self.testButton setTitleColor:MY_YELLOW_COLOR forState:UIControlStateNormal];

            break;
        default:
            
            break;
    }
    [UIView animateWithDuration:0.3 animations:^{
        sepetate_arrow.frame = CGRectMake(currentButtonFrame.origin.x + currentButtonFrame.size.width *0.5 - 5, currentButtonFrame.origin.y + currentButtonFrame.size.height + 9, 11, 9);
    }];
}


#pragma mark -
- (void)showDetailsPage{
    [self showPageWithIndex:DETAIL_PAGE];
}
- (void)showDiscussPage{
//    [self initDiscussPage:discussURLString];
    [self showPageWithIndex:DISCUSS_PAGE];

}
- (void)showRelevantPage{
    [self showPageWithIndex:RELEVANT_PAGE];
}
- (void)showTestPage{
    [self showPageWithIndex:TEST_PAGE];

}
//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
//    
//}
#pragma mark - 请求应用数据
- (void)prepareAppContent:(NSString *)appID pos:(NSString *)pos{
    appID_ = appID;
    atLeastOnePreviewSuccess = NO;
    [[MyServerRequestManager getManager] requestAppInformation:appID_ userData:self];
}

//当截图下载失败时,点击失败状态菊花
-(void)retryPreviews{
    if ([introImagesURL count]==0) {
        return;
    }else{
        for (NSString *URLString in introImagesURL) {
            NSURL *imageURL = [NSURL URLWithString:URLString];
            [searchManager downloadImageURL:imageURL userData:appID_];
        }
    }

}
#pragma mark - marketServerDelegate
-(BOOL)checkData_appInformation:(NSDictionary*)dataDic {

    NSDictionary * data = [dataDic getNSDictionaryObjectForKey:@"data"];
    if(!data)
        return NO;
    
    //应用信息
    NSDictionary * detailApp = data;
    if(!IS_NSDICTIONARY(detailApp))
        return NO;
    
    if(

//       [detailApp getNSStringObjectForKey:@"appdeveloper"] &&
       [detailApp getNSStringObjectForKey:@"appdevice"] &&
       [detailApp getNSStringObjectForKey:@"appdowncount"] &&
       [detailApp getNSStringObjectForKey:@"appiconurl"] &&
       [detailApp getNSStringObjectForKey:@"appid"] &&
       [detailApp getNSStringObjectForKey:@"appintro"] &&
       [detailApp getNSStringObjectForKey:@"appminosver"] &&
       [detailApp getNSStringObjectForKey:@"appname"] &&
       [detailApp getNSStringObjectForKey:@"appprice"] &&
       [detailApp getNSStringObjectForKey:@"appreputation"] &&
       [detailApp getNSStringObjectForKey:@"appdisplaysize"] &&
       [detailApp getNSStringObjectForKey:@"appupdatetime"] &&
       [detailApp getNSStringObjectForKey:@"appversion"] &&
       [detailApp getNSStringObjectForKey:@"category"] &&
       [detailApp getNSStringObjectForKey:@"displayversion"] &&
       [detailApp getNSStringObjectForKey:@"plist"] &&
       [detailApp getNSStringObjectForKey:@"appdetailinfo"] &&
       [detailApp getNSStringObjectForKey:@"appdigitalid"] &&
       [detailApp getNSStringObjectForKey:@"ipadetailinfor"] &&
       [detailApp getNSStringObjectForKey:@"appcommenturl"]
//       [detailApp getNSStringObjectForKey:@"share_url"]
//       [detailApp getNSStringObjectForKey:@"xxFlag"]
       
       
       //评论页地址
       //kid
       //otaPlist,appinserttime,appdetailinfo,installtype,appdigitalid,appcommenturl
       //ipadetailinfor,apppreviewimages
       //evaluating,relatedapps,activity
       ){
        
    }else{
        return NO;
    }
    
//暂时关闭活动和评测检测
    
/*
    //活动
    NSArray * activity = [detailApp getNSArrayObjectForKey:@"activity"];
    if(activity){
        for (NSDictionary * item in activity){
            if( !IS_NSDICTIONARY(item) )
                return NO;
            
            if( [item getNSStringObjectForKey:@"article_type"] &&
               [item getNSStringObjectForKey:@"content"]&&
               [item getNSStringObjectForKey:@"content_url"]&&
               [item getNSStringObjectForKey:@"content_url_open_type"]&&
               [item getNSStringObjectForKey:@"date"]&&
               [item getNSStringObjectForKey:@"id"]&&
               [item getNSStringObjectForKey:@"op_source"]&&
               [item getNSNumberObjectForKey:@"reputation_num"]&&
               [item getNSStringObjectForKey:@"share_word"]&&
               [item getNSStringObjectForKey:@"title"]&&
               [item getNSStringObjectForKey:@"titleImg"]&&
               [item getNSStringObjectForKey:@"viewCount"] )
            {
                
            }else{
                return NO;
            }
        }
    }
    
    //评测
    NSArray * evaluating = [detailApp getNSArrayObjectForKey:@"evaluating"];
    if(evaluating){
        for (NSDictionary * item in evaluating){
            if( !IS_NSDICTIONARY(item) )
                return NO;
            
            if( [item getNSStringObjectForKey:@"article_type"] &&
               [item getNSStringObjectForKey:@"content"]&&
               [item getNSStringObjectForKey:@"content_url"]&&
               [item getNSStringObjectForKey:@"content_url_open_type"]&&
               [item getNSStringObjectForKey:@"date"]&&
               [item getNSStringObjectForKey:@"id"]&&
               [item getNSStringObjectForKey:@"op_source"]&&
               [item getNSNumberObjectForKey:@"reputation_num"]&&
               [item getNSStringObjectForKey:@"share_word"]&&
               [item getNSStringObjectForKey:@"title"]&&
               [item getNSStringObjectForKey:@"titleImg"]&&
               [item getNSStringObjectForKey:@"viewCount"] )
            {
                
            }else{
                return NO;
            }
        }
    }
 
 */
    //相关应用
    NSArray *relatedapps = [detailApp getNSArrayObjectForKey:@"relatedapps"];
    if(relatedapps){
        for (NSDictionary * item in relatedapps){
            if( !IS_NSDICTIONARY(item) )
                return NO;
            
            if([item getNSStringObjectForKey:@"appdevice"] &&
               [item getNSStringObjectForKey:@"appdowncount"] &&
               [item getNSStringObjectForKey:@"appiconurl"] &&
               [item getNSStringObjectForKey:@"appid"] &&
               [item getNSStringObjectForKey:@"appintro"] &&
               [item getNSStringObjectForKey:@"appminosver"] &&
               [item getNSStringObjectForKey:@"appname"] &&
               [item getNSStringObjectForKey:@"appprice"] &&
               [item getNSStringObjectForKey:@"appreputation"] &&
               [item getNSStringObjectForKey:@"appdisplaysize"] &&
               [item getNSStringObjectForKey:@"appupdatetime"] &&
               [item getNSStringObjectForKey:@"appversion"] &&
               [item getNSStringObjectForKey:@"category"] &&
               [item getNSStringObjectForKey:@"displayversion"] &&
               [item getNSStringObjectForKey:@"plist"] &&
               [item getNSStringObjectForKey:@"appdigitalid"] &&
               [item getNSStringObjectForKey:@"ipadetailinfor"] )
            {
                
            }else{
                return NO;
            }
        }
    }
    
    //截图检测

    NSArray * previews = [detailApp getNSArrayObjectForKey:@"APPPREVIEWURLS"];
    if(previews){
        for (NSString * url in previews) {
            if(!IS_NSSTRING(url))
                return NO;
        }
    }
    
    return YES;
}


-(BOOL)checkData_appdetailinfo:(NSDictionary *) tmpDic {
    
    if( !IS_NSDICTIONARY(tmpDic) )
        return NO;
    
    
    NSArray * previews = [tmpDic getNSArrayObjectForKey:@"APPPREVIEWURLS"];
    if(!previews)
        return NO;
    
    for (NSString * url in previews) {
        if(!IS_NSSTRING(url))
            return NO;
    }
    
    
    return YES;
}
- (BOOL)checkData_appIntroText:(NSDictionary *) tmpDic {
    NSString *introText = [tmpDic getNSStringObjectForKey:@"APPDETAILINTRO"];
    if (!introText||!IS_NSSTRING(introText)) {
        return NO;
    }
    return YES;
}


- (void)appInformationRequestSucess:(NSDictionary*)dataDic appid:(NSString*)appid userData:(id)userData{
    
    if (self != userData) {
        return;
    }
    
    if (!IS_NSDICTIONARY(dataDic)) {
        [self checkDataError];
        return;
    }
    
    if(![self checkData_appInformation:dataDic]){
        [self checkDataError];
        return;
    }
    
    //隐藏加载视图
    [self.parentVC showDetailTableView];

    //根据内容设置需要显示的tag页(详情\评论\相关应用\评测活动,前两个必显示)

    
    //相关应用
    
    NSArray *relatedApps = [[dataDic objectForKey:@"data"] objectForKey:@"relatedapps"];
    if (!relatedApps) {
        relatedApps = [NSArray array];
    }
    if ([relatedApps count] > 0) {
        [self initRelevantPage:relatedApps];
    }
    //活动
    NSDictionary *activity = [[dataDic objectForKey:@"data"] objectForKey:@"activity"];
    NSDictionary *evaluating = [[dataDic objectForKey:@"data"] objectForKey:@"evaluating"];
    
//    NSMutableDictionary *testDic = [NSMutableDictionary dictionary];
//    [testDic setObject:activity forKey:@"huodong"];
//    [testDic setObject:evaluating forKey:@"pingce"];
//    [self initTestPage:testDic];
    
    [self shouldRelevantPageShow:[relatedApps count] > 0?NO:YES TestPageShow:[activity count] + [evaluating count] > 0?NO:YES];

    
    //详情页常规信息
    [self.headView initAppInforWithData:dataDic ];
    [self.appDetailView setAppInfor:dataDic];

    //设置下载按钮状态
    appInforDic = [NSMutableDictionary dictionaryWithDictionary:[dataDic objectForKey:@"data"]];
    if(self.mianLiuPlist.length > 0){
        [appInforDic setObject:self.mianLiuPlist forKey:@"plist"];
    }
    
    [buttonManager setDownloadButton:self.headView.appStateButton withAppInforDic:appInforDic andDetailSoure:self.detailSource andUserData:buttonManager];
    
    //请求icon
        [SearchManager getObject].delegate = nil;//之前的delegate是SearchResultTabelViewController
    searchManager = [[SearchManager alloc]init];
    searchManager.delegate = self;
    NSString* imageUrl = [[dataDic objectForKey:@"data"]  objectForKey:@"appiconurl"];
    imageUrl = [FileUtil URLEncodedString:imageUrl];
    iconURL = [[NSURL alloc ]initWithString:imageUrl];
    [searchManager downloadImageURL:iconURL  userData:appID_];
    
    introImagesURL = [[NSArray alloc ] initWithArray:[[dataDic objectForKey:@"data" ] objectForKey:@"appipadpreviewimages"]];
    
    //截图
    [self previewsActivity:introImagesURL && introImagesURL.count>0?Loading:Hidden];

    
    for (NSString *URLString in introImagesURL) {
//        NSString* encodeUrlStr = [FileUtil URLEncodedString:URLString];
        NSURL *imageURL = [NSURL URLWithString:URLString];
        [searchManager downloadImageURL:imageURL userData:appID_];
    }
    
    NSString *appdetailInfo = [[dataDic objectForKey:@"data"] objectForKey:@"appdetailinfo"];
    [self.appDetailView setDetailContent:appdetailInfo];
    //获取应用详细介绍
    NSString* detailIntroduction = [[dataDic objectForKey:@"data"] objectForKey:@"appintro"];//[FileUtil URLEncodedString:];
//    NSURL *dataURL = [NSURL URLWithString:detailIntroduction];
    
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        NSData *data = [NSData dataWithContentsOfURL:dataURL];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            //data转成截图地址数组和详细介绍字符串
//            NSDictionary *tmpDic =[searchManager getDetailAppDetailIntroStr:data] ;
//
//            //显示详细文字
//            
//            if (![self checkData_appIntroText:tmpDic]) {
////                [self checkDataError];
//                return;
//            }
    NSString *detailText  = detailIntroduction;//[tmpDic objectForKey:@"appintro"];
            [self.appDetailView setDetailContent:detailText];
            if ([self getContentHeight:detailText]/DETAIL_FONT_SIZE <5) {
                self.appDetailView.expandButton.hidden = YES;
                [self.appDetailView layoutSubviews];
            }else{
                self.appDetailView.expandButton.hidden = NO;
                [self.appDetailView layoutSubviews];
            }
//        });
//        
//    });
    
    
    //初始化评论页签
    discussURLString = [[dataDic objectForKey:@"data"] objectForKey:@"appcommenturl" ];
    [self initDiscussPage:discussURLString];
    discussWebView.frame  =  CGRectMake(-MainScreen_Width, 0, MainScreen_Width, 400);
    
 
    [self.parentVC lockFunctionButton:NO];

}

- (void)checkDataError{
    [self.parentVC hideDetailTableView];
    NSLog(@"详情页数据检测出现问题");
}
- (void)appInformationRequestFail:(NSString*)appid userData:(id)userData{
    if (!IS_NSSTRING(appid)) {
        return;
    }
    if (self != userData) {
        return;
    }else{
        [self.parentVC hideDetailTableView];
        [self.parentVC lockFunctionButton:YES];
    }
}

-(BOOL)checkData:(NSDictionary*)dataDic {
    NSArray * apps = [dataDic getNSArrayObjectForKey:@"data"];
    if(!apps){
        return NO;
    }

    for (NSDictionary * dicItem in apps){
        if(!IS_NSDICTIONARY(dicItem))
            return NO;
        
        if(
        [dicItem getNSStringObjectForKey:@"appdowncount"]&&
        [dicItem getNSStringObjectForKey:@"appiconurl"]&&
        [dicItem getNSStringObjectForKey:@"appid"]&&
        [dicItem getNSStringObjectForKey:@"appintro"]&&
        [dicItem getNSStringObjectForKey:@"appname"]&&
        [dicItem getNSStringObjectForKey:@"appreputation"]&&
        [dicItem getNSStringObjectForKey:@"appsize"]&&
        [dicItem getNSStringObjectForKey:@"appupdatetime"]&&
        [dicItem getNSStringObjectForKey:@"appversion"]&&
        [dicItem getNSStringObjectForKey:@"category"]&&
        [dicItem getNSStringObjectForKey:@"ipadetailinfor"]&&
        [dicItem getNSStringObjectForKey:@"plist"]&&
        [dicItem getNSStringObjectForKey:@"share_url"])
        {
            
        }else{
            return NO;
        }
    }
    
    return YES;
}

//相关应用新接口
- (void)developerCompangProductListRequestSucess:(NSDictionary*)dataDic developerName:(NSString*)developerName pageCount:(int)pageCount appid:(NSString*)appid userData:(id)userData{
    if (self != userData) {
        return;
    }
    if (!IS_NSDICTIONARY(dataDic)) {
        return;
    }
    if (![self checkData:dataDic]) {
        return;
    }
    [self initRelevantPage:[dataDic objectForKey:@"data"]];
}

- (void)developerCompangProductListRequestFail:(NSString*)developerName pageCount:(int)pageCount appid:(NSString*)appid userData:(id)userData{
    if (self != userData) {
        return;
    }
    NSLog(@"返回厂商相关应用失败");
}

- (void)recommendSucessUpdateServer:(NSString *)kid{
    NSLog(@"推荐成功");
    
}

- (void)recommendUpdateServerFail:(NSString *)kid{
    NSLog(@"推荐失败");
}

#pragma mark - SearchManagerDelegate

//返回图片
- (void)getImageSucessFromImageUrl:(NSString *)urlStr image:(UIImage *)image userData:(id)userdata{
    if (![appID_ isEqualToString:userdata]) {
        return;
    }
    if (![image isKindOfClass:[UIImage class]]) {
        return;
    }
    if ([urlStr isEqualToString:iconURL.absoluteString ]) {
        [self.headView setIconImage:image];
        self.parentVC.icon = image;
    }else{
        int index = [introImagesURL indexOfObject:[FileUtil URLDecodedString:urlStr]];
        if (index == NSNotFound) {
            return;
        }
        //图片成功下载,隐藏加载菊花,显示截图scrollView
        [self previewsActivity:Hidden];
        atLeastOnePreviewSuccess = YES;
        
        //根据图片尺寸,调整截图scrollView默认图;
        //图片比例判断,是iphone4还是iphone5
        if (!self.isPreviewSizeFixed) {
            self.isPreviewSizeFixed  = YES;
            float f1 = image.size.height *1.0/image.size.width;
            float f2 = IMAGES_SCROLLVIEW_HEIGHT *1.0/IMAGES_SCROLLVIEW_WEIGHT;
            if (f1>f2) {
                [self.appDetailView resetPreviewsFrameWithWidth:IMAGES_SCROLLVIEW_WEIGHT_IPHONE5 withCount:MIN([introImagesURL count],6)];
            }else{
                [self.appDetailView resetPreviewsFrameWithWidth:IMAGES_SCROLLVIEW_WEIGHT withCount:MIN([introImagesURL count],6)];
            }
        }
        
        if (index < 6) {
            [self.appDetailView setIntroImage:image withPageIndex:index pageCount:MIN([introImagesURL count],6)];
        }
    }
}
- (void)getImageFailFromUrl:(NSString *)urlStr userData:(id)userdata{
    if (![appID_ isEqualToString:userdata]) {
        return;
    }
    if (![urlStr isEqualToString:iconURL.absoluteString ]&&!atLeastOnePreviewSuccess) {
        [self previewsActivity:Failed];
    }
}
#pragma mark-
#pragma mark 显示和隐藏截图转菊

//根据截图的下载情况显示加载菊花或截图所在的scrollView
- (void)previewsActivity:(int)status{
    [_backView setStatus:status];
    switch (status) {
        case Failed:
            _appDetailView.scrollImageView.hidden = YES;
            break;
        case Loading:
            _appDetailView.scrollImageView.hidden = YES;
            break;
        case Hidden:
            _appDetailView.scrollImageView.hidden = NO;
            break;
        default:
            break;
    }
}

#pragma mark - 是否隐藏相关应用和评测页签
- (void)shouldRelevantPageShow:(BOOL)hidden TestPageShow:(BOOL)hidden_{
    self.relevantAppsButton.hidden = hidden;
    self.testButton.hidden = hidden_;
    
    //初始化页签按钮
    tagButtons = [NSMutableArray arrayWithObjects:self.detailsButton,self.discussButton,nil];
    if (!hidden) {
        [tagButtons addObject:self.relevantAppsButton];
    }
    if (!hidden_) {
        [tagButtons addObject:self.testButton];
    }
    float boarer = (MainScreen_Width - TAG_BUTTON_WEIGHT * [tagButtons count])/([tagButtons count] + 1);
    
    for (int i = 0; i<[tagButtons count]; i++) {
        UIButton *button =  tagButtons[i];
        button.frame = CGRectMake(boarer *(i+1) + TAG_BUTTON_WEIGHT * i, 0, TAG_BUTTON_WEIGHT, 20);
    }
    [self moveSepetate_arrowToButton:DETAIL_PAGE];
    
}
- (void)hideTestPage{
    appTestTableViewController.view.hidden = YES;
}
#pragma mark - scrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    if (scrollView !=_appDetailView.scrollImageView) {
        return;
    }
    if ([_appDetailView getCurrentImgWidth] ==IMAGES_SCROLLVIEW_WEIGHT) {
        currentIndex = CONTENTOFFSET_X/(PREVIEW_SCROLLVIEW_WEIGTH + BOARDER_WIDTH);
    }else if ([_appDetailView getCurrentImgWidth] ==IMAGES_SCROLLVIEW_WEIGHT_IPHONE5){
        currentIndex = CONTENTOFFSET_X/(IMAGES_SCROLLVIEW_WEIGHT_IPHONE5 + BOARDER_WIDTH);
    }
    if ([_appDetailView getImagesCount]!=1&& (scrollView.contentOffset.x>=scrollView.contentSize.width  - MainScreen_Width) ){
        
        [scrollView setContentOffset:CGPointMake(scrollView.contentSize.width  - MainScreen_Width, 0) animated:NO];
        currentIndex = [_appDetailView getImagesCount];
       _appDetailView.scrollImageView.pagingEnabled = NO;
    }
    if ([_appDetailView getImagesCount]!=1&& (scrollView.contentOffset.x< scrollView.contentSize.width  - MainScreen_Width) ) {
        _appDetailView.scrollImageView.pagingEnabled = YES;
    }
    [_appDetailView setPageControl:currentIndex ];
}

//平稳拖动,松手时调用
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{

}
 // called when setContentOffset/scrollRectVisible:animated: finishes. not called if not animating
-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    //pageControll
    
}
// called on finger up as we are moving
//快速拖动,松手后,scrollView未停止滚动
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    
}
//快速拖动,scrollView停止后
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{


}

#pragma mark -
- (AppTestTableViewController *)getTestTableViewController{
    return appTestTableViewController;
}
//- (AppRelevantTableViewController *)getRelevantTableViewController{
//    return appRelevantTableViewController;
//}
#pragma mark - unloadData
- (void)unloadData{
    
}
- (void)setRelevantAppsNil{
    [appRelevantTableViewController setRelevantData:nil];
}

- (void)setRelevantSizeZero{
    relevantTableViewHeight = 37;
}
- (void)setIntroTextNil{
    
}

@end
