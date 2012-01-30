
SPEC_BEGIN(IJLocalContextSpec)

describe(@"IJLocalContext", ^{
	__block IJLocalContext *context = nil;
	
	beforeEach(^{
		context = [[IJLocalContext alloc] init];
	});
	
	it(@"should provide values for additional passed params", ^{
		[context registerClass:[ITCar class] instantinationMode:IJContextInstantinationModeFactory];
		[context registerClass:[ITBrakes class] instantinationMode:IJContextInstantinationModeFactory];
		
		ITCar *car = [context instantinateClass:[ITCar class] withProperties:[NSDictionary dictionaryWithObject:@"test" forKey:@"name"]];
		[[car.name should] equal:@"test"];
	});
	
	it(@"should allow passing of local context to dependent objects", ^{
		[context registerClass:[ITParking class] instantinationMode:IJContextInstantinationModeFactory];
		[context registerClass:[ITCar class] instantinationMode:IJContextInstantinationModeFactory];
		[context registerClass:[ITBrakes class] instantinationMode:IJContextInstantinationModeFactory];
		
		ITParking *parking = [context instantinateClass:[ITParking class] withProperties:nil];
		ITCar *car = [parking localCar];
		[car shouldNotBeNil];
		[car.name shouldBeNil];
		
		car = [parking localCarNamed:@"test car"];
		[car shouldNotBeNil];
		[[car.name should] equal:@"test car"];
	});
	
	afterEach(^{
		[context release];
	});
});

SPEC_END