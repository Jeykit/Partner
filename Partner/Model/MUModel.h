//
//  MUModel.h
//  Partner
//
//  Created by Jekity on 2019/8/16.
//  Copyright © 2019 Jekity. All rights reserved.
//

#import "MUNetworkingModel.h"

NS_ASSUME_NONNULL_BEGIN
@class MUParaModel;
@interface MUModel : MUNetworkingModel
MUNetworkingModelInitialization(MUModel,MUParaModel)
@end

NS_ASSUME_NONNULL_END
