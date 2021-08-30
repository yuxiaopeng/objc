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
