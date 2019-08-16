//
//  LoadingModel.m
//  Partner
//
//  Created by Jekity on 2019/8/16.
//  Copyright © 2019 Jekity. All rights reserved.
//

#import "LoadingModel.h"

@implementation LoadingModel
- (instancetype)init{
    if (self = [super init]) {
        
        self.weChatSharedID = @"wx6e7b73442c7b4b64";
        self.weChatPayID = @"wx6e7b73442c7b4b64";
        self.weChatPayScheme = @"wx6e7b73442c7b4b64";
        
        self.alipayID = @"2019030763515118";
        self.alipayScheme = @"Alipay2019030763515118";
        
        self.QQID = @"1104763150";
        self.weiboID = @"728997221";
    }
    return self;
}
@end
