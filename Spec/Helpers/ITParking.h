#import <Foundation/Foundation.h>

@class ITCar;

@interface ITParking : NSObject

- (ITCar *)localCarNamed:(NSString *)name;
- (ITCar *)localCar;

@end
