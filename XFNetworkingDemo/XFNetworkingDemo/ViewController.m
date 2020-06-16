//
//  ViewController.m
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import "ViewController.h"
#import "XFNetworkingManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self postWithUrl];
}

// 发送请求
- (void)request {
    XFNetworkingManager
    .manager  // 创建一个XFNetworkingManager实例对象，并初始化
    .requestWith(
                 NSMutableURLRequest // 创建request
                 .xf_requestWithURL(@"urlStr") // 设置url
                 .xf_setUA(@"UAvalue") // 设置HTTPHeaderField： @"User-Agent"
                 .xf_setPolicy(NSURLRequestUseProtocolCachePolicy)
                 .xf_setMethod(@"POST")
                 .xf_handleCookie(YES)
                 .xf_setTimeout(25)
                 .xf_addHeaderValues(
                                        @{
                                          /// 设置 请求头
                                          @"key1": @"value1",
                                          @"key2": @"value2"
                                          }
                                        )
                 .xf_setHTTPParameter(
                                         @{
                                           /// 设置 HTTPBody
                                           @"key1": @"value1",
                                           @"key2": @"value2"
                                           }
                                         )
                 )
    .retryCount(2)
    /// 下面四个设置回调处理的闭包并非必选，偶是选用
    .responseData(^(NSURLSessionTask * _Nonnull task, NSData * _Nonnull responseData) {
        NSLog(@"--> Task responseData");
    })
    .responseJSON(^(NSURLSessionTask * _Nonnull task, NSError * _Nonnull jsonError, id  _Nonnull responsedObj) {
        NSLog(@"--> Task responsedObj");
    })
    .responseText(^(NSURLSessionTask * _Nonnull task, NSString * _Nonnull responsedText) {
        NSLog(@"--> Task responsedText");
    })
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task Error");
    });
}

// Get请求
- (void)getWithUrl {
    XFNetworkingManager
    .manager
    .getWithURL(
                @"http://api.budejie.com/api/api_open.php",
                /// 设置 HTTPBody
                @{
                  @"a": @"list",
                  @"c": @"data"
                  }
                )
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task Error");
    });
}

// post请求
- (void)postWithUrl {
    XFNetworkingManager
    .manager
    .postWithURL(
                 @"http://api.budejie.com/api/api_open.php",
                 /// 设置 HTTPBody
                 @{
                   @"a": @"list",
                   @"cmmm": @"data"
                   }
                 )
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task Error");
    });
}

- (void)taskInSerialQueue {
    XFNetworkingManager
    .manager
    .getWithURL(@"urlStr", nil)
    .retryCount(2)
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task A Error");
    })
    .nextManager
    .postWithURL(
                 @"urlStr",
                 /// 设置 HTTPBody
                 @{
                   @"key1": @"value1",
                   @"key2": @"value2"
                   }
                 )
    .retryCount(1)
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task B Error");
    })
    .nextManager
    .getWithURL(@"urlStr", nil)
    .retryCount(3)
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task C Error");
    });
}

- (void)taskInSerialQueueByMakeRequest {
    __block NSString *urlTwo;
    
    XFNetworkingManager
    .manager
    .getWithURL(@"urlStr", nil)
    .retryCount(1)
    .responseData(^(NSURLSessionTask * _Nonnull task, NSData * _Nonnull responseData) {
        urlTwo = @"urlTwoFromResponseData";
        NSLog(@"--> Task A %@",responseData);
    })
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task A %@",error);
    })
    .nextManager
    .makeRequest(^NSURLRequest * _Nonnull{
        return NSMutableURLRequest
        /// 第二个请求的参数可以使用第一个请求的回包数据
        .xf_requestWithURL(urlTwo);
    })
    .retryCount(1)
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"--> Task B %@",error);
    });
}

- (void)taskAfterMoreTaskInCurrentQueue {
    NSError *error;
    NSMutableURLRequest *request = NSMutableURLRequest
    .xf_requestWithURL(@"urlStr")
    .xf_setJSONParameter(
                            @{
                              @"key1": @"value1",
                              @"key2": @"value2"
                              },
                            error
                            );
    
    XFNetworkingTask *taskA = XFNetworkingManager
    .manager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task A Error");
    })
    .nextManager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task A2 Error");
    });
    
    XFNetworkingTask *taskB = XFNetworkingManager
    .manager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task B Error");
    })
    .nextManager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task B2 Error");
    })
    .nextManager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task B3 Error");
    });
    
    XFNetworkingTask *taskC = XFNetworkingManager
    .allTasks(@[taskA, taskB], ^{
        NSLog(@"--> AB 完成");
    })
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task C Error");
    });
    
    XFNetworkingTask *taskD = XFNetworkingManager
    .manager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task D Error");
    })
    .nextManager
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task D2 Error");
    });
    
    XFNetworkingManager
    .allTasks(@[taskC, taskD], ^{
        NSLog(@"--> fuck all");
    })
    .requestWith(request)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> task E Error");
    });
}

- (void)redirect {
    XFNetworkingManager
    .manager
    .getWithURL(@"urlStr", nil)
    .retryCount(1)
    .redirect(^NSURLRequest * _Nonnull(NSURLRequest * _Nonnull request, NSURLResponse * _Nonnull response) {
        /// 从 request 和 response 中获取信息进行业务判断，返回所需的新的 request
        NSMutableURLRequest *newRequest = NSMutableURLRequest
        .xf_requestWithURL(@"newUrlStr")
        .xf_setMethod(@"POST");
        return newRequest;
    })
    .responseText(^(NSURLSessionTask * _Nonnull task, NSString * _Nonnull responsedText) {
        NSLog(@"--> Task responsedText");
    })
    .failure(^(NSError * _Nonnull error){
        NSLog(@"--> Task Error");
    });
}



- (void)createNetworking {
    XFNetworkingManager
    .createNetworking(
                      /// 可以自己设置 NSURLSessionConfiguration 和 delegateQueue
                      [NSURLSessionConfiguration defaultSessionConfiguration],
                      [[NSOperationQueue alloc] init]
                      )
    .getWithURL(@"urlStr", nil)
    .retryCount(1)
    .failure(^(NSError * _Nonnull error) {
        NSLog(@"%@",error);
    });
}



@end
