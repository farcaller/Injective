#import <UIKit/UIKit.h>

SPEC_BEGIN(IJContextSpec)

describe(@"IJContext", ^{
	__block IJContext *context = nil;
	__block IJContext *nibContext = nil;
	
	beforeAll(^{
		nibContext = [[IJContext alloc] init];
		[nibContext registerOnAwakeFromNib];
	});
	
	beforeEach(^{
		context = [[IJContext alloc] init];
	});
	
	it(@"should create different instances if set to factory", ^{
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		ITBrakes *obj1 = [context instantiateClass:[ITBrakes class] withProperties:nil];
		ITBrakes *obj2 = [context instantiateClass:[ITBrakes class] withProperties:nil];
		[[obj1 shouldNot] beIdenticalTo:obj2];
	});
	
	it(@"should create same instances if set to singleton", ^{
		[context registerClass:[ITParking class] instantiationMode:IJContextInstantiationModeSingleton];
		ITParking *obj1 = [context instantiateClass:[ITParking class] withProperties:nil];
		ITParking *obj2 = [context instantiateClass:[ITParking class] withProperties:nil];
		[[obj1 should] beIdenticalTo:obj2];
	});
	
	it(@"should provide dependencies for registered classes via property", ^{
		[context registerClass:[ITCar class] instantiationMode:IJContextInstantiationModeFactory];
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		ITCar *car = [context instantiateClass:[ITCar class] withProperties:nil];
		[car.brakes shouldNotBeNil];
	});
	
	pending(@"should provide dependencies for registered classes via ivar", ^{
		[context registerClass:[ITCarIvar class] instantiationMode:IJContextInstantiationModeFactory];
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		ITCarIvar *car = [context instantiateClass:[ITCarIvar class] withProperties:nil];
		[[car brakes] shouldNotBeNil];
	});
	
	it(@"should raise if dependencies are not satisfied", ^{
		[context registerClass:[ITCar class] instantiationMode:IJContextInstantiationModeFactory];
		
		[[theBlock(^{
			[context instantiateClass:[ITCar class] withProperties:nil];
		}) should] raiseWithName:NSInternalInconsistencyException];
	});
	
	it(@"should provide values for additional passed params", ^{
		[context registerClass:[ITCar class] instantiationMode:IJContextInstantiationModeFactory];
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		ITCar *car = [context instantiateClass:[ITCar class] withProperties:[NSDictionary dictionaryWithObject:@"test" forKey:@"name"]];
		[[car.name should] equal:@"test"];
	});
	
	it(@"should create objects from default context using helper methods", ^{
		[IJContext setDefaultContext:context];
		[context registerClass:[ITCar class] instantiationMode:IJContextInstantiationModeFactory];
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		ITCar *car = [ITCar injectiveInstantiate];
		[car.brakes shouldNotBeNil];
		
		car = [ITCar injectiveInstantiateWithProperties:@"test", @"name", nil];
		[[car.name should] equal:@"test"];
	});
	
	it(@"should provide dependencies for registered classes when instantiated in from nib", ^{
		[nibContext registerClass:[ITCar class] instantiationMode:IJContextInstantiationModeFactory];
		[nibContext registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		NSArray *nib = [[NSBundle bundleForClass:[self class]] loadNibNamed:@"Car" owner:nil options:nil];
		ITCar *car = [nib lastObject];
		
		[car shouldNotBeNil];
		
		[car.brakes shouldNotBeNil];
	});
	
	it(@"sends awake messages to instantiated classes that support the behaviour", ^{
		[IJContext setDefaultContext:context];
		[context registerClass:[ITBrakes class] instantiationMode:IJContextInstantiationModeFactory];
		
		ITBrakes *brakes = [ITBrakes injectiveInstantiate];
		[[theValue(brakes.awaken) should] beTrue];
	});
	
	afterEach(^{
		[context release];
	});
	
	afterAll(^{
		[nibContext release];
	});
});

SPEC_END