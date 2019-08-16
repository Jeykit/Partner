//
//  MUModel.m
//  Partner
//
//  Created by Jekity on 2019/8/16.
//  Copyright © 2019 Jekity. All rights reserved.
//

#import "MUModel.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation MUModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper{
    //@"Price":@"AvgPrice",
    return @{};
}
+(NSDictionary<NSString *,id> *)modelContainerPropertyGenericClass{
    return  @{};
}
- (id)copyWithZone:(NSZone *)zone
{
    return nil;
}
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [self yy_modelEncodeWithCoder:aCoder];
    
}
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    return [self yy_modelInitWithCoder:aDecoder];
    
}
@end
#pragma clang diagnostic pop
