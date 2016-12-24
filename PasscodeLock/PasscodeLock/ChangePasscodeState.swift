//
//  ChangePasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation

struct ChangePasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    
	init(stringsToShow: StringsToBeDisplayed?) {
        
        title = (stringsToShow?.passcodeLockChangeTitle ?? localizedStringFor("PasscodeLockChangeTitle", comment: "Change passcode title"))
        description = (stringsToShow?.passcodeLockChangeDescription ?? localizedStringFor("PasscodeLockChangeDescription", comment: "Change passcode description"))
    }
    
	func acceptPasscode(_ passcode: [String], fromLock lock: PasscodeLockType, stringsToShow: StringsToBeDisplayed?) {
        
        guard let currentPasscode = lock.repository.passcode else {
            return
        }
        
        if passcode == currentPasscode {
            
			let nextState = SetPasscodeState(stringsToShow: stringsToShow)

            lock.changeStateTo(nextState)
            
        } else {
            
            lock.delegate?.passcodeLockDidFail(lock)
        }
    }
}
