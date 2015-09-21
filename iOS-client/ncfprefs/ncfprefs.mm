#import <Preferences/Preferences.h>

@interface ncfprefsListController: PSListController {
}
@end

@implementation ncfprefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"ncfprefs" target:self] retain];
    if ([[self readPreferenceValue:[self specifierForID:@"enableEncrypted"]] intValue] == 1) {
      [((PSSpecifier *)[self specifierForID:@"secretkey"]) setProperty:@(TRUE) forKey:@"enabled"];
      [self reloadSpecifierID:@"secretkey"];
    }
	}
	return _specifiers;
}

//Enable secret cell if turn on
- (void)enable: (NSNumber *)enabled forSpecifier: (PSSpecifier *)spec {
  [self setPreferenceValue:enabled specifier:spec];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [((PSSpecifier *)[self specifierForID:@"secretkey"]) setProperty:@(([enabled intValue] == 1)) forKey:@"enabled"];
  [self reloadSpecifierID:@"secretkey"];
}

//Correct some cells after loaded
/*
-(void)viewDidLoad {

  [super viewDidLoad];

  if ([[self readPreferenceValue:[self specifierForID:@"enableEncrypted"]] intValue] == 1) {
    [((PSSpecifier *)[self specifierForID:@"secretkey"]) setProperty:@(TRUE) forKey:@"enabled"];
    [self reloadSpecifierID:@"secretkey"];
  }
}
*/

- (void)twitter {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.twitter.com/H6nry_/"]];
}

- (void)mail {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:henry.anonym@gmail.com"]];
}

- (void)website {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://h6nry.github.io/"]];
}
@end

// vim:ft=objc
