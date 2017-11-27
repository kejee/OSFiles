
//
//  ApplicationHelper.m
//  FileDownloader
//
//  Created by Swae on 2017/10/31.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "ApplicationHelper.h"
#import "NetworkTypeUtils.h"
#import "OSFileDownloaderManager.h"
#import "AppGroupManager.h"
#import "MainTabBarController.h"
#import "BrowserViewController.h"
#import "ZWUtility.h"
#import "MainNavigationController.h"

@implementation UIView (ApplicationHelperExtension)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
         MethodSwizzle([UIView class], @selector(hitTest:withEvent:), @selector(xy_hitTest:withEvent:));
    });
}

/// 解决在leftViewController时BrowserViewController的switchPageButton超出父控件不响应事件的问题
- (UIView *)xy_hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *touchView = [self xy_hitTest:point withEvent:event];
    MainTabBarController *tabBarVc = (MainTabBarController *)[ApplicationHelper helper].drawerViewController.leftViewController;
    if (!tabBarVc || touchView) {
        return touchView;
    }
    CGRect rect =[[BrowserViewController sharedInstance].bottomToolBar convertRect:[BrowserViewController sharedInstance].bottomToolBar.switchPageButton.frame toView:tabBarVc.view];
    if (CGRectContainsPoint(rect, point)) {
        return [BrowserViewController sharedInstance].bottomToolBar.switchPageButton;
    }
    return touchView;
}

@end

@interface ApplicationHelper () <ICSDrawerControllerDelegate, UITabBarControllerDelegate>

@end

@implementation ApplicationHelper

@dynamic helper;

+ (ApplicationHelper *)helper {
    static id _helper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _helper = self.new;
    });
    return _helper;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addNotification];
        [self commonInit];
        [AppGroupManager defaultManager];
    }
    return self;
}

- (void)commonInit {
    
    _pasteboard = [UIPasteboard generalPasteboard];
}

- (void)addNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange:) name:NetworkTypeChangeNotification object:nil];
}

- (void)networkChange:(NSNotification *)notification {
    
    NetworkType type = [NetworkTypeUtils networkType];
    switch (type) {
        case NetworkTypeWIFI: {
            [[OSFileDownloaderManager sharedInstance] autoDownloadFailure];
            break;
        }
        case NetworkTypeWWAN: {
            [[OSFileDownloaderManager sharedInstance] failureAllDownloadTask];
            break;
        }
        default:
            break;
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - drawerViewController
////////////////////////////////////////////////////////////////////////


- (void)configureDrawerViewController {
    BrowserViewController *bvc = [BrowserViewController sharedInstance];
    MainNavigationController *nav = [[MainNavigationController alloc] initWithRootViewController:bvc];
    MainTabBarController *tabBarController = [MainTabBarController new];
    tabBarController.delegate = self;
    self.drawerViewController  = [[ICSDrawerController alloc] initWithLeftViewController:tabBarController
                                                                     centerViewController:nav];
    self.drawerViewController.delegate = self;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - ICSDrawerControllerDelegate
////////////////////////////////////////////////////////////////////////

- (CGFloat)drawerDepthOfDrawerController:(ICSDrawerController *)drawerController {
    return [UIScreen mainScreen].bounds.size.width;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UITabBarControllerDelegate
////////////////////////////////////////////////////////////////////////
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    
    if ([viewController.title isEqualToString:@"个人中心"]) {
        
    }
    
    return  YES;
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

/// 屏蔽ios文件不备份到icloud
- (void)addNotBackUpiCloud {
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *docPath = [documentPaths objectAtIndex:0];
    [self addSkipBackupAttributeToItemAtURL:docPath];
}

- (BOOL)addSkipBackupAttributeToItemAtURL:(NSString *)filePathString {
    NSURL *url = [NSURL fileURLWithPath:filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath:[url path]]);
    
    NSError *error = nil;
    BOOL success = [url setResourceValue:[NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [url lastPathComponent], error);
    }
    return success;
}

@end
