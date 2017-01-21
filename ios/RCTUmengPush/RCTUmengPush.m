//
//  RCTUmengPush.m
//  RCTUmengPush
//
//  Created by user on 16/4/24.
//  Copyright © 2016年 react-native-umeng-push. All rights reserved.
//

#import "RCTUmengPush.h"
#import "RCTLog.h"


static NSString * const DidReceiveMessage = @"DidReceiveMessage";
static NSString * const DidOpenMessage = @"DidOpenMessage";

static RCTUmengPush *_instance = nil;

@interface RCTUmengPush ()
@property (nonatomic, copy) NSString *deviceToken;
@end
@implementation RCTUmengPush

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
    return @[DidReceiveMessage,DidOpenMessage];
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(_instance == nil) {
            _instance = [[self alloc] init];
        }
    });
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(_instance == nil) {
            _instance = [super allocWithZone:zone];
            [_instance setupUMessage];
        }
    });
    return _instance;
}

+ (dispatch_queue_t)sharedMethodQueue {
    static dispatch_queue_t methodQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        methodQueue = dispatch_queue_create("com.liuchungui.react-native-umeng-push", DISPATCH_QUEUE_SERIAL);
    });
    return methodQueue;
}

- (dispatch_queue_t)methodQueue {
    return [RCTUmengPush sharedMethodQueue];
}

- (NSDictionary<NSString *, id> *)constantsToExport {
    return @{
             DidReceiveMessage: DidReceiveMessage,
             DidOpenMessage: DidOpenMessage,
             };
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
//    RCTLog();
    [self sendEventWithName:DidReceiveMessage body:userInfo];
}

- (void)didOpenRemoteNotification:(NSDictionary *)userInfo {
    [self sendEventWithName:DidOpenMessage body:userInfo];
}

RCT_EXPORT_METHOD(setAutoAlert:(BOOL)value) {
    [UMessage setAutoAlert:value];
}

RCT_EXPORT_METHOD(getDeviceToken:(RCTResponseSenderBlock)callback) {
    NSString *deviceToken = self.deviceToken;
    if(deviceToken == nil) {
        deviceToken = @"";
    }
    callback(@[deviceToken]);
}
RCT_REMAP_METHOD(setAlias,
                 alias:(NSString *)alias
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject
                 ) {

    [UMessage setAlias:alias type:kUMessageAliasTypeSina response:^(id responseObject, NSError *error) {
        if(error == nil) {
            resolve(responseObject);
        } else {
            reject(@1, @"set alias failed", error);
        }
    }];
    
}

/**
 *  初始化UM的一些配置
 */
- (void)setupUMessage {
    [UMessage setAutoAlert:NO];
}

+ (void)registerWithAppkey:(NSString *)appkey launchOptions:(NSDictionary *)launchOptions{
    //set AppKey and LaunchOptions
    [UMessage startWithAppkey:appkey launchOptions:launchOptions];
    
    //注册通知，如果要使用category的自定义策略，可以参考demo中的代码。
    [UMessage registerForRemoteNotifications];
    
//    //iOS10必须加下面这段代码。
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate=self;
    
    UNAuthorizationOptions types10=UNAuthorizationOptionBadge|  UNAuthorizationOptionAlert|UNAuthorizationOptionSound;
    [center requestAuthorizationWithOptions:types10  completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            //点击允许
            //这里可以添加一些自己的逻辑
            NSLog(@"点击允许");
        } else {
            //点击不允许
            //这里可以添加一些自己的逻辑
            NSLog(@"点击不允许");
        }
    }];
#ifdef DEBUG
    [UMessage setLogEnabled:YES];
#endif
}

+ (void)application:(UIApplication *)application didRegisterDeviceToken:(NSData *)deviceToken {
    [RCTUmengPush sharedInstance].deviceToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                                  stringByReplacingOccurrencesOfString: @">" withString: @""]
                                                 stringByReplacingOccurrencesOfString: @" " withString: @""];
    [UMessage registerDeviceToken:deviceToken];
}

+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [UMessage didReceiveRemoteNotification:userInfo];
    //send event
    if (application.applicationState == UIApplicationStateInactive) {
        [[RCTUmengPush sharedInstance] didOpenRemoteNotification:userInfo];
    }
    else {
        [[RCTUmengPush sharedInstance] didReceiveRemoteNotification:userInfo];
    }
}

+ (void)didReceiveRemoteNotificationWhenFirstLaunchApp:(NSDictionary *)launchOptions {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), [self sharedMethodQueue], ^{
        //判断当前模块是否正在加载，已经加载成功，则发送事件
        if(![RCTUmengPush sharedInstance].bridge.isLoading) {
            [UMessage didReceiveRemoteNotification:launchOptions];
            [[RCTUmengPush sharedInstance] didOpenRemoteNotification:launchOptions];
        }
        else {
            [self didReceiveRemoteNotificationWhenFirstLaunchApp:launchOptions];
        }
    });
}
//iOS10新增：处理前台收到通知的代理方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler{
    NSDictionary * userInfo = notification.request.content.userInfo;
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        //应用处于前台时的远程推送接受
        //关闭友盟自带的弹出框
        [UMessage setAutoAlert:NO];
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        
    }else{
        //应用处于前台时的本地推送接受
    }
    //当应用处于前台时提示设置，需要哪个可以设置哪一个
    completionHandler(UNNotificationPresentationOptionSound|UNNotificationPresentationOptionBadge|UNNotificationPresentationOptionAlert);
}

//iOS10新增：处理后台点击通知的代理方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler{
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        //应用处于后台时的远程推送接受
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        
    }else{
        //应用处于后台时的本地推送接受
    }
    
}
@end
