//
//  MyServerRequestManager.m
//  MyHelper
//
//  Created by liguiyang on 14-12-23.
//  Copyright (c) 2014年 myHelper. All rights reserved.
//

#import "MyServerRequestManager.h"
#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"
#import "CJSONDeserializer.h"
#import "TMCache.h"
#import "DESUtils.h"
#import "FileUtil.h"

#define MODIFY_TIME @"ModifyTime"

@interface MyServerRequestManager ()
{
}

@property (nonatomic, strong) NSMutableArray *listeners;


@end

static MyServerRequestManager *serverRequestManager = nil;

@implementation MyServerRequestManager

+ (MyServerRequestManager *)getManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serverRequestManager = [[MyServerRequestManager alloc] init];
    });
    
    return serverRequestManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.listeners = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)addListener:(id<MyServerRequestManagerDelegate>)listener
{ //
    if (NSNotFound == [_listeners indexOfObject:listener]) {
        [self.listeners addObject:listener];
    }
}

- (void)removeListener:(id<MyServerRequestManagerDelegate>)listener
{
    if (NSNotFound != [_listeners indexOfObject:listener]) {
        [self.listeners removeObject:listener];
    }
}

#pragma mark - Request methods
#pragma mark 精彩推荐
- (void)requestWonderfulRecommendList:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData;
{
    isUseCache = NO;
    NSString *path = @"/recommend/getRecommend";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld",(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(wonderfulRecommendRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj wonderfulRecommendRequestSuccess:cacheData pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(wonderfulRecommendRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj wonderfulRecommendRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(wonderfulRecommendRequestFailed:isUseCache:userData:)]) {
                    [obj wonderfulRecommendRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(wonderfulRecommendRequestFailed:isUseCache:userData:)]) {
                    [obj wonderfulRecommendRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
                    DeLog(@"精彩推荐请求失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
    
}

#pragma mark 最新应用/游戏
- (void)requestLatestAppGameList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
//    http://123.56.228.139:83/app/newest?page=1&type=app
    isUseCache = NO;
    NSString *path = @"/app/newest";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld&type=%@",(long)pageCount,(tagType==tagType_app)?@"app":@"game"];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
//    NSString *reqStr = @"http://123.56.228.139:83/app/newest?page=1&type=app";
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(latestAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj latestAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(latestAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj latestAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(latestAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj latestAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(latestAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj latestAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"最新应用/游戏失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 排行榜 应用/游戏
- (void)requestRankingAppGameList:(TagType)tagType rankingType:(RankingType)rankingType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
//    NSString *path = @"/app/rank";
//    NSString *parameter = [NSString stringWithFormat:@"page=%ld&tag=%@&rankType=%@",(long)pageCount,(tagType==tagType_app)?@"app":@"game",[self getRankType:rankingType]];
//    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
//    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    NSString *path = @"/rank/index";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld&type=%@",(long)pageCount,(tagType==tagType_app)?@"app":@"game"];
    NSString *cacheStr = [self getReqString:path httpParameter:parameter];
    NSString *reqStr = cacheStr;
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(rankingAppGameRequestSuccess:TagType:rankingType:pageCount:isUseCache:userData:)]) {
                        [obj rankingAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType rankingType:rankingType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(rankingAppGameRequestSuccess:TagType:rankingType:pageCount:isUseCache:userData:)]) {
                        [obj rankingAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType rankingType:rankingType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(rankingAppGameRequestFailed:rankingType:pageCount:isUseCache:userData:)]) {
                    [obj rankingAppGameRequestFailed:tagType rankingType:rankingType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(rankingAppGameRequestFailed:rankingType:pageCount:isUseCache:userData:)]) {
                    [obj rankingAppGameRequestFailed:tagType rankingType:rankingType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"排行榜应用/游戏失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 分类 应用/游戏
- (void)requestCategoryAppGameList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
//    http://123.56.228.139:83/category/getCategorys?type=game
    isUseCache = NO;
    NSString *path = @"/category/getCategorys";
    NSString *parameter = [NSString stringWithFormat:@"type=%@",(tagType==tagType_app)?@"app":@"game"];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(categoryAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj categoryAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(categoryAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj categoryAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(categoryAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj categoryAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(categoryAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj categoryAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"分类 应用/游戏失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 分类列表
- (void)requestCategoryList:(NSInteger)categoryId pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
//    http://123.56.228.139:83/category-App/appList?categoryid=6000&page=1
    isUseCache = NO;
    NSString *path = @"/category-App/appList";
    NSString *parameter = [NSString stringWithFormat:@"categoryid=%ld&page=%ld",(long)categoryId,(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(categoryListRequestSuccess:categoryId:pageCount:isUseCache:userData:)]) {
                        [obj categoryListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] categoryId:categoryId pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(categoryListRequestSuccess:categoryId:pageCount:isUseCache:userData:)]) {
                        [obj categoryListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] categoryId:categoryId pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(categoryListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj categoryListRequestFailed:categoryId pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(categoryListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj categoryListRequestFailed:categoryId pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"分类列表失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 优秀 应用/游戏
- (void)requestExcellentAppGameList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = (tagType==tagType_app)?@"/great/app":@"/great/game";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld",(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(excellentAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj excellentAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(excellentAppGameRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj excellentAppGameRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(excellentAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj excellentAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(excellentAppGameRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj excellentAppGameRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"优秀 应用/游戏失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 发现
- (void)requestDiscoveryList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/article/articleList";
    NSString *parameter = [NSString stringWithFormat:@"type=%@&page=%ld",[self getDiscoveryType:tagType],(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(discoveryRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj discoveryRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(discoveryRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj discoveryRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(discoveryRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj discoveryRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(discoveryRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj discoveryRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
//                    NSError *error = [requestSelf error];
//                    NSLog(@"发现 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 搜索联想词
- (void)requestSearchAssociativeWordList:(NSInteger)pageCount keyWord:(NSString *)keyWord isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/app-search/association";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld&keyword=%@",(long)pageCount,keyWord];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    NSURL *reqURL = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqURL];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(searchAssociativeWordRequestSuccess:pageCount:keyWord:isUseCache:userData:)]) {
                        [obj searchAssociativeWordRequestSuccess:map pageCount:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(searchAssociativeWordRequestFailed:keyWord:isUseCache:userData:)]) {
                    [obj searchAssociativeWordRequestFailed:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                }
            }];
        });
    }];
    
    [request setFailedBlock:^{
        [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj respondsToSelector:@selector(searchAssociativeWordRequestFailed:keyWord:isUseCache:userData:)]) {
                [obj searchAssociativeWordRequestFailed:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                NSError *error = [requestSelf error];
//                NSLog(@"搜索联想词失败: %@",error);
            }
        }];
    }];
}

#pragma mark 搜索列表
- (void)requestSearchList:(NSInteger)pageCount keyWord:(NSString *)keyWord isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = [NSString stringWithFormat:@"/app-search/search?page=%ld&keyword=",(long)pageCount];
//    app-search/search?page=1&keyword=%E5%B0%8F%E9%B8%9F
//    NSString *parameter = [NSString stringWithFormat:@"%@",keyWord];
    NSString *reqStr = [self getRequestURLStringEncodeNotUsingShuXian:path httpParameter:keyWord];
//    NSString *reqStr = [self getRequestURLStringNotUsingShuXian:path httpParameter:parameter];
    
    NSURL *reqURL = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqURL];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(searchListRequestSuccess:pageCount:keyWord:isUseCache:userData:)]) {
                        [obj searchListRequestSuccess:map pageCount:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(searchListRequestFailed:keyWord:isUseCache:userData:)]) {
                    [obj searchListRequestFailed:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
                    DeLog(@"搜索列表失败: %@",error);
                }
            }];
        });
    }];
    
    [request setFailedBlock:^{
        [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj respondsToSelector:@selector(searchListRequestFailed:keyWord:isUseCache:userData:)]) {
                [obj searchListRequestFailed:pageCount keyWord:keyWord isUseCache:isUseCache userData:userData];
                NSError *error = [requestSelf error];
                DeLog(@"搜索列表失败: %@",error);
            }
        }];
    }];
}

#pragma mark - 摇一摇热词

- (void)requestSearchHotWords:(BOOL)firstFlag isUseCache:(BOOL)isUseCache userData:(id)userData;
{
    isUseCache = NO;
    NSString *path = firstFlag?@"/app-search/hotWords":@"/app-search/hotWordsShake";
    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:reqStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(hotWordsRequestSuccess:isUseCache:userData:)]) {
                        NSArray *dataArray = [(NSDictionary *)[[TMCache sharedCache] objectForKey:reqStr] objectForKey:@"data"];
                        [obj hotWordsRequestSuccess:dataArray isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:reqStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:reqStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:reqStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(hotWordsRequestSuccess:isUseCache:userData:)]) {
                        NSArray *dataArray = [(NSDictionary *)[[TMCache sharedCache] objectForKey:reqStr] objectForKey:@"data"];
                        [obj hotWordsRequestSuccess:dataArray isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(hotWordsRequestFailed:userData:)]) {
                    [obj hotWordsRequestFailed:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(hotWordsRequestFailed:userData:)]) {
                    [obj hotWordsRequestFailed:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"摇一摇热词 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
    
}

#pragma mark 付费金榜 应用/游戏列表
- (void)requestPaidList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
//    http://123.56.228.139:83/charge-app/list?page=1&tag=app
    NSString *path = @"/charge-app/list";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld&tag=%@",(long)pageCount,(tagType==tagType_app)?@"app":@"game"];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(paidListRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj paidListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(paidListRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj paidListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(paidListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj paidListRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(paidListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj paidListRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"付费金榜 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 免费畅玩 应用/游戏列表
- (void)requestFreeList:(TagType)tagType pageCount:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
//    http://123.56.228.139:83/free-app/list?page=1&tag=app
    NSString *path = @"/free-app/list";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld&tag=%@",(long)pageCount,(tagType==tagType_app)?@"app":@"game"];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(freeListRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj freeListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(freeListRequestSuccess:TagType:pageCount:isUseCache:userData:)]) {
                        [obj freeListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] TagType:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(freeListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj freeListRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(freeListRequestFailed:pageCount:isUseCache:userData:)]) {
                    [obj freeListRequestFailed:tagType pageCount:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"免费畅玩 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 限时免费
- (void)requestLimitFreeList:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
//    http://123.56.228.139:83/limited-free/list?page=1
    NSString *path = @"/limited-free/list";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld",(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(limitFreeRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj limitFreeRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(limitFreeRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj limitFreeRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(limitFreeRequestFailed:isUseCache:userData:)]) {
                    [obj limitFreeRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(limitFreeRequestFailed:isUseCache:userData:)]) {
                    [obj limitFreeRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"显示免费 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 装机必备
- (void)requestInstalledNecessaryList:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/necessary/list";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld",(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(installedNecessaryRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj installedNecessaryRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(installedNecessaryRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj installedNecessaryRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(installedNecessaryRequestFailed:isUseCache:userData:)]) {
                    [obj installedNecessaryRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(installedNecessaryRequestFailed:isUseCache:userData:)]) {
                    [obj installedNecessaryRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"装机必备 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 专题列表
- (void)requestSpecialList:(NSInteger)pageCount isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/special/list";
    NSString *parameter = [NSString stringWithFormat:@"page=%ld",(long)pageCount];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(specialListRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj specialListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(specialListRequestSuccess:pageCount:isUseCache:userData:)]) {
                        [obj specialListRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] pageCount:pageCount isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(specialListRequestFailed:isUseCache:userData:)]) {
                    [obj specialListRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(specialListRequestFailed:isUseCache:userData:)]) {
                    [obj specialListRequestFailed:pageCount isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"专题列表 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 专题详情
- (void)requestSpecialDetail:(NSString *)specialId isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/special/detail";
    NSString *parameter = [NSString stringWithFormat:@"specialId=%@",specialId];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(specialDetailRequestSuccess:specialId:isUseCache:userData:)]) {
                        [obj specialDetailRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] specialId:specialId isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSDICTIONARY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(specialDetailRequestSuccess:specialId:isUseCache:userData:)]) {
                        [obj specialDetailRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] specialId:specialId isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(specialDetailRequestFailed:isUseCache:userData:)]) {
                    [obj specialDetailRequestFailed:specialId isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(specialDetailRequestFailed:isUseCache:userData:)]) {
                    [obj specialDetailRequestFailed:specialId isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"专题详情 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 轮播图
- (void)requestCarouselDiagrams:(lunBoType)type isUseCache:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
    NSString *path = @"/gyrate/list";
    NSString *parameter = [NSString stringWithFormat:@"type=%@",[self getLunBoTypeName:type]];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(carouselDiagramsRequestSuccess:type:isUseCache:userData:)]) {
                        [obj carouselDiagramsRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] type:type isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSARRAY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(carouselDiagramsRequestSuccess:type:isUseCache:userData:)]) {
                        [obj carouselDiagramsRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] type:type isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(carouselDiagramsRequestFailed:isUseCache:userData:)]) {
                    [obj carouselDiagramsRequestFailed:type isUseCache:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(carouselDiagramsRequestFailed:isUseCache:userData:)]) {
                    [obj carouselDiagramsRequestFailed:type isUseCache:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"轮播图 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 首页混合数据
- (void)requestIndexMixedData:(BOOL)isUseCache userData:(id)userData
{
    isUseCache = NO;
//    http://123.56.228.139:83/index/mixData
    NSString *path = @"/index/mixData";
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *parameter = @"";//[NSString stringWithFormat:@"myVersion=%@",version];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(indexMixedDataRequestSuccess:isUseCache:userData:)]) {
                        [obj indexMixedDataRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSDICTIONARY([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:cacheStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:cacheStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:cacheStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(indexMixedDataRequestSuccess:isUseCache:userData:)]) {
                        [obj indexMixedDataRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:cacheStr] isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(indexMixedDataRequestFailed:userData:)]) {
                    [obj indexMixedDataRequestFailed:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(indexMixedDataRequestFailed:userData:)]) {
                    [obj indexMixedDataRequestFailed:isUseCache userData:userData];
                    NSError *error = [requestSelf error];
//                    NSLog(@"首页混合数据 失败: %@",error);
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 获取自身数字ID

- (void)getSelfDigitalId:(BOOL)isUseCache userData:(id)userData
{
    //http://123.56.228.139:83/update/getAppDigitalId
    isUseCache = NO;
    NSString *path = @"/update/getAppDigitalId";
    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
    
    // 使用缓存
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:reqStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(selfDigitalIdRequestSuccess:isUseCache:userData:)]) {
                        [obj selfDigitalIdRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:reqStr] isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSSTRING([map objectForKey:@"data"]) && IS_NSDICTIONARY([map objectForKey:@"flag"])) {
            NSDictionary *cacheDic = [[TMCache sharedCache] objectForKey:reqStr];
            if (cacheDic && [[[cacheDic objectForKey:@"flag"] objectForKey:@"md5"] isEqualToString:[[map objectForKey:@"flag"] objectForKey:@"md5"]]) {
                NSMutableDictionary *_cacheDic = [cacheDic mutableCopy];
                [_cacheDic setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_cacheDic forKey:reqStr];
            }
            else
            {
                NSMutableDictionary *_map = [map mutableCopy];
                [_map setObject:[self getCurrentSystemDate] forKey:MODIFY_TIME];
                [[TMCache sharedCache] setObject:_map forKey:reqStr];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(selfDigitalIdRequestSuccess:isUseCache:userData:)]) {
                        [obj selfDigitalIdRequestSuccess:(NSDictionary *)[[TMCache sharedCache] objectForKey:reqStr] isUseCache:isUseCache userData:userData];
                    }
                }];
            });
            
            return ; // avoid failed code path
        }
        
        // failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(selfDigitalIdRequestFailed:userData:)]) {
                    [obj selfDigitalIdRequestFailed:isUseCache userData:userData];
                }
            }];
        });
        
    }];
    
    // request failed
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(selfDigitalIdRequestFailed:userData:)]) {
                    [obj selfDigitalIdRequestFailed:isUseCache userData:userData];
                }
            }];
        });
        
        [self reportError:path response:[[requestSelf error] localizedDescription]];
    }];
}

#pragma mark 获取开关信息

- (void)requestAllSwitch{
    //http://123.56.228.139:83/basic-settings/allSwitch
    NSString *path = @"/basic-settings/allSwitch";
    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
    
    // 重新请求
    NSURL *reqUrl = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        // success
        if (map && IS_NSDICTIONARY([map objectForKey:@"data"])) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(requestAllSwitchSuccess:)]) {
                        [obj requestAllSwitchSuccess:[map objectForKey:@"data"]];
                    }
                }];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(requestAllSwitchFailed)]) {
                        [obj requestAllSwitchFailed];
                    }
                }];
            });
        }
    }];
    
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj respondsToSelector:@selector(requestAllSwitchFailed)]) {
                    [obj requestAllSwitchFailed];
                }
            }];
        });
    }];
}
//
//- (void)getRealViewSwitchInformation
//{
//    NSString *path = @"/basicSettings/realViewSwitch";
//    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
//    
//    // 重新请求
//    NSURL *reqUrl = [NSURL URLWithString:reqStr];
//    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
//    [request setTimeOutSeconds:10];
//    [request setDelegate:self];
//    [request setRequestMethod:@"GET"];
//    [request startAsynchronous];
//    __weak ASIFormDataRequest *requestSelf = request;
//    [request setCompletionBlock:^{
//        
//        NSString *responseStr = [requestSelf responseString];
//        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
//        
//        // success
//        if (map && IS_NSSTRING([map objectForKey:@"data"])) {
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(realViewSwitchRequestSuccess:)]) {
//                        NSString *key = [map objectForKey:@"data"];
//                        BOOL flag = [key isEqualToString:@"on"]?YES:NO;
//                        [obj realViewSwitchRequestSuccess:flag];
//                    }
//                }];
//            });
//        }
//        else
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(realViewSwitchRequestFailed)]) {
//                        [obj realViewSwitchRequestFailed];
//                    }
//                }];
//            });
//        }
//    }];
//    
//    [request setFailedBlock:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                if ([obj respondsToSelector:@selector(realViewSwitchRequestFailed)]) {
//                    [obj realViewSwitchRequestFailed];
//                }
//            }];
//        });
//    }];
//}
//
//- (void)requestEUSwitch{
//    NSString *path = @"/basicSettings/PCCheatDisplayRealContent";
//    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
//    
//    // 重新请求
//    NSURL *reqUrl = [NSURL URLWithString:reqStr];
//    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
//    [request setTimeOutSeconds:10];
//    [request setDelegate:self];
//    [request setRequestMethod:@"GET"];
//    [request startAsynchronous];
//    __weak ASIFormDataRequest *requestSelf = request;
//    [request setCompletionBlock:^{
//        
//        NSString *responseStr = [requestSelf responseString];
//        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
//        
//        // success
//        if (map && IS_NSSTRING([map objectForKey:@"data"])) {
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(requestEUSwichCSuccess:)]) {
//                        NSString *key = [map objectForKey:@"data"];
//                        BOOL flag = [key isEqualToString:@"display"]?YES:NO;
//                        [obj requestEUSwichCSuccess:flag];
//                    }
//                }];
//            });
//        }
//        else
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(requestEUSwichFailed)]) {
//                        [obj requestEUSwichFailed];
//                    }
//                }];
//            });
//        }
//    }];
//    
//    [request setFailedBlock:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                if ([obj respondsToSelector:@selector(requestEUSwichFailed)]) {
//                    [obj requestEUSwichFailed];
//                }
//            }];
//        });
//    }];
//}
//
//
//- (void)requestDirectlyGoAppStoreSwitch{//是否直接跳store,默认否
//    NSString *path = @"";
//    NSString *reqStr = [NSString stringWithFormat:@"%@%@",HEAD_REQSTR,path];
//    
//    // 重新请求
//    NSURL *reqUrl = [NSURL URLWithString:reqStr];
//    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:reqUrl];
//    [request setTimeOutSeconds:10];
//    [request setDelegate:self];
//    [request setRequestMethod:@"GET"];
//    [request startAsynchronous];
//    __weak ASIFormDataRequest *requestSelf = request;
//    [request setCompletionBlock:^{
//        
//        NSString *responseStr = [requestSelf responseString];
//        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
//        
//        // success
//        if (map && IS_NSSTRING([map objectForKey:@"data"])) {
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(requestDirectlyGoAppStoreSwitchSuccess:)]) {
//                        NSString *key = [map objectForKey:@"data"];
//                        BOOL flag = [key isEqualToString:@"yes"]?YES:NO;
//                        [obj requestDirectlyGoAppStoreSwitchSuccess:flag];
//                    }
//                }];
//            });
//        }
//        else
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    if ([obj respondsToSelector:@selector(requestDirectlyGoAppStoreSwitchFailed)]) {
//                        [obj requestDirectlyGoAppStoreSwitchFailed];
//                    }
//                }];
//            });
//        }
//    }];
//    
//    [request setFailedBlock:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                if ([obj respondsToSelector:@selector(requestDirectlyGoAppStoreSwitchFailed)]) {
//                    [obj requestDirectlyGoAppStoreSwitchFailed];
//                }
//            }];
//        });
//    }];
//    
//    
//}
#pragma mark - 应用详情
- (void)requestAppInformation:(NSString *)appid userData:(id)userData{
    
//    http://123.56.228.139:83/app-detail/detailInfo?appid= 307880732
    
//    NSString *path = @"/appDetail/detailINfo";
    NSString *path = @"/app-detail/detailInfo";
    NSString *parameter = [NSString stringWithFormat:@"appid=%@",appid];

    
//    //测试使用
//    NSString *parameter = [NSString stringWithFormat:@"appid=%@",@"KU3X3.bUDI0wFoSSL4QD.dvElT4mvz3vf.da1wkZPITeL.cZqH1M.d5LZe.biafpeGZk.b.dk"];
    NSString *cacheStr = [self getCacheURLString:path httpParameter:parameter];
    NSString *reqStr = [self getRequestURLString:path httpParameter:parameter];
    
//        NSString *reqStr = [NSString stringWithFormat:@"%@%@%@",HEAD_REQSTR,path,@"KU3X3.bUDI0wFoSSL4QD.dvElT4mvz3vf.da1wkZPITeL.cZqH1M.d5LZe.biafpeGZk.b.dk"];
    
    NSString*bodyStr = [NSString stringWithFormat:@"/appDetail/detailINfo?cry=appid=%@",appid];
    
    BOOL isUseCache = NO;
    
    if (isUseCache) {
        NSDictionary *cacheData = [[TMCache sharedCache] objectForKey:cacheStr];
        NSInteger cacheTime = [[[cacheData objectNoNILForKey:@"flag"] objectNoNILForKey:@"expire"] integerValue];
        NSDate *modifyDate = [cacheData objectNoNILForKey:MODIFY_TIME];
        NSTimeInterval timeInterval = [self timerIntervalFromDate:modifyDate];
        if (timeInterval <= cacheTime ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_listeners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj respondsToSelector:@selector(appInformationRequestSucess:appid:userData:)]) {
                        [obj appInformationRequestSucess:cacheData appid:(NSString*)appid userData:(id)userData];
                    }
                }];
            });
            
            return ; // 缓存数据已返回
        }
    }

    
    
    
    NSURL *url = [NSURL URLWithString:reqStr];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setTimeOutSeconds:10];
    [request setDelegate:self];
    [request setRequestMethod:@"GET"];
    [request startAsynchronous];
    __weak ASIFormDataRequest *requestSelf = request;
    [request setCompletionBlock:^{
        
        NSString *responseStr = [requestSelf responseString];
        NSDictionary *map = [self getDictionaryFromResponseString:responseStr];
        
        if (!map) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.listeners  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if( [obj respondsToSelector:@selector(appInformationRequestFail:userData:)] ) {
//                        NOT_DIC_ERROR(@"应用详情信息")
                        [obj appInformationRequestFail:appid userData:userData];
                        
                    }
                }];
            });
            
            [self reportError:bodyStr response: responseStr];
            
        }else{
            
            if ( IS_NSDICTIONARY([map objectForKey:@"data"])  ) {
                NSDictionary *saveDic = [[TMCache sharedCache] objectForKey:cacheStr];
                if (saveDic && [[saveDic objectForKey:@"md5"] isEqualToString:[map objectForKey:@"md5"]]) {
                    NSMutableDictionary *_saveDic = [NSMutableDictionary dictionaryWithDictionary:saveDic];
                    [_saveDic setObject:[self getCurrentSystemDate] forKey:@"ModifyTime"];
                    [[TMCache sharedCache] setObject:(NSDictionary*)_saveDic forKey:cacheStr];
                    
                }else{
                    
                    NSMutableDictionary *_map = [NSMutableDictionary dictionaryWithDictionary:map];
                    [_map setObject:[self getCurrentSystemDate] forKey:@"ModifyTime"];
                    [[TMCache sharedCache] setObject:(NSDictionary*)_map forKey:cacheStr];
                    
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.listeners  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        if( [obj respondsToSelector:@selector(appInformationRequestSucess:appid:userData:)] ) {
                            [obj appInformationRequestSucess:(NSDictionary *)[[TMCache sharedCache] objectForKey: cacheStr ] appid:appid userData:userData];
                            
                        }
                    }];
                });
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.listeners  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        if( [obj respondsToSelector:@selector(appInformationRequestFail:userData:)] ) {
                            [obj appInformationRequestFail:appid userData:userData];
                            
                        }
                    }];
                });
            }
        }
    }];
    
    [request setFailedBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.listeners  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if( [obj respondsToSelector:@selector(appInformationRequestFail:userData:)] ) {
                    NSError *error = [requestSelf error];
                    NSLog(@"应用详情信息请求失败---%@",error);
                    [obj appInformationRequestFail:appid userData:userData];
                    
                }
            }];
        });
        
        [self reportError:bodyStr response: [[requestSelf error] localizedDescription]];
    }];
    
}
#pragma mark - Utility

- (NSString *)getReqString:(NSString *)path httpParameter:(NSString *)parameter
{
    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
}


- (NSString *)getCacheURLString:(NSString *)path httpParameter:(NSString *)parameter
{
    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
//    return [NSString stringWithFormat:@"%@%@?cry=%@",HEAD_REQSTR,path,parameter];
}

- (NSString *)getRequestURLString:(NSString *)path httpParameter:(NSString *)parameter
{
    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
//    return [NSString stringWithFormat:@"%@%@?cry=%@",HEAD_REQSTR,path,[self getDESString:parameter]];
}

- (NSString *)getRequestURLStringEncode:(NSString *)path httpParameter:(NSString *)parameter
{
//    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
        return [NSString stringWithFormat:@"%@%@%@",HEAD_REQSTR,path,[self getDESString:parameter]];
}

- (NSString *)getRequestURLStringEncodeNotUsingShuXian:(NSString *)path httpParameter:(NSString *)parameter
{
    //    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
    return [NSString stringWithFormat:@"%@%@%@",HEAD_REQSTR,path,[self getDESString:parameter]];
}

- (NSString *)getRequestURLStringNotUsingShuXian:(NSString *)path httpParameter:(NSString *)parameter
{
    //    return [NSString stringWithFormat:@"%@%@?%@",HEAD_REQSTR,path,parameter];
    return [NSString stringWithFormat:@"%@%@%@",HEAD_REQSTR,path,parameter];
}

- (NSString *)getDESString:(NSString *)string{
    return [[FileUtil instance] urlEncode:string];
}

- (NSDictionary *)getDictionaryFromResponseString:(NSString *)responseStr
{ // valid json object && valid return data(NSDictionary)
    NSError *error = nil;
    NSData *jsonData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    return jsonDic;
}

- (NSDate *)getCurrentSystemDate
{
    return [NSDate date];
}

-(NSString *)getRankType:(RankingType)rankingType
{
    NSString *typeName = nil;
    switch (rankingType) {
        case rankingType_week:
            typeName = @"week";
            break;
        case rankingType_month:
            typeName = @"month";
            break;
        case rankingType_All:
            typeName = @"all";
            break;
        default:
            break;
    }
    
    return typeName;
}

- (NSString *)getDiscoveryType:(TagType)tagType
{ // 发现文章类别
    NSString *typeName = nil;
    switch (tagType) {
        case tagType_discoveryEvaluation:
            typeName = @"evaluation";
            break;
        case tagType_discoveryActivity:
            typeName = @"activities";
            break;
        case tagType_discoveryInformaton:
            typeName = @"information";
            break;
        case tagType_discoveryApplepie:
            typeName = @"applepie";
            break;
            
        default:
            break;
    }
    
    return typeName;
}

- (NSString *)getLunBoTypeName:(lunBoType)type
{
    NSString *typeName = nil;
    switch (type) {
        case lunBo_chosenType:
            typeName = @"chosen";
            break;
        case lunBo_appType:
            typeName = @"app";
            break;
        case lunBo_gameType:
            typeName = @"game";
            break;
        case lunBo_discoverType:
            typeName = @"discover";
            break;
            
        default:
            break;
    }
    
    return typeName;
}

- (NSTimeInterval)timerIntervalFromDate:(NSDate *)date
{
    NSDate *nowDate = [NSDate date];
    return [nowDate timeIntervalSinceDate:date];
}

-(void)reportError:(NSString*)requestStr response:(NSString*)responseStr {
    
    NSMutableDictionary * dic = [NSMutableDictionary dictionary];
    [dic setObjectNoNIL:requestStr forKey:@"request"];
    [dic setObjectNoNIL:responseStr forKey:@"response"];
    
    [[ReportManage instance] reportPHPRequestError:dic];
    
}

@end
