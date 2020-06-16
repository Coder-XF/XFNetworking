//
//  XFNetworkingManager.h
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XFNetworkingTask.h"
#import "XFNetworkingAssistant.h"

NS_ASSUME_NONNULL_BEGIN

@class XFNetworkingManager;


typedef XFNetworkingManager *_Nonnull(^XFNetworkingCreateBlock)(NSURLSessionConfiguration *sessionConfiguration, NSOperationQueue *delegateQueue);
typedef XFNetworkingManager *_Nullable(^XFNetworkingTasksBlock)(NSArray <XFNetworkingTask *> *tasks, dispatch_block_t finish);
// typedef 定义一个别名
// typedef int NSInteger;  给int定义了一个别名为NSInteger
/// send block 定义
typedef NSURLRequest *_Nonnull(^XFRequestMakeBlock)(void);

typedef XFNetworkingTask *_Nonnull(^XFSendRequestBlock)(XFRequestMakeBlock make);
typedef XFNetworkingTask *_Nonnull(^XFNetRequestBlock)(NSURLRequest *request);
typedef XFNetworkingTask *_Nonnull(^XFNetParametersBlock)(NSString *urlString, NSDictionary *_Nullable parameters);

@interface XFNetworkingManager : NSObject

/// 此 block 可指定 NSURLSessionConfiguration 和 NSOperationQueue
@property (nonatomic, readonly, class) XFNetworkingCreateBlock createNetworking;
@property (nonatomic, readonly, class) XFNetworkingManager *manager;
@property (nonatomic, readonly, class) XFNetworkingTasksBlock allTasks;

/// 以下 block 执行后返回 XFNetMicroTask 对象，可以进行返回数据处理和重定向相关工作
@property (nonatomic, copy, readonly) XFSendRequestBlock   makeRequest;
@property (nonatomic, copy, readonly) XFNetRequestBlock    requestWith;
@property (nonatomic, copy, readonly) XFNetParametersBlock getWithURL;
@property (nonatomic, copy, readonly) XFNetParametersBlock postWithURL;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
