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
#import "GTMSessionFetcherLogging.h"


static NSString * const kClientId = @"18381047542-08tkk2u1hdprcpnv4211tgckodqbspd4.apps.googleusercontent.com";
static NSString * const kURLSchema = @"com.googleusercontent.apps.18381047542-08tkk2u1hdprcpnv4211tgckodqbspd4:/oauthredirect";
static NSString * const kGDriveApDataFolder = @"appDataFolder";

static int const kMaxExecutingQueue = 3;
static int const kTotalPhotoUpload = 10000;


@interface ViewController ()

@property (nonatomic, strong)  OIDAuthState                             *authState;
@property (nonatomic, strong)  GTMAppAuthFetcherAuthorization           *gAuth;
@property (nonatomic, strong)  GTLRDriveService                         *service;

@property (nonatomic, strong)  NSMutableArray<GTLRServiceTicket *>      *executingTicket;
@property (nonatomic, assign)  int                                      totalPhotoUploadToDrive;
@property (nonatomic, assign)  int                                      executingCount;

@property (nonatomic, strong) NSString                                  *filePath;
@property (nonatomic, assign) dispatch_queue_t                          executeQueue;

@end // @interface ViewController ()


@implementation ViewController

#pragma mark View LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.service = [GTLRDriveService new];
    self.executingTicket = [NSMutableArray new];
    self.filePath = [self _imagePath];
    self.executeQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    
    [GTMSessionFetcher setLoggingEnabled:YES];
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
    = [OIDAuthState
       authStateByPresentingAuthorizationRequest:request
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
    
    [self _executeOnConcurrentQueue];
    [self _executeOnConcurrentQueue];
    [self _executeOnConcurrentQueue];
}

#pragma mark - Upload photo

- (void)_executeOnConcurrentQueue {
    dispatch_async(self.executeQueue, ^{
        UIApplication *application = UIApplication.sharedApplication;
        __block  UIBackgroundTaskIdentifier identifier = [application beginBackgroundTaskWithName:@"com.trieund2.startExecuteOnConcurrenQueue"
                                                                       expirationHandler:^{
            if (identifier != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:identifier];
                identifier = UIBackgroundTaskInvalid;
            }
        }];
        
        [self _executeUploadPhoto];
        
        if (identifier != UIBackgroundTaskInvalid) {
            [application endBackgroundTask:identifier];
            identifier = UIBackgroundTaskInvalid;
        }
    });
}

- (void)_executeUploadPhoto {
    if (self.executingCount > kMaxExecutingQueue || self.totalPhotoUploadToDrive > kTotalPhotoUpload) {
        return;
    }
    
    self.executingCount += 1;
    self.totalPhotoUploadToDrive += 1;
    
    NSLog(@"TRIEUND2> Execute upload photo");
    
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
        [self _executeOnConcurrentQueue];
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
    gFile.parents = @[kGDriveApDataFolder];
    
    GTLRUploadParameters *uploadParams = [GTLRUploadParameters
                                          uploadParametersWithFileURL:[NSURL fileURLWithPath:self.filePath]
                                          MIMEType:nil];
    
    GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate
                                         queryWithObject:gFile
                                         uploadParameters:uploadParams];
    query.fields = @"id, name";
    
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

- (NSString *)_imagePath {
    NSString *saveImagePath = [self getDocumentDirectoryPath:@"saveImage.jpg"];
    
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:saveImagePath]) {
        UIImage *image = [UIImage imageNamed:@"image"];
        NSData *data = UIImageJPEGRepresentation(image, 1.0f);
        [data writeToFile:saveImagePath atomically:YES];
    }
    
    return saveImagePath;
}

- (NSString *)getDocumentDirectoryPath:(NSString *)Name {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,  NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *savedImagePath = [documentsDirectory stringByAppendingPathComponent:Name];
    return savedImagePath;
}

@end // @implementation ViewController
