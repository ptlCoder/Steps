//
//  ViewController.m
//  iOS计步
//
//  Created by soliloquy on 2018/5/22.
//  Copyright © 2018年 soliloquy. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <HealthKit/HealthKit.h>

@interface ViewController ()<UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *stepsLabel;
@property (strong, nonatomic) CMPedometer *pedometer;
@property (strong, nonatomic) HKHealthStore *healthStore;

@property (weak, nonatomic) IBOutlet UITextField *writeDateTF;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    self.writeDateTF.delegate = self;
    self.writeDateTF.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
}

- (NSDate *)getDate:(NSString *)dateString {
    
    NSDate *date = [NSDate date];
    NSDateFormatter *df = [[NSDateFormatter alloc]init];
    df.dateFormat = @"yyyy-MM-dd ";
    NSString *lastDateStr = [df stringFromDate:date];

    
    NSString *string = [lastDateStr stringByAppendingString:dateString];;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm";
    NSDate *date1 = [fmt dateFromString:string];
    
//
//    NSTimeZone *zone = [NSTimeZone systemTimeZone];
//    NSInteger interval = [zone secondsFromGMT];
//    date1 = [date1 dateByAddingTimeInterval:interval];
    return date1;
}


- (IBAction)stepDown:(id)sender {
    

 
    /// 创建计步器对象
    if ([CMPedometer isStepCountingAvailable]) { 
        self.pedometer = [[CMPedometer alloc] init];
        
        
        NSDate *lastDate = [self getDate:@"00:01"];
        NSDate *toDate = [self getDate:@"23:59"];
        
        
        [self.pedometer startPedometerUpdatesFromDate:lastDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
            // 如果没有错误，具体信息从pedometerData参数中获取

        }];
        [self.pedometer queryPedometerDataFromDate:lastDate toDate:toDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
            // 如果没有错误，具体信息从pedometerData参数中获取
            if (error) {
                NSLog(@"%@",error);
                return;
            }
//            pedometerData
            NSLog(@"步数: %zd", [pedometerData.numberOfSteps integerValue]);
            dispatch_async(dispatch_get_main_queue(), ^{
               self.stepsLabel.text = [NSString stringWithFormat:@"步数: %ld",[pedometerData.numberOfSteps integerValue]];
            });
            
            
        }];
    }
}

-(HKHealthStore *)healthStore {
    if (!_healthStore) {
        _healthStore = [[HKHealthStore alloc]init];
    }
    return _healthStore;
}

- (IBAction)healthKit:(id)sender {
    
    if ([HKHealthStore isHealthDataAvailable]) {
        NSSet<HKSampleType *> *shareTypes = nil;
        HKQuantityType *stepType = [HKQuantityType quantityTypeForIdentifier:(HKQuantityTypeIdentifierStepCount)];
        HKQuantityType *distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
        NSSet<HKObjectType *> *readTypes = [NSSet setWithObjects:stepType, distanceType, nil];
        [self.healthStore requestAuthorizationToShareTypes:shareTypes readTypes:readTypes completion:^(BOOL success, NSError * _Nullable error) {
            
            if (error) {
                NSLog(@"error: %@",error);
                return ;
            }
            
            
            // 查询数据的类型，比如计步，行走+跑步距离等等
            HKQuantityType *quantityType = [HKQuantityType quantityTypeForIdentifier:(HKQuantityTypeIdentifierStepCount)];
            // 谓词，用于限制查询返回结果
            NSDate *lastDate = [self getDate:@"00:01"];
            NSDate *toDate = [self getDate:@"23:59"];
            
            NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:lastDate endDate:toDate options:(HKQueryOptionNone)];
            
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
            // 用于锚集合的时间间隔
            NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
            
            // 采样时间间隔
            NSDateComponents *intervalComponents = [[NSDateComponents alloc] init];
            intervalComponents.day = 1;
            
            // 创建统计查询对象
            HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType quantitySamplePredicate:predicate options:(HKStatisticsOptionCumulativeSum|HKStatisticsOptionSeparateBySource) anchorDate:anchorDate intervalComponents:intervalComponents];
            query.initialResultsHandler = ^(HKStatisticsCollectionQuery * _Nonnull query, HKStatisticsCollection * _Nullable result, NSError * _Nullable error) {
                
                if (error) {
                    return ;
                }
                
//                NSMutableArray *resultArr = [NSMutableArray array];
                for (HKStatistics *statistics in [result statistics]) {
                    for (HKSource *source in statistics.sources) {
                        // 过滤掉其它应用写入的健康数据
                        NSLog(@"name:%@ -- id:%@",source.name, source.bundleIdentifier);
//                        if ([source.name isEqualToString:[UIDevice currentDevice].name]) {
//                            // 获取到步数
//                            double step = round([[statistics sumQuantityForSource:source] doubleValueForUnit:[HKUnit countUnit]]);
//                            NSLog(@"步数： %f",step);
//                        }
                        // 获取到步数
                        NSInteger step = round([[statistics sumQuantityForSource:source] doubleValueForUnit:[HKUnit countUnit]]);
                        NSLog(@"步数： %ld",step);
                        dispatch_async(dispatch_get_main_queue(), ^{
                           self.stepsLabel.text = [NSString stringWithFormat:@"步数: %ld",step];
                        });
                    }
                }
                
                
            };
            // 执行查询请求
            [self.healthStore executeQuery:query];
            
            
        }];
        
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSLog(@"%s---%@",__func__,textField.text);
    
//    HKQuantityType *stepType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
//    NSSet *shareTypes = [NSSet setWithObjects:stepType, nil];
    
    if ([HKHealthStore isHealthDataAvailable]) {
        
        HKQuantityType *stepType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
        NSSet *shareTypes = [NSSet setWithObjects:stepType, nil];
        
        [self.healthStore requestAuthorizationToShareTypes:shareTypes readTypes:shareTypes completion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                NSLog(@"%@",error);
                return ;
            }
            double step = [textField.text doubleValue];
            HKQuantityType *stepType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
            HKQuantity *stepQuantity = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:step];
            NSDate *lastDate = [self getDate:@"00:01"];
            
            HKQuantitySample *stepSample = [HKQuantitySample quantitySampleWithType:stepType quantity:stepQuantity startDate:lastDate endDate:[NSDate date]];
            [self.healthStore saveObject:stepSample withCompletion:^(BOOL success, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"error: %@", error);
                    return ;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.stepsLabel.text = success ? @"写入成功" : @"写入失败";
                });
            }];
        }];
        
    }
    
    
    
    return YES;
}

@end
