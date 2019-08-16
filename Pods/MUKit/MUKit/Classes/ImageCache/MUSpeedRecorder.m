//
//  MUSpeedRecorder.m
//  MUKit_Example
//
//  Created by Jekity on 2018/8/9.
//  Copyright © 2018年 Jeykit. All rights reserved.
//

#import "MUSpeedRecorder.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import "MUProgressiveImage.h"
@interface MUSpeedMeasurement : NSObject

// Storing the count of each measurement allows for bias adjustment in exponentially
// weighted average.
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) float bytesPerSecond;
@property (nonatomic, assign) float startAdjustedBytesPerSecond;
@property (nonatomic, assign) CFTimeInterval timeToFirstByte;

@end

@interface MUSpeedRecorder ()
{
    NSCache <NSString *, MUSpeedMeasurement *>*_speedMeasurements;
    SCNetworkReachabilityRef _reachability;
#if DEBUG
    BOOL _overrideBPS;
    float _currentBPS;
#endif
}

@property (nonatomic, strong) MURemoteLock *lock;

@end

@implementation MUSpeedRecorder

+ (MUSpeedRecorder *)sharedRecorder
{
    static dispatch_once_t onceToken;
    static MUSpeedRecorder *sharedRecorder;
    dispatch_once(&onceToken, ^{
        sharedRecorder = [[self alloc] init];
    });
    
    return sharedRecorder;
}

- (instancetype)init
{
    if (self = [super init]) {
        _lock = [[MURemoteLock alloc] initWithName:@"MUSpeedRecorder lock"];
        _speedMeasurements = [[NSCache alloc] init];
        _speedMeasurements.countLimit = 25;
        
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        _reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    }
    return self;
}

- (void)processMetrics:(NSURLSessionTaskMetrics *)metrics forTask:(NSURLSessionTask *)task
{
    NSDate *requestStart = [NSDate distantFuture];
    NSDate *firstByte = [NSDate distantFuture];
    NSDate *requestEnd = [NSDate distantPast];
    int64_t contentLength = task.countOfBytesReceived;
    
    for (NSURLSessionTaskTransactionMetrics *metric in metrics.transactionMetrics) {
        if (metric.requestStartDate == nil || metric.responseStartDate == nil) {
            //Only evaluate requests which completed their first byte.
            return;
        }
        
        requestStart = [requestStart earlierDate:metric.requestStartDate];
        firstByte = [firstByte earlierDate:metric.responseStartDate];
        requestEnd = [requestEnd laterDate:metric.responseEndDate];
    }
    
    if ([requestStart isEqual:[NSDate distantFuture]] || [firstByte isEqual:[NSDate distantFuture]] || [requestEnd isEqual:[NSDate distantPast]] || contentLength == 0) {
        return;
    }
    
    [self updateSpeedsForHost:task.currentRequest.URL.host
               bytesPerSecond:contentLength / [requestEnd timeIntervalSinceDate:requestStart]
  startAdjustedBytesPerSecond:contentLength / [requestEnd timeIntervalSinceDate:firstByte]
              timeToFirstByte:[firstByte timeIntervalSinceDate:requestStart]];
}

- (void)resetMeasurements
{
    [self.lock lockWithBlock:^{
        [self->_speedMeasurements removeAllObjects];
    }];
}

- (void)updateSpeedsForHost:(NSString *)host bytesPerSecond:(float)bytesPerSecond startAdjustedBytesPerSecond:(float)startAdjustedBytesPerSecond timeToFirstByte:(float)timeToFirstByte
{
    [self.lock lockWithBlock:^{
        MUSpeedMeasurement *measurement = [self->_speedMeasurements objectForKey:host];
        if (measurement == nil) {
            measurement = [[MUSpeedMeasurement alloc] init];
            measurement.count = 0;
            measurement.bytesPerSecond = bytesPerSecond;
            measurement.startAdjustedBytesPerSecond = startAdjustedBytesPerSecond;
            measurement.timeToFirstByte = timeToFirstByte;
            [self->_speedMeasurements setObject:measurement forKey:host];
        } else {
            const double bpsBeta = 0.8;
            const double ttfbBeta = 0.8;
            measurement.count++;
            measurement.bytesPerSecond = (measurement.bytesPerSecond * bpsBeta) + ((1.0 - bpsBeta) * bytesPerSecond);
            measurement.startAdjustedBytesPerSecond = (measurement.startAdjustedBytesPerSecond * bpsBeta) + ((1.0 - bpsBeta) * startAdjustedBytesPerSecond);
            measurement.timeToFirstByte = (measurement.timeToFirstByte * ttfbBeta) + ((1.0 - ttfbBeta) * timeToFirstByte);
        }
    }];
}

- (float)weightedAdjustedBytesPerSecondForHost:(NSString *)host
{
    __block float startAdjustedBytesPerSecond = -1;
    [self.lock lockWithBlock:^{
#if DEBUG
        if ( self->_overrideBPS) {
            startAdjustedBytesPerSecond =  self->_currentBPS;
            return;
        }
#endif
        MUSpeedMeasurement *measurement = [self->_speedMeasurements objectForKey:host];
        if (measurement == 0) {
            startAdjustedBytesPerSecond = -1;
            return;
        }
        startAdjustedBytesPerSecond = measurement.startAdjustedBytesPerSecond;
    }];
    return startAdjustedBytesPerSecond;
}

- (NSTimeInterval)weightedTimeToFirstByteForHost:(NSString *)host
{
    __block NSTimeInterval timeToFirstByte = 0;
    [self.lock lockWithBlock:^{
        MUSpeedMeasurement *measurement = [self->_speedMeasurements objectForKey:host];
        timeToFirstByte = measurement.timeToFirstByte;
    }];
    return timeToFirstByte;
}

#if DEBUG
- (void)setCurrentBytesPerSecond:(float)currentBPS
{
    [self.lock lockWithBlock:^{
        if (currentBPS == -1) {
             self->_overrideBPS = NO;
        } else {
             self->_overrideBPS = YES;
        }
        self->_currentBPS = currentBPS;
    }];
}
#endif

// Cribbed from Apple's reachability: https://developer.apple.com/library/content/samplecode/Reachability/Listings/Reachability_Reachability_m.html#//apple_ref/doc/uid/DTS40007324-Reachability_Reachability_m-DontLinkElementID_9

- (MUSpeedRecorderConnectionStatus)connectionStatus
{
    MUSpeedRecorderConnectionStatus status = MUSpeedRecorderConnectionStatusNotReachable;
    SCNetworkReachabilityFlags flags;
    
    // _reachability is set on init and therefore safe to access outside the lock
    if (SCNetworkReachabilityGetFlags(_reachability, &flags)) {
        return [self networkStatusForFlags:flags];
    }
    return status;
}

- (MUSpeedRecorderConnectionStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return MUSpeedRecorderConnectionStatusNotReachable;
    }
    
    MUSpeedRecorderConnectionStatus connectionStatus = MUSpeedRecorderConnectionStatusNotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        connectionStatus = MUSpeedRecorderConnectionStatusWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            /*
             ... and no [user] intervention is needed...
             */
            connectionStatus = MUSpeedRecorderConnectionStatusWiFi;
        }
    }
    
#if PIN_TARGET_IOS
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        connectionStatus = PINSpeedRecorderConnectionStatusWWAN;
    }
#endif
    
    return connectionStatus;
}

+ (NSUInteger)appropriateImageIdxForURLsGivenHistoricalNetworkConditions:(NSArray <NSURL *> *)urls
                                                  lowQualityQPSThreshold:(float)lowQualityQPSThreshold
                                                 highQualityQPSThreshold:(float)highQualityQPSThreshold
{
    float currentBytesPerSecond = [[MUSpeedRecorder sharedRecorder] weightedAdjustedBytesPerSecondForHost:[[urls firstObject] host]];
    
    NSUInteger desiredImageURLIdx;
    
    if (currentBytesPerSecond == -1) {
        // Base it on reachability
        switch ([[MUSpeedRecorder sharedRecorder] connectionStatus]) {
            case MUSpeedRecorderConnectionStatusWiFi:
                desiredImageURLIdx = urls.count - 1;
                break;
                
            case MUSpeedRecorderConnectionStatusWWAN:
            case MUSpeedRecorderConnectionStatusNotReachable:
                desiredImageURLIdx = 0;
                break;
        }
    } else {
        if (currentBytesPerSecond >= highQualityQPSThreshold) {
            desiredImageURLIdx = urls.count - 1;
        } else if (currentBytesPerSecond <= lowQualityQPSThreshold) {
            desiredImageURLIdx = 0;
        } else if (urls.count == 2) {
            desiredImageURLIdx = roundf((currentBytesPerSecond - lowQualityQPSThreshold) / ((highQualityQPSThreshold - lowQualityQPSThreshold) / (float)(urls.count - 1)));
        } else {
            desiredImageURLIdx = ceilf((currentBytesPerSecond - lowQualityQPSThreshold) / ((highQualityQPSThreshold - lowQualityQPSThreshold) / (float)(urls.count - 2)));
        }
    }
    
    return desiredImageURLIdx;
}

@end

@implementation MUSpeedMeasurement

@end
