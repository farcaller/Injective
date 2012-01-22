Injective framework
===================

The purpose of this framework is to provide a simple dependency injection  framework for iOS/Mac applications.

Injective provides facilities for automatic connection of class instances by resolving properties dependencies. Additionally, Injection verifies that all required data is passed to instance for it to function correctly.

Injective supports factory-like object creation and singleton object creation.

Setup
=====

*TODO*: write here about basic linking to libInjective.a

Add the following to your project's precompiled header (pch file):

    #import "InjectiveContext.h"

Registering a singleton class
=============================

To register a class you need to use **+registerClass:instantinationMode:**  method of *InjectiveContext* class:

    InjectiveContext *myContext = [[InjectiveContext alloc] init];
    [myContext
     registerClass:[MyAPIController class]
     instantinationMode:InjectiveContextInstantinationModeSingleton];

Then, you can get an instance of the class with the following code:

    MyAPIController *api = [myContext instantinateClass:[MyAPIController class] withProperties:nil];

Registering a common class
==========================

You can register a common class using **InjectiveContextInstantinationModeFactory**. This way, Injection will create a new instance of the class each time you instantiate it:

    InjectiveContext *myContext = [[InjectiveContext alloc] init];
    [myContext
     registerClass:[MyDetailViewController class]
     instantinationMode:InjectiveContextInstantinationModeFactory];

In this mode, you can pass additional properties that would be mapped by KVC:

    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       items, @"items",
                       nil];
    MyDetailViewController *viewController = [myContext
                                              instantinateClass:[MyDetailViewController class] 
                                              withProperties:d];

Specifying dependencies
=======================

*TODO*: write this (see `+ (NSSet *)injective_requredProperties` method).