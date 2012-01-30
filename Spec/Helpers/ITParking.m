#import "ITParking.h"

@implementation ITParking

- (ITCar *)localCarNamed:(NSString *)name;
{
	return [ITCar injectiveInstantiateFromLocalObjectWithProperties:self,
			name, @"name", nil];
}

- (ITCar *)localCar
{
	return [ITCar injectiveInstantiateFromLocalObject:self];
}

@end
