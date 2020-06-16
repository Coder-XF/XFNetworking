//
//  XFNetworkingTask.h
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class XFNetworkingTask;
@class XFNetworkingManager;

// redirect 参数 BLOCK 定义
typedef NSURLRequest *_Nonnull(^XFChainRedirectParameterBlock)(NSURLRequest *request, NSURLResponse *response);

/// 链式重定向 BLOCK 定义
typedef XFNetworkingTask *_Nonnull(^XFChainRedirectBlock)(XFChainRedirectParameterBlock redirectParameter);

/// DATA JSON TEXT FAILURE 参数 BLOCK 定义
typedef void(^XFNetSuccessDataBlock)(NSURLSessionTask *task, NSData *responseData);
typedef void(^XFNetSuccessJSONBlock)(NSURLSessionTask *task, NSError *jsonError, id responsedObj);
typedef void(^XFNetSuccessTextBlock)(NSURLSessionTask *task, NSString *responsedText);
typedef void(^XFNetFailureParameterBlock)(NSError *error);

/// 链式 response 和 failure BLOCK 定义
typedef XFNetworkingTask *_Nonnull(^XFResponseDataBlock)(XFNetSuccessDataBlock jsonBlock);
typedef XFNetworkingTask *_Nonnull(^XFResponseJSONBlock)(XFNetSuccessJSONBlock jsonBlock);
typedef XFNetworkingTask *_Nonnull(^XFResponseTextBlock)(XFNetSuccessTextBlock textBlock);
typedef XFNetworkingTask *_Nonnull(^XFNetFailureBlock)(XFNetFailureParameterBlock failure);
typedef XFNetworkingTask *_Nonnull(^XFRetryCountBlock)(NSUInteger retryCount);


@interface XFNetworkingTask : NSObject

@property (nonatomic, copy, readonly) XFChainRedirectBlock redirect;
@property (nonatomic, copy, readonly) XFResponseDataBlock  responseData;
@property (nonatomic, copy, readonly) XFResponseTextBlock  responseText;
@property (nonatomic, copy, readonly) XFResponseJSONBlock  responseJSON;
@property (nonatomic, copy, readonly) XFNetFailureBlock    failure;
/// 执行 .next 之后返回 XFNetworking 对象，可以进行新请求的发送
@property (nonatomic, weak, readonly) XFNetworkingManager *nextManager;
/// 设置重试次数 只可以为 1 2 3
@property (nonatomic, assign, readonly) XFRetryCountBlock retryCount;

@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

@property (nonatomic, weak  ) dispatch_group_t taskGroup;

@property (nonatomic, weak  ) XFNetworkingManager *manager;


/// 这三个方法提供给manager，实现对响应数据的传递，交给XFNetworkingTask处理
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler;

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
