//
//  UserDataModel.h
//  Partner
//
//  Created by Jekity on 2019/8/16.
//  Copyright © 2019 Jekity. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserDataModel : NSObject
+(instancetype)sharedInstance;
+ (void)save;//
@end

NS_ASSUME_NONNULL_END
