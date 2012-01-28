#import <Foundation/Foundation.h>

@class ITBrakes;

@interface ITCar : NSObject

@property (nonatomic, readonly, strong) ITBrakes *brakes;
@property (nonatomic, readonly, strong) NSString *name;

@end
