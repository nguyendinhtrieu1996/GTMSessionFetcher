//
//  AppDelegate.h
//  UploadImageToDrive
//
//  Created by LAP12852 on 7/17/20.
//  Copyright © 2020 LAP12852. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol OIDExternalUserAgentSession;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;

@end // @interface AppDelegate

