#import "ITCarIvar.h"

@implementation ITCarIvar
{
	ITBrakes *_brakes;
}

injective_requires(@"brakes")

- (ITBrakes *)brakes
{
	return _brakes;
}

@end
