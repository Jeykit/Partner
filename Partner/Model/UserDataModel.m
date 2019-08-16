//
//  UserDataModel.m
//  Partner
//
//  Created by Jekity on 2019/8/16.
//  Copyright © 2019 Jekity. All rights reserved.
//

#import "UserDataModel.h"
#import <YYModel.h>

static UserDataModel *model = nil;
@implementation UserDataModel
+(instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSString *jsonStr = [[NSUserDefaults standardUserDefaults] valueForKey:@"UserDataModel"];
        model = [UserDataModel yy_modelWithJSON:jsonStr];
        if (model == nil) {
            model = [UserDataModel new];
        }
//#ifdef DEBUG
//
//#endif
    });
    return model;
}
+ (void)save{
    NSString *jsonStr = [model yy_modelToJSONString];
    
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"UserDataModel"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
