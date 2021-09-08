//
//  ViewController.m
//  objc
//
//  Created by roc on 2021/8/20.
//

#import "ViewController.h"
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <pthread/pthread.h>

static const uint64_t NANOS_PER_USEC = 1000ULL;
static const uint64_t NANOS_PER_MILLISEC = 1000ULL * NANOS_PER_USEC;
static const uint64_t NANOS_PER_SEC = 1000ULL * NANOS_PER_MILLISEC;

static mach_timebase_info_data_t timebase_info;

static uint64_t abs_to_nanos(uint64_t abs) {
    return abs * timebase_info.numer / timebase_info.denom;
}

static uint64_t nanos_to_abs(uint64_t nanos) {
    return nanos * timebase_info.denom / timebase_info.numer;
}

void example_mach_wait_until(int argc, const char * argv[]) {
    mach_timebase_info(&timebase_info);
    uint64_t time_to_wait = nanos_to_abs(10ULL * NANOS_PER_SEC);
    uint64_t now = mach_absolute_time();
    mach_wait_until(now + time_to_wait);
}

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
    mach_timebase_info_data_t timebase_info;
    mach_timebase_info(&timebase_info);
    
    const uint64_t UANOS_PER_MSEC = 1000000ULL;
    double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) *UANOS_PER_MSEC;
    
    thread_time_constraint_policy_data_t policy;
    policy.period = 0;
    policy.computation = (uint32_t)(5 * clock2abs); // 5ms of work
    policy.constraint = (uint32_t)(10 * clock2abs);
    policy.preemptible = FALSE;
    
    int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (kr != KERN_SUCCESS) {
        mach_error("thread_policy_set:", kr);
        exit(1);
    }
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self SELIMPMethod];
}

/**
 SEL:一个字符串（Char *类型），表现方法的名字
 IMP:指向方法实现首地址的指针
 Method:是一个结构体，包含一个SEL表示方法名、一个IMP指向函数的实现地址、一个Char*表现函数的类型（包括返回值和参数类型）
 SEL、IMP、Method之间的关系可以这么理解：
 一个类（Class）持有一系列的（Method），在load类时，runtime会将所有方法的选择器（SEL）hash后映射到一个集合（NSSet）中；
 当需要发消息时，会根据选择器（SEL）去查找方法，找到之后，用Method结构体里的函数指针（IMP）去调用方法，这样在运行时查找selector的速度就会非常快。
 */
- (void)SELIMPMethod {
    SEL selA = @selector(test);
    SEL selB = sel_registerName("test");
    SEL selC = NSSelectorFromString(@"test");
    NSLog(@"%s", selB);
    IMP methodPoint = [self methodForSelector:selC];
    methodPoint();
}

- (void)test {
    NSLog(@"this is test method....");
}

- (void)limit3 {
    dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
    // 控制并发数的信号量
    static dispatch_semaphore_t limitSemaphore;
    // 专门控制并发等待的线程
    static dispatch_queue_t receiveQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        limitSemaphore = dispatch_semaphore_create(3);
        receiveQueue = dispatch_queue_create("receiver", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(receiveQueue, ^{
        // 若信号量小于0，则会阻塞receiveQueue的线程，控制添加到queue里的任务不会超过三个。
        dispatch_semaphore_wait(limitSemaphore, DISPATCH_TIME_FOREVER);
        dispatch_async(queue, ^{
            NSLog(@"doing...");
            // block执行完后增加信号量
            dispatch_semaphore_signal(limitSemaphore);
        });
    });
    // 并发任务先异步派发到receiveQueue串行队列，该队列用来保存这些任务
    // 为什么是异步派发？
    //  dispatch_async表示不需要等到block执行完即可继续向下执行（执行下一条语句）
    //  如果使用dispatch_sync则需要等到block执行完才能继续向下执行，
    //  也就意味着如果dispatch_semaphore_wait方法被阻塞（信号量减为0）则该方法会被阻塞
    // receiveQueue可以是并行队列吗？
    //  派发到串行队列的任务需要等到前一个执行完成后，后一个才能开始执行
    //  而并发队列不需要等到前一个执行完成，只要前一个开始执行，后一个就可以开始
    //  如果使用并发队列，则超出最大并发数任务都会在dispatch_semaphore_wait处阻塞
    //  这会导致占用多个线程。
}

//void dispatch_asyn_limit_3(dispatch_queue_t queue, dispatch_block_t block){
//    // 控制并发数的信号量
//    static dispatch_semaphore_t limitSemaphore;
//    // 专门控制并发等待的线程
//    static dispatch_queue_t receiveQueue;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        limitSemaphore = dispatch_semaphore_create(3);
//        receiveQueue = dispatch_queue_create("receiver", DISPATCH_QUEUE_SERIAL);
//    });
//
//    dispatch_async(receiveQueue, ^{
//        //若信号量小于0，则会阻塞receiveQueue的线程，控制添加到queue里的任务不会超过三个。
//        dispatch_semaphore_wait(limitSemaphore, DISPATCH_TIME_FOREVER);
//        dispatch_async(queue, ^{
//            if (block) {
//                block();
//            }
//            //block执行完后增加信号量
//            dispatch_semaphore_signal(limitSemaphore);
//        });
//    });
//    // 并发任务先异步派发到receiveQueue串行队列，该队列用来保存这些任务
//    // 为什么是异步派发？
//    //  dispatch_async表示不需要等到block执行完即可继续向下执行（执行下一条语句）
//    //  如果使用dispatch_sync则需要等到block执行完才能继续向下执行，
//    //  也就意味着如果dispatch_semaphore_wait方法被阻塞（信号量减为0）则该方法会被阻塞
//    // receiveQueue可以是并行队列吗？
//    //  派发到串行队列的任务需要等到前一个执行完成后，后一个才能开始执行
//    //  而并发队列不需要等到前一个执行完成，只要前一个开始执行，后一个就可以开始
//    //  如果使用并发队列，则超出最大并发数任务都会在dispatch_semaphore_wait处阻塞
//    //  这会导致占用多个线程。
//}



@end
