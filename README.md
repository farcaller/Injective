# Injective framework

The purpose of this framework is to provide a simple dependency injection  framework for iOS/Mac applications.

Injective provides facilities for automatic connection of class instances by resolving properties dependencies. Additionally, Injection verifies that all required data is passed to instance for it to function correctly.

Injective supports factory-like object creation and singleton object creation.

# Setup

## Git version

### (For git users only) Add Injective as a submodule

If you're using git as your project's scm, add Injective as a submodue:

```bash
git submodule add https://github.com/farcaller/Injective
```

### (For all others) Download Injective source

Download Injective source code from https://github.com/farcaller/Injective/zipball/master and unzip it to your project root directory.

### Add Injective project to your workspace

Add Injective project to Project navigator (this will create a workspace if you don't have one). To do this, drag *Injective.xcodeproj* from the Finder to the very bottom of your project navigator panel:

![Adding Injective to workspace](http://github.com/farcaller/Injective/raw/master/Docs/add-to-workspace.png)

If you don't have a workspace yet, you will be asked: "Do you want to save this project in a new workspace?". Save it.

### Add public headers to search path

Open your project's build settings and add *Injective/Headers* to **Header Search paths**. If you followed step 0, it's as simple as adding `$(PROJECT_DIR)/Injective/Injective/Headers`:

![Adding header search paths](http://github.com/farcaller/Injective/raw/master/Docs/add-header-search-path.png)

### (optional) Add Injective as a global header

Add the following line to your project's precompiled header (pch file): `#import "InjectiveContext.h"`:

![Updating precompiled header](http://github.com/farcaller/Injective/raw/master/Docs/add-to-pch.png)

This will allow you to use Injective without requiring you to #import it everywhere.

## Precompiled version

*TODO*: publish precompiled version

# Usage

## Registering a singleton class

To register a class you need to use **+registerClass:instantinationMode:**  method of *InjectiveContext* class:

```objc
InjectiveContext *myContext = [[InjectiveContext alloc] init];
[myContext
 registerClass:[MyAPIController class]
 instantinationMode:InjectiveContextInstantinationModeSingleton];
```

Then, you can get an instance of the class with the following code:

```objectivec
MyAPIController *api = [myContext instantinateClass:[MyAPIController class] withProperties:nil];
```

## Registering a common class

You can register a common class using **InjectiveContextInstantinationModeFactory**. This way, Injection will create a new instance of the class each time you instantiate it:

```objectivec
InjectiveContext *myContext = [[InjectiveContext alloc] init];
[myContext
 registerClass:[MyDetailViewController class]
 instantinationMode:InjectiveContextInstantinationModeFactory];
```

In this mode, you can pass additional properties that would be mapped by KVC:

```objectivec
NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                   items, @"items",
                   nil];
MyDetailViewController *viewController = [myContext
                                          instantinateClass:[MyDetailViewController class] 
                                          withProperties:d];
```

## Specifying dependencies

*TODO*: write this (see `+ (NSSet *)injective_requredProperties` method).