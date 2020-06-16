//
//  XFNetworkingTask.m
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import "XFNetworkingTask.h"
#import "XFNetworkingManager.h"

@interface XFNetworkingTask ()

@property (nonatomic, strong) NSMutableData *data;

@property (nonatomic, copy) XFChainRedirectParameterBlock redirectAction;
@property (nonatomic, copy) XFNetSuccessDataBlock responseDataAction;
@property (nonatomic, copy) XFNetSuccessTextBlock responseTextAction;
@property (nonatomic, copy) XFNetSuccessJSONBlock responseJSONAction;
@property (nonatomic, copy) XFNetFailureParameterBlock failureAction;
@property (nonatomic, assign) NSUInteger privateRetryCount;

@end

@implementation XFNetworkingTask

#pragma mark - 初始化

- (instancetype)init
{
    self = [super init];
    if (self) {
        _data = [NSMutableData data];
    }
    return self;
}

#pragma mark - 点语法（getter方法）

- (XFNetworkingManager *)nextManager {
    return _manager;
}

- (XFChainRedirectBlock)redirect {
    return ^XFNetworkingTask *_Nonnull(XFChainRedirectParameterBlock redirectParameter) {
        self.redirectAction = redirectParameter;
        return self;
    };
}

- (XFResponseDataBlock)responseData {
    return ^XFNetworkingTask * _Nonnull(XFNetSuccessDataBlock  _Nonnull jsonBlock) {
        self.responseDataAction = jsonBlock;
        return self;
    };
}

- (XFResponseJSONBlock)responseJSON {
    return ^XFNetworkingTask * _Nonnull(XFNetSuccessJSONBlock  _Nonnull jsonBlock) {
        self.responseJSONAction = jsonBlock;
        return self;
    };
}

- (XFResponseTextBlock)responseText {
    return ^XFNetworkingTask * _Nonnull(XFNetSuccessTextBlock  _Nonnull textBlock) {
        self.responseTextAction = textBlock;
        return self;
    };
}

- (XFNetFailureBlock)failure {
    return ^XFNetworkingTask * _Nonnull(XFNetFailureParameterBlock  _Nonnull failure) {
        self.failureAction = failure;
        return self;
    };
}

- (XFRetryCountBlock)retryCount {
    return ^XFNetworkingTask * _Nonnull(NSUInteger retryCount) {
        if (retryCount >= 1) {
            self.privateRetryCount = retryCount;
        }
        return self;
    };
}

#pragma mark - 模拟NSURLSessionDelegate代理方法

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    if (self.redirectAction) {
        return completionHandler(self.redirectAction(request, response));
    }
    completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    [self.data appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    
    if (error && _privateRetryCount) {
        /// 剩余重试次数 -1，清除错误数据，发起新的request
        _privateRetryCount -= 1;
        _data = [NSMutableData data];
        NSURLSessionDataTask *newTask = [session dataTaskWithRequest:task.currentRequest.copy];
        self.dataTask = newTask;
        return [newTask resume];
    }
    
    dispatch_block_t processFinish = ^() {
        [self.manager performSelector:@selector(removeMicroTask:) withObject:self];
        [self.manager performSelector:@selector(queryFinishTasks) withObject:nil];
//        [self.manager removeMicroTask:self];
//        [self.manager queryFinishTasks];
    };
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    if (error) {
        if (self.failureAction) {
            dispatch_async(mainQueue, ^{
                !self.failureAction ?: self.failureAction(error);
            });
        }
        return processFinish();
    }
    
    NSData *data = self.data.copy;
    if (self.responseDataAction) {
        dispatch_async(mainQueue, ^{
            !self.responseDataAction ?: self.responseDataAction(task, data);
        });
    }
    
    if (self.responseJSONAction) {
        NSError *jsonError;
        id json = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingAllowFragments) error:&jsonError];
        dispatch_async(mainQueue, ^{
            !self.responseJSONAction ?: self.responseJSONAction(task, jsonError, json);
        });
    }
    
    if (self.responseTextAction) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        dispatch_async(mainQueue, ^{
            !self.responseTextAction ?: self.responseTextAction(task, text);
        });
    }
    
    processFinish();
}


@end
