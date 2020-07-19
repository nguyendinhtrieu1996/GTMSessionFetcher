//
//  ViewController.h
//  UploadImageToDrive
//
//  Created by LAP12852 on 7/17/20.
//  Copyright © 2020 LAP12852. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton       *authButton;
@property (weak, nonatomic) IBOutlet UILabel        *authEmailLabel;
@property (weak, nonatomic) IBOutlet UIButton       *syncButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel        *progressLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end // @interface ViewController

