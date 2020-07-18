//
//  ViewController.m
//  UploadImageToDrive
//
//  Created by LAP12852 on 7/17/20.
//  Copyright © 2020 LAP12852. All rights reserved.
//

#import "ViewController.h"

#import "GTMAppAuth.h"
#import "AppAuth.h"
#import "GTLRDriveService.h"
#import "AppDelegate.h"
#import "GTLRDriveQuery.h"
#import "GTLRDriveObjects.h"


static NSString * const kClientId = @"18381047542-08tkk2u1hdprcpnv4211tgckodqbspd4.apps.googleusercontent.com";
static NSString * const kURLSchema = @"com.googleusercontent.apps.18381047542-08tkk2u1hdprcpnv4211tgckodqbspd4:/oauthredirect";
static NSString * const kGDriveApDataFolder = @"appDataFolder";

static int const kMaxExecutingQueue = 3;
static int const kTotalPhotoUpload = 400;


@interface ViewController ()

@property (nonatomic, strong)  OIDAuthState                             *authState;
@property (nonatomic, strong)  GTMAppAuthFetcherAuthorization           *gAuth;
@property (nonatomic, strong)  GTLRDriveService                         *service;

@property (nonatomic, strong)  NSMutableArray<GTLRServiceTicket *>      *executingTicket;
@property (nonatomic, assign)  int                                      totalPhotoUploadToDrive;
@property (nonatomic, assign)  int                                      executingCount;

@property (nonatomic, strong) NSURL                                  *filePath;

@end // @interface ViewController ()


@implementation ViewController

#pragma mark View LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.service = [GTLRDriveService new];
    self.executingTicket = [NSMutableArray new];
    self.filePath = [self _imagePath];
}

#pragma mark UI Actions

- (IBAction)didSelecAuthorizeButton:(id)sender {
    NSArray<NSString *> *scopes = @[OIDScopeOpenID,
                                    OIDScopeProfile,
                                    OIDScopeEmail,
                                    kGTLRAuthScopeDriveAppdata];
    
    OIDServiceConfiguration *serviceConfiguration = [GTMAppAuthFetcherAuthorization configurationForGoogle];
    NSURL *redirectURL = [NSURL URLWithString:kURLSchema];
    
    OIDAuthorizationRequest *request = [[OIDAuthorizationRequest alloc]
                                        initWithConfiguration:serviceConfiguration
                                        clientId:kClientId
                                        scopes:scopes
                                        redirectURL:redirectURL
                                        responseType:OIDResponseTypeCode
                                        additionalParameters:nil];
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    appDelegate.currentAuthorizationFlow
    = [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                     presentingViewController:self
                                                     callback:^(OIDAuthState * _Nullable authState,
                                                                NSError * _Nullable error) {
        self.authState = authState;
        GTMAppAuthFetcherAuthorization *gAuth;
        gAuth = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
        self.gAuth = gAuth;
        self.authEmailLabel.text = gAuth.userEmail;
        self.service.authorizer = gAuth;
    }];
}

- (IBAction)didSelectStartSyncButton:(id)sender {
    [self.syncButton setUserInteractionEnabled:NO];
    self.syncButton.backgroundColor = UIColor.lightGrayColor;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _executeUploadPhoto];
        [self _executeUploadPhoto];
        [self _executeUploadPhoto];
    });
}

- (void)_executeUploadPhoto {
    if (self.executingCount > kMaxExecutingQueue || self.totalPhotoUploadToDrive > kTotalPhotoUpload) {
        return;
    }
    
    self.executingCount += 1;
    self.totalPhotoUploadToDrive += 1;

    id<GTLRQueryProtocol> query = [self _buildGTLRQuery];
    
    [self.service executeQuery:query
             completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket,
                                 id  _Nullable object,
                                 NSError * _Nullable callbackError) {
        
        [self _showError:callbackError];
        self.executingCount -= 1;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _updateProgress];
        });
        [self _executeUploadPhoto];
    }];
}

- (void)_showError:(NSError *)callbackError {
    if (callbackError) {
        NSDictionary *userInfo = callbackError.userInfo;
        if ([userInfo isKindOfClass:[NSDictionary class]]) {
            NSData *errorData = [userInfo objectForKey:@"data"];
            
            if ([errorData isKindOfClass:[NSData class]]) {
                NSError *parserError = nil;
                NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData
                                                                          options:(NSJSONReadingMutableContainers)
                                                                            error:&parserError];
                if ([errorDict isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"TRIEUND2> upload file fail: %@", errorDict.description);
                    return;
                }
            }
        }
        
        NSLog(@"TRIEUND2> upload file fail: %@", callbackError.description);
    } else {
        NSLog(@"TRIEUND2> upload file success: %@", (callbackError == nil) ? @"YES" : @"NO");
    }
}

- (id<GTLRQueryProtocol>)_buildGTLRQuery {
    GTLRDrive_File *gFile = [GTLRDrive_File new];
    gFile.name = NSUUID.UUID.UUIDString;
    gFile.spaces = @[kGDriveApDataFolder];
    
    GTLRUploadParameters *uploadParams = [GTLRUploadParameters uploadParametersWithFileURL:self.filePath MIMEType:@""];
    
    GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate queryWithObject:gFile uploadParameters:uploadParams];
    query.fields = @"id, name, mimeType";
    
    return query;
}

- (void)_updateProgress {
    float progress = (float)self.totalPhotoUploadToDrive / (float)kTotalPhotoUpload;
    self.progressView.progress = progress;
    self.progressLabel.text = [NSString stringWithFormat:@"%f - %d/%d",
                               progress,
                               self.totalPhotoUploadToDrive,
                               kTotalPhotoUpload];
}

- (NSURL *)_imagePath {
    NSArray *paths = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                          inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [paths objectAtIndex:0];
    NSURL *saveImagePath = [documentsDirectory URLByAppendingPathComponent:@"saveImage.png"];
    
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:saveImagePath.absoluteString]) {
        UIImage *image = [UIImage imageNamed:@"image_1"];
        NSData *data = UIImagePNGRepresentation(image);
        [data writeToURL:saveImagePath atomically:YES];
    }
    
    return saveImagePath;
}

@end // @implementation ViewController
