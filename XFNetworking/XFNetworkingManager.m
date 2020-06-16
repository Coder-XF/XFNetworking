//
//  XFNetworkingManager.m
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import "XFNetworkingManager.h"
#import "XFNetworkingAssistant.h"

/**
 返回默认的回调队列
 
 @return DelegateQueue
 */
static NSOperationQueue *XFNetSessionDelegateQueue() {
    static dispatch_once_t onceXF;
    static NSOperationQueue *processQueue;
    dispatch_once(&onceXF, ^{
        processQueue = [[NSOperationQueue alloc] init];
        /// 并发数 = 核心数 * 2
        processQueue.maxConcurrentOperationCount = [[NSProcessInfo processInfo] activeProcessorCount] * 2;
    });
    return processQueue;
}

@interface XFNetworkingManager () <NSURLSessionDelegate>

/// 保存每一个任务
@property (nonatomic, strong) NSMutableArray <XFNetworkingTask *> *microTasks;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_semaphore_t operationLock;
@property (nonatomic, strong) dispatch_semaphore_t taskSemaphore;
@property (nonatomic, strong) dispatch_queue_t processQueue;


@end

@implementation XFNetworkingManager

// 提供了多个接口用于不同情况下创建实例
+ (XFNetworkingManager *)manager {
    // 创建一个XFNetworking实例对象
    return [[self alloc] init];
}

+ (XFNetworkingCreateBlock)createNetworking {
    return ^XFNetworkingManager *(NSURLSessionConfiguration *sessionConfiguration, NSOperationQueue *delegateQueue) {
        return [[XFNetworkingManager alloc] initWithConfiguration:sessionConfiguration delegateQueue:delegateQueue];
    };
}

/// init创建，参数全部设置为默认值
- (instancetype)init
{
    if (self = [super init]) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:XFNetSessionDelegateQueue()];
        //XFNetSessionDelegateQueue为一个默认的队列
        [self prepare];
    }
    return self;
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration delegateQueue:(NSOperationQueue *)delegateQueue {
    if (self = [super init]) {
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:delegateQueue];
        [self prepare];
    }
    return self;
}

#pragma mark - 管理task的方法

- (void)prepare {
    _operationLock = dispatch_semaphore_create(1);
    _taskSemaphore = dispatch_semaphore_create(1);
    _processQueue  = dispatch_queue_create("com.XFnetworking.microtaskqueue", NULL);  // NULL默认为串行队列
    
    _microTasks    = [NSMutableArray array];
}

- (void)lock {
    dispatch_semaphore_wait(_operationLock, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_operationLock);
}

- (XFNetworkingTask *)getMicroTaskWithTaskID:(NSUInteger)taskID {
    [self lock];
    XFNetworkingTask *targetTask;
    for (XFNetworkingTask *microTask in _microTasks) {
        if (microTask.dataTask.taskIdentifier == taskID) {
            targetTask = microTask;
            break;
        }
    }
    [self unlock];
    return targetTask;
}

- (XFNetworkingManager *)addMicroTask:(XFNetworkingTask *)task {
    [self lock];
    [self.microTasks addObject:task];
    [self unlock];
    dispatch_async(_processQueue, ^{
        /// 串行请求的基础
        /*
         1.dispatch_semaphore_create：创建一个Semaphore并初始化信号的总量
         2.dispatch_semaphore_signal：发送一个信号，让信号总量加1
         3.dispatch_semaphore_wait：可以使总信号量减1，当信号总量为0时就会一直等待
         （阻塞所在线程），否则就可以正常执行。
         */
        //dispatch_semaphore_wait 保证线程安全：一个请求只能由一个线程去开启
        dispatch_semaphore_wait(self.taskSemaphore, DISPATCH_TIME_FOREVER);
        [task.dataTask resume];
    });
    return self;
}


- (void)removeMicroTask:(XFNetworkingTask *)task {
    dispatch_semaphore_signal(_taskSemaphore);
    [self lock];
    [self.microTasks removeObject:task];
    
    // 没有任务，需要通知
    if (self.microTasks.count == 0) {
        /// 多任务完成执行后执行某操作的基础
        // group需要进行调用dispatch_group_leave并释放信号
        !task.taskGroup ?: dispatch_group_leave(task.taskGroup);
    }
    
    [self unlock];
}


- (void)queryFinishTasks {
    [self lock];
    
    if (self.microTasks.count == 0) {
        /// 完成所有任务，取消session
        [self.session finishTasksAndInvalidate];
    }
    
    [self unlock];
}


#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    XFNetworkingTask *microTask = [self getMicroTaskWithTaskID:task.taskIdentifier];
    
    [microTask URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    
    
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    XFNetworkingTask *microTask = [self getMicroTaskWithTaskID:dataTask.taskIdentifier];
    [microTask URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    XFNetworkingTask *microTask = [self getMicroTaskWithTaskID:task.taskIdentifier];
    [microTask URLSession:session task:task didCompleteWithError:error];
}

#pragma mark - 点语法（getter方法）

+ (XFNetworkingTasksBlock)allTasks {
    return ^XFNetworkingManager *(NSArray <XFNetworkingTask *> *tasks, dispatch_block_t finish) {
        
        BOOL enter = NO;
        __block dispatch_group_t group = dispatch_group_create();
        // 将任务放到group中
        for (XFNetworkingTask *task in tasks) {
            if ([task isKindOfClass:[XFNetworkingTask class]]) {
                enter = YES;
                task.taskGroup = group;
                
                dispatch_group_enter(group);
            }
        }
        
        if (!enter) {
            !finish ?: finish();
            return nil;
        }
        
        XFNetworkingManager *manager = [XFNetworkingManager manager];
        dispatch_async(manager.processQueue, ^{
            dispatch_semaphore_wait(manager.taskSemaphore, DISPATCH_TIME_FOREVER);
        });
        
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            /// 延长group 的生命周期，block 捕获住这个 group
            group = nil;
            !finish ?: finish();
            dispatch_semaphore_signal(manager.taskSemaphore);
            [manager queryFinishTasks];
        });
        
        return manager;
    };
}

- (XFNetRequestBlock)requestWith {
    return ^XFNetworkingTask *_Nonnull(NSURLRequest *request) {
        XFNetworkingTask *task = [[XFNetworkingTask alloc] init];
        // self即是调用此方法的XFNetworking实例对象
        // 根据request创建dataTask(下载任务）
        task.dataTask           = [self.session dataTaskWithRequest:request];
        task.manager         = self;
        // 将dataTask对象放到task数组（注意线程安全）
        [self addMicroTask:task];
        return task;
    };
}

- (XFSendRequestBlock)makeRequest {
    return ^XFNetworkingTask *_Nonnull(XFRequestMakeBlock  _Nonnull make) {
        XFNetworkingTask *task = [[XFNetworkingTask alloc] init];
        task.manager         = self;
        [self lock];
        [self.microTasks addObject:task];
        [self unlock];
        
        dispatch_async(self.processQueue, ^{
            dispatch_semaphore_wait(self.taskSemaphore, DISPATCH_TIME_FOREVER);
            NSURLRequest *request = make();
            task.dataTask         = [self.session dataTaskWithRequest:request];;
            [task.dataTask resume];
        });
        return task;
    };
}

- (XFNetParametersBlock)getWithURL {
    return ^XFNetworkingTask *(NSString *urlString, NSDictionary *parameters) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.xf_setMethod(@"GET");
        if (parameters) {
            request.xf_setHTTPParameter(parameters);
        }
        return self.requestWith(request);
    };
}

- (XFNetParametersBlock)postWithURL {
    return ^XFNetworkingTask *(NSString *urlString, NSDictionary *parameters) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.xf_setMethod(@"POST");
        if (parameters) {
            request.xf_setHTTPParameter(parameters);
        }
        return self.requestWith(request);
    };
}

@end
